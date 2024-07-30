# defmodule Nc.Processes.ProcessTest do
#   use ExUnit.Case

#   alias Nc.Processes.Client
#   alias Nc.Processes.Server

#   # another really inefficient testing function
#   def apply_random_change(client) do
#     client_document = Client.read(client)

#     change = Nc.Helpers.random_change(client_document, <<64 + :rand.uniform(26)>>)

#     change = Nc.Sync.clamp(change, client_document)

#     case change do
#       {:delete, pos, amt, _} -> Client.delete(client, pos, amt)
#       {:insert, pos, text, _} -> Client.insert(client, pos, text)
#       nil -> nil
#     end

#     change
#   end

#   setup do
#     server =
#       start_supervised!(%{id: Server, start: {Server, :start_from_text, "1234567890!@#$%^&*()"}})

#     %{server: server}
#   end

#   # not really sure how to repeat this one, but we dont really need to anyways
#   test "3 way divergence", %{server: server} do
#     # testing that set of divergences from many clients can be resolved
#     # this will be the core functionality of this project

#     client1 = start_supervised!({Client, server}, id: :client1)
#     client2 = start_supervised!({Client, server}, id: :client2)
#     client3 = start_supervised!({Client, server}, id: :client3)

#     apply_random_change(client1)
#     apply_random_change(client1)

#     # client2 is at version 2
#     Client.pull(client2)

#     apply_random_change(client1)
#     apply_random_change(client1)

#     # client3 is at version 4
#     Client.pull(client3)

#     apply_random_change(client1)
#     apply_random_change(client1)

#     # client1 is at current version

#     # client2 makes a change
#     apply_random_change(client2)

#     # client3 makes a change
#     apply_random_change(client3)

#     # all sync and compare documents

#     Client.push(client1)
#     Client.push(client2)
#     Client.push(client3)

#     Client.pull(client1)
#     Client.pull(client2)
#     Client.pull(client3)

#     server_doc = Server.read(server)

#     client1_doc = Client.read(client1)
#     client2_doc = Client.read(client2)
#     client3_doc = Client.read(client3)

#     assert server_doc == client1_doc
#     assert server_doc == client2_doc
#     assert server_doc == client3_doc
#   end
# end
