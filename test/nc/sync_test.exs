defmodule Nc.SyncTest do
  use ExUnit.Case, async: true

  alias Nc.Sync

  # these tests are as much to help me find situations i had not expected as to find bugs in my code

  def apply_change(string, change) do
    case change do
      {:insert, position, text, _from} ->
        {front, back} = String.split_at(string, position)
        front <> text <> back

      {:delete, position, amount, _from} ->
        {front, rest} = String.split_at(string, position)
        {_, back} = String.split_at(rest, amount)
        front <> back

      nil ->
        string
    end
  end

  def random_change(string, letter, from) do
    position = :rand.uniform(String.length(string) + 1) - 1
    amount = :rand.uniform(String.length(string))

    case :rand.uniform(2) do
      1 -> {:delete, position, amount, from}
      2 -> {:insert, position, String.duplicate(letter, amount), from}
    end
  end

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
  test "automated n n compound divergence" do
    changelog_length = nil

    Enum.each(0..100, fn _ ->
      string = "1234567890!@#$%^&*()"

      server_changes = generate_change_list(string, nil, changelog_length)

      client_changes = generate_change_list(string, nil, changelog_length)

      {server, server_changes} = apply_and_clamp(string, server_changes)

      {client, client_changes} = apply_and_clamp(string, client_changes)

      {new_client_changes, _} = reconcile_changes(server_changes, client_changes)
      new_client = apply_change_list(client, new_client_changes)
      {new_server_changes, _} = reconcile_changes(client_changes, server_changes)
      new_server = apply_change_list(server, new_server_changes)

      if new_client != new_server do
        IO.inspect({client_changes, server_changes})
      end

      assert new_client == new_server
    end)
  end

  def generate_change_list(string, from, length \\ nil) do
    0..(length || :rand.uniform(String.length(string)))
    |> Enum.map(fn i ->
      random_change(string, <<65 + i>>, from)
    end)
  end

  def reconcile_changes(incoming, changelog) do
    reconcile_single_change = fn current_changelog_change, {reconciled_change, new_changelog} ->
      {new_current_changelog_change, new_reconciled_change} =
        Sync.reconcile(current_changelog_change, reconciled_change)

      {new_reconciled_change, [new_current_changelog_change | new_changelog]}
    end

    reconcile_all_changes = fn incoming_change, {new_changes, current_changelog} ->
      {reconciled_change, new_changelog} =
        Enum.reduce(current_changelog, {incoming_change, []}, reconcile_single_change)

      new_changelog = Enum.reverse(new_changelog)
      {[reconciled_change | new_changes], new_changelog}
    end

    {new_changes, reconciled_changelog} =
      Enum.reduce(incoming, {[], changelog}, reconcile_all_changes)

    {Enum.reverse(new_changes), reconciled_changelog}
  end

  def apply_change_list(string, changes, to \\ nil) do
    if to == nil do
      Enum.reduce(changes, string, &apply_change(&2, &1))
    else
      Enum.reduce(changes, string, fn change, str ->
        if change == nil || elem(change, 3) == to do
          str
        else
          apply_change(str, change)
        end
      end)
    end
  end

  def apply_and_clamp(string, changes) do
    {new_string, new_changes} =
      Enum.reduce(changes, {string, []}, fn change, {new_string, new_changes} ->
        change = Sync.clamp(change, new_string)
        new_string = apply_change(new_string, change)
        {new_string, [change | new_changes]}
      end)

    {new_string, Enum.reverse(new_changes)}
  end

  def get_relevant_changes(changelog, last_synced) do
    for {change, version} when version > last_synced <- changelog, do: change
  end

  def extend_changelog(changelog, new_changes) do
    new_changes =
      changelog ++
        Enum.zip(
          new_changes,
          Stream.iterate(elem(List.last(changelog, {0, 0}), 1) + 1, &(&1 + 1))
        )

    {elem(List.last(new_changes), 1), new_changes}
  end

  # for some reason, this test gives a runtime error when the tests are run asynchronously
  test "push without pull" do
    # test to see if a client can push changes up to the server from a stale document, and successfully sync changes afterward
    # may need to have client id baked into every change by this point so the client can differentiate its own changes from others

    changes_length = nil

    string = "1234567890!@#$%^&*()"

    server_changes = generate_change_list(string, :server, changes_length) |> IO.inspect()
    # server_changes = [{:delete, 13, 5, :server}]
    {server, server_changes} = apply_and_clamp(string, server_changes)
    {_, server_changelog} = extend_changelog([], server_changes)

    # assert server == "1234567890!@#()"

    client_changes = generate_change_list(string, :client, changes_length) |> IO.inspect()
    # client_changes = [{:insert, 16, "AAAAAAA", :client}]
    {client, client_changes} = apply_and_clamp(string, client_changes)

    # assert client == "1234567890!@#$%^AAAAAAA&*()"

    # client pushes pending changes

    relevant_server_changes = get_relevant_changes(server_changelog, 0)
    {new_changes, new_changelog} = reconcile_changes(client_changes, relevant_server_changes)
    server = apply_change_list(server, new_changes, :server)
    {_, server_changelog} = extend_changelog(server_changelog, new_changes)

    # assert server == "1234567890!@#()"

    # server makes new changes

    server_changes = generate_change_list(server, :server, changes_length) |> IO.inspect()
    # server_changes = [{:insert, 7, "BB", :server}]
    {server, server_changes} = apply_and_clamp(server, server_changes)
    {_, server_changelog} = extend_changelog(server_changelog, server_changes)
    new_changelog = new_changelog ++ server_changes

    # assert server == "1234567BB890!@#()"

    # client makes new changes

    new_client_changes = generate_change_list(string, :client, changes_length) |> IO.inspect()
    # new_client_changes = [{:insert, 8, "CCCCCCCCCCCCCC", :client}]
    {client, new_client_changes} = apply_and_clamp(client, new_client_changes)
    client_changes = client_changes ++ new_client_changes

    # assert client == "12345678CCCCCCCCCCCCCC90!@#$%^AAAAAAA&*()"

    # client pushes those changes

    # relevant_server_changes = get_relevant_changes(server_changelog, 0)
    {new_changes, _} = reconcile_changes(new_client_changes, new_changelog)
    server = apply_change_list(server, new_changes, :server)
    {_, server_changelog} = extend_changelog(server_changelog, new_changes)

    # assert server == "1234567BB8CCCCCCCCCCCCCC90!@#()"

    # client pulls from server

    relevant_server_changes = get_relevant_changes(server_changelog, 0)
    {new_changes, _} = reconcile_changes(relevant_server_changes, client_changes)
    client = apply_change_list(client, new_changes, :client)

    # assert client == "1234567BB8CCCCCCCCCCCCCC90!@#()"

    assert server == client
  end

  test "pull without push" do
    # test to see if a client can pull changes down without pushing its pending changes
  end

  # test "3 way divergence" do
  #   # testing that set of divergences from many clients can be resolved
  #   # this will be the core functionality of this project

  #   string = "1234567890!@#$%^&*()"

  #   {server, server_changelog} =
  #     Enum.reduce(generate_change_list(string, 6), {string, []}, fn change,
  #                                                                   {server, new_changes} ->
  #       change = Sync.clamp(change, server)
  #       server = apply_change(server, change)
  #       {server, [change | new_changes]}
  #     end)

  #   server_changelog = Enum.reverse(server_changelog)

  #   # client1 is at version 4
  #   client1 =
  #     Enum.reduce(server_changelog, string, fn {server_change, change_id}, client ->
  #       if change_id <= 4, do: apply_change(client, server_change), else: client
  #     end)

  #   # client1 makes a change
  #   client1_change = random_change(client1, "A")
  #   client1 = apply_change(client1, client1_change)

  #   # client2 is at version 2
  #   client2 =
  #     Enum.reduce(server_changelog, string, fn {server_change, change_id}, client ->
  #       if change_id <= 2, do: apply_change(client, server_change), else: client
  #     end)

  #   # client2 makes a change
  #   client2_change = random_change(client1, "B")
  #   client2 = apply_change(client2, client2_change)

  #   # client3 is at current version
  #   client3 =
  #     Enum.reduce(server_changelog, string, fn {server_change, change_id}, client ->
  #       if true, do: apply_change(client, server_change), else: client
  #     end)

  #   # client3 makes a change
  #   client3_change = random_change(client1, "C")
  #   client3 = apply_change(client3, client3_change)

  #   # server pulls in all changes, and adds them to the changelog
  #   [new_change] = reconcile_changes_2([client1_change], server_changelog)
  #   server = apply_change()

  # end
end
