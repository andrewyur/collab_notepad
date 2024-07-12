defmodule Nc.SyncTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.CodeAction.Helpers
  alias Nc.Sync

  import Nc.Helpers

  # these tests are as much to help me find situations i had not expected as to find bugs in my code

  # this has passed 1_000_000 iterations
  test "randomized test" do
    Enum.each(0..100, fn _ ->
      string = "12345678901234567890"

      change1 = random_change(string, "A", nil)
      change2 = random_change(string, "B", nil)

      change1 = Sync.clamp(change1, string)
      server = apply_change(string, change1)
      change2 = Sync.clamp(change2, string)
      client = apply_change(string, change2)

      {change1_p, change2_p} = Sync.reconcile(change1, change2)

      assert apply_change(server, change2_p) == apply_change(client, change1_p),
             inspect([change1, change2])
    end)
  end

  # this has passed 1_000_000 iterations
  test "randomized 1 2 compound divergence" do
    Enum.each(0..100, fn _ ->
      string = "12345678901234567890"

      o_change1 = random_change(string, "A", nil)
      o_change2 = random_change(string, "B", nil)
      o_change3 = random_change(string, "C", nil)

      change3 = Sync.clamp(o_change3, string)
      server = apply_change(string, change3)

      change1 = Sync.clamp(o_change1, string)
      client = apply_change(string, change1)
      change2 = Sync.clamp(o_change2, client)
      client = apply_change(client, change2)

      {change1_p, change3_p} = Sync.reconcile(change1, change3)
      server = apply_change(server, change1_p)
      {change2_p, _change3_pp} = Sync.reconcile(change2, change3_p)
      server = apply_change(server, change2_p)

      {_change1_p, change3_p} = Sync.reconcile(change1, change3)
      {_change2_p, change3_pp} = Sync.reconcile(change2, change3_p)
      client = apply_change(client, change3_pp)

      assert client == server, inspect([client, server, o_change1, o_change2, o_change3])
    end)
  end

  @tag timeout: :infinity
  # this test has passed 1_000_000 iterations
  test "randomized n n compound divergence" do
    changelog_length = nil

    Enum.each(0..100, fn _ ->
      string = "1234567890!@#$%^&*()"

      server_changes = generate_change_list(string, nil, changelog_length)

      client_changes = generate_change_list(string, nil, changelog_length)

      {server, server_changes} = apply_and_clamp(string, server_changes)

      {client, client_changes} = apply_and_clamp(string, client_changes)

      {new_client_changes, _} = Sync.reconcile_against(server_changes, client_changes)
      new_client = apply_change_list(client, new_client_changes)
      {new_server_changes, _} = Sync.reconcile_against(client_changes, server_changes)
      new_server = apply_change_list(server, new_server_changes)

      if new_client != new_server do
        IO.inspect({client_changes, server_changes})
      end

      assert new_client == new_server
    end)
  end

  @tag timeout: :infinity
  # this test has passed 1_000_000 iterations
  test "randomized push without pull" do
    # test to see if a client can push changes up to the server from a stale document, and successfully sync changes afterward
    # may need to have client id baked into every change by this point so the client can differentiate its own changes from others

    # this works because the server keeps the modified changelog produced by the Sync.reconcile_against function, so it can base the client's changes off of its previous ones.
    # this means that the server process will have to keep an array of modified changelogs, adding new changes onto them as they happen, and emptying them when the client pulls.

    Enum.each(0..100, fn _ ->
      changes_length = nil

      string = "1234567890!@#$%^&*()"

      server_changes = generate_change_list(string, :server, changes_length)
      {server, server_changes} = apply_and_clamp(string, server_changes)
      {_, server_changelog} = extend_changelog([], server_changes)

      client_changes = generate_change_list(string, :client, changes_length)
      {client, client_changes} = apply_and_clamp(string, client_changes)

      # client pushes pending changes

      relevant_server_changes = get_relevant_changes(server_changelog, 0)

      {new_changes, new_changelog} =
        Sync.reconcile_against(client_changes, relevant_server_changes)

      server = apply_change_list(server, new_changes, :server)
      {_, server_changelog} = extend_changelog(server_changelog, new_changes)

      # server makes new changes

      server_changes = generate_change_list(server, :server, changes_length)
      {server, server_changes} = apply_and_clamp(server, server_changes)
      {_, server_changelog} = extend_changelog(server_changelog, server_changes)
      new_changelog = new_changelog ++ server_changes

      # client makes new changes

      new_client_changes = generate_change_list(string, :client, changes_length)
      {client, new_client_changes} = apply_and_clamp(client, new_client_changes)
      client_changes = client_changes ++ new_client_changes

      # client pushes those changes

      {new_changes, _} = Sync.reconcile_against(new_client_changes, new_changelog)
      server = apply_change_list(server, new_changes, :server)
      {_, server_changelog} = extend_changelog(server_changelog, new_changes)

      # client pulls from server

      relevant_server_changes = get_relevant_changes(server_changelog, 0)
      {new_changes, _} = Sync.reconcile_against(relevant_server_changes, client_changes)
      client = apply_change_list(client, new_changes, :client)

      assert server == client
    end)
  end

  @tag timeout: :infinity
  # this test has passed 1_000_000 iterations
  test "randomized pull without push" do
    # test to see if a client can pull changes down without pushing its pending changes

    # this should work similarly to the push without pull test, where the client keeps a log of changes to base outdated changes off of.
    Enum.each(0..100, fn _ ->
      changes_length = nil

      string = "1234567890!@#$%^&*()"

      # server & client make changes

      server_changes = generate_change_list(string, :server, changes_length)
      {server, server_changes} = apply_and_clamp(string, server_changes)
      {_, server_changelog} = extend_changelog([], server_changes)

      client_changes = generate_change_list(string, :client, changes_length)
      {client, client_changes} = apply_and_clamp(string, client_changes)

      # client pulls pending changes

      relevant_server_changes = get_relevant_changes(server_changelog, 0)

      {new_changes, client_changes_p} =
        Sync.reconcile_against(relevant_server_changes, client_changes)

      client = apply_change_list(client, new_changes, :client)

      # server and client make new changes

      new_client_changes = generate_change_list(string, :client, changes_length)
      {client, new_client_changes} = apply_and_clamp(client, new_client_changes)
      client_changes_p = client_changes_p ++ new_client_changes

      server_changes = generate_change_list(server, :server, changes_length)
      {server, server_changes} = apply_and_clamp(server, server_changes)
      {_, _server_changelog} = extend_changelog(server_changelog, server_changes)

      # client pulls from server

      {new_changes, client_changes_p} = Sync.reconcile_against(server_changes, client_changes_p)
      client = apply_change_list(client, new_changes, :client)

      # client pushes pending changes

      # list is empty because the client just pulled, in reality we would call get relevant changes anyway
      {new_changes, _} = Sync.reconcile_against(client_changes_p, [])
      server = apply_change_list(server, new_changes, :server)

      assert server == client
    end)
  end

  # this may be easier to test with everything encapsulated as a state should do the server_state & client_state modules before doing this

  test "3 way divergence" do
    # testing that set of divergences from many clients can be resolved
    # this will be the core functionality of this project

    # client1 is at version 4

    # client1 makes a change

    # client2 is at version 2

    # client2 makes a change

    # client3 is at current version

    # client3 makes a change
  end

  test "temp" do
    string = "1234567890!@#$%^&*()"

    # client makes a change and pushes to the server

    client_change_list_1 = [{:delete, 11, 4, :client1}]

    client = apply_change_list(string, client_change_list_1, :client1)

    server = apply_change_list(string, client_change_list_1, :server)
    {_, server_changelog} = extend_changelog([], client_change_list_1)

    client_pending = client_change_list_1

    # server makes a change

    server_changes = [{:delete, 8, 8, :server}]
    {server, server_changes} = apply_and_clamp(server, server_changes)
    {_, server_changelog} = extend_changelog(server_changelog, server_changes)

    # client makes another change and pushes to the server

    client_change_list_2 = [{:insert, 13, "AAA", :client1}]

    client = apply_change_list(string, client_change_list_2, :client1)

    server = apply_change_list(string, client_change_list_2, :server)
    {_, server_changelog} = extend_changelog([], client_change_list_2)

    client_pending = client_pending ++ client_change_list_2

    # client 1 pulls from the server

    relevant_server_changes = get_relevant_changes(server_changelog, 0)
    {new_changes, _} = Sync.reconcile_against(relevant_server_changes, client_pending)
    client = apply_change_list(client, new_changes, :client1)

    assert server == client
  end
end
