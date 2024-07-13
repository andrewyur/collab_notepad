defmodule Nc.Processes.StateTest do
  alias Nc.Core.DocTree
  alias Nc.Processes.ClientState
  alias Nc.Processes.ServerState

  use ExUnit.Case, async: true

  # these tests should mimic the way the states will interact through message passing as closely as possible

  # atoms are used in place of pids here

  def apply_random_changes(client, from) do
    changes_list =
      Nc.Helpers.generate_change_list(DocTree.tree_to_string(client.document), from)

    # obviously really inefficient, but its fine because it will only be used in tests :)
    Enum.reduce(changes_list, client, fn change, client ->
      change = Nc.Sync.clamp(change, DocTree.tree_to_string(client.document))
      ClientState.make_change(client, change)
    end)
  end

  @tag timeout: :infinity
  # this test has passed 1_000_000 iterations
  test "randomized push without pull" do
    Enum.each(0..100, fn _ ->
      string = "1234567890!@#$%^&*()"

      server = ServerState.new(string)
      {server, server_document, server_current_id} = ServerState.add_new_client(server, :client1)
      {server, _, _} = ServerState.add_new_client(server, :client2)

      client1 = ClientState.new(:server, server_document, server_current_id)
      client2 = ClientState.new(:server, server_document, server_current_id)

      # client 1 makes a change and pushes to the server

      client1 = apply_random_changes(client1, :client1)

      {client1, client1_changes} = ClientState.start_push(client1)
      server = ServerState.handle_push(server, :client1, client1_changes)

      # client 2 pulls from the server

      {client2, client2_last_pulled} = ClientState.start_pull(client2)

      {server, client2_pulled_changes, client2_current_id} =
        ServerState.handle_pull(server, :client2, client2_last_pulled)

      client2 = ClientState.recieve_pull(client2, client2_pulled_changes, client2_current_id)

      # client 2 makes another change and pushes to the server

      client2 = apply_random_changes(client2, :client2)

      {client2, client2_changes} = ClientState.start_push(client2)
      server = ServerState.handle_push(server, :client2, client2_changes)

      # client 1 makes another change and pushes to the server

      client1 = apply_random_changes(client1, :client1)

      {client1, client1_changes} = ClientState.start_push(client1)
      server = ServerState.handle_push(server, :client1, client1_changes)

      # client 2 pulls from the server

      {client2, client2_last_pulled} = ClientState.start_pull(client2)

      {server, client2_pulled_changes, client2_current_id} =
        ServerState.handle_pull(server, :client2, client2_last_pulled)

      client2 = ClientState.recieve_pull(client2, client2_pulled_changes, client2_current_id)

      # client 1 pulls from the server

      {client1, client1_last_pulled} = ClientState.start_pull(client1)

      {server, client1_pulled_changes, client1_current_id} =
        ServerState.handle_pull(server, :client1, client1_last_pulled)

      client1 = ClientState.recieve_pull(client1, client1_pulled_changes, client1_current_id)

      assert DocTree.tree_to_string(client1.document) == DocTree.tree_to_string(server.document)
      assert DocTree.tree_to_string(client2.document) == DocTree.tree_to_string(server.document)
    end)
  end

  @tag timeout: :infinity
  # this test has passed 1_000_000 iterations
  test "randomized pull without push" do
    Enum.each(0..100, fn _ ->
      string = "1234567890!@#$%^&*()"

      server = ServerState.new(string)
      {server, server_document, server_current_id} = ServerState.add_new_client(server, :client1)
      {server, _, _} = ServerState.add_new_client(server, :client2)

      client1 = ClientState.new(:server, server_document, server_current_id)
      client2 = ClientState.new(:server, server_document, server_current_id)

      # client1 makes a change

      client1 = apply_random_changes(client1, :client1)

      # client2 makes a change

      client2 = apply_random_changes(client2, :client2)

      # client2 pulls + pushes

      {client2, client2_last_pulled} = ClientState.start_pull(client2)

      {server, client2_pulled_changes, client2_current_id} =
        ServerState.handle_pull(server, :client2, client2_last_pulled)

      client2 = ClientState.recieve_pull(client2, client2_pulled_changes, client2_current_id)

      {client2, client2_changes} = ClientState.start_push(client2)
      server = ServerState.handle_push(server, :client2, client2_changes)

      # client1 pulls

      {client1, client1_last_pulled} = ClientState.start_pull(client1)

      {server, client1_pulled_changes, client1_current_id} =
        ServerState.handle_pull(server, :client1, client1_last_pulled)

      client1 = ClientState.recieve_pull(client1, client1_pulled_changes, client1_current_id)

      # client1 makes a change

      client1 = apply_random_changes(client1, :client1)

      # client2 makes a change

      client2 = apply_random_changes(client2, :client2)

      # client2 pulls + pushes

      {client2, client2_last_pulled} = ClientState.start_pull(client2)

      {server, client2_pulled_changes, client2_current_id} =
        ServerState.handle_pull(server, :client2, client2_last_pulled)

      client2 = ClientState.recieve_pull(client2, client2_pulled_changes, client2_current_id)

      {client2, client2_changes} = ClientState.start_push(client2)
      server = ServerState.handle_push(server, :client2, client2_changes)

      # client1 pulls + pushes

      {client1, client1_last_pulled} = ClientState.start_pull(client1)

      {server, client1_pulled_changes, client1_current_id} =
        ServerState.handle_pull(server, :client1, client1_last_pulled)

      client1 = ClientState.recieve_pull(client1, client1_pulled_changes, client1_current_id)

      {client1, client1_changes} = ClientState.start_push(client1)
      server = ServerState.handle_push(server, :client1, client1_changes)

      # client2 pulls

      {client2, client2_last_pulled} = ClientState.start_pull(client2)

      {server, client2_pulled_changes, client2_current_id} =
        ServerState.handle_pull(server, :client2, client2_last_pulled)

      client2 = ClientState.recieve_pull(client2, client2_pulled_changes, client2_current_id)

      assert DocTree.tree_to_string(client1.document) == DocTree.tree_to_string(server.document)
      assert DocTree.tree_to_string(client2.document) == DocTree.tree_to_string(server.document)
    end)
  end

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
end
