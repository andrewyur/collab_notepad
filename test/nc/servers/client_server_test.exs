defmodule Nc.Servers.ClientServerUnitTest do
  use ExUnit.Case, async: true

  alias Nc.Servers.ClientServer
  alias Nc.Servers.DocServer

  setup do
    docserver = start_supervised!({DocServer, "12345678901234567890"})
    GenServer.call(docserver, :start)
    %{docserver: docserver}
  end

  test "handle_edit", %{docserver: docserver} do
    state = %{
      last_synced: 0,
      document: "12345HI HELLO67890TE...1234567890",
      server: docserver,
      pending_changes: [
        {:insert, 5, "HI HELLO"},
        {:delete, 12, 5},
        {:insert, 10, "TESTING..."},
      ]
    }

    change = {:delete, 2, 6}

    assert ClientServer.handle_edit(change, state) == %{
      last_synced: 0,
      document: "12HELLO67890TE...1234567890",
      server: docserver,
      pending_changes: [
        {:delete, 2, 6},
        {:insert, 5, "HI HELLO"},
        {:delete, 12, 5},
        {:insert, 10, "TESTING..."},
      ],
    }
  end

  test "collect_change_messages", %{docserver: docserver} do
    Task.await(Task.async(fn ->
      {:ok, _} = GenServer.call(docserver, {:change, {:insert, 10, "TESTING..."}, 0})
      {:ok, _} = GenServer.call(docserver, {:change, {:insert, 5, "HI HELLO"}, 1})
      {:ok, _} = GenServer.call(docserver, {:change, {:delete, 12, 5}, 2})
    end))

    assert ClientServer.collect_change_messages() == {
      [
        {:insert, 10, "TESTING..."},
        {:insert, 5, "HI HELLO"},
        {:delete, 12, 5}
      ],
      3
    }
  end

  # this test is failing, we need to send only 1 change at a time, so at most, there
  # is only one change in the client's mailbox, and the pending changes only need to get revised against
  # that one change, and then the client is completely up to date with that version of the server document.

  # also need to get something out soon, i am in over my head here and i will burn out soon.

  # the problem remains though... what happens when a server sends a change to insert something,
  # and then later sends a change to delete it? I think I was almost there, pending changes have to be updated
  # along with each server change. it may make it easier to process only one incoming change at time.
  # the problem with a pending change splitting a server change in two seems minor as well.


  test "transform_incoming 1" do

    #12345678901234567890


    incoming_change = {:delete, 5, 6}

    #12345234567890

    pending_changes = [
      {:insert, 4, "HI HELLO"},
      #1234HI HELLO5678901234567890
      {:insert, 15, "HI HELLO"},
      #1234HI HELLO567HI HELLO8901234567890
      {:delete, 25, 5}
      #1234HI HELLO567HI HELLO89567890
    ]

    expected = {
    [
      {:delete, 13, 2},
      {:delete, 23, 2}
    ],
    #1234HI HELLO5HI HELLO567890
    [
      #12345234567890
      {:insert, 4, "HI HELLO"},
      #1234HI HELLO5234567890
      {:insert, 13, "HI HELLO"},
      #1234HI HELLO5HI HELLO234567890
      {:delete, 19, 3}
      #1234HI HELLO5HI HELLO234567890
    ]}
    assert ClientServer.transform_incoming(incoming_change, pending_changes)
      == expected
  end

  # test "transform_incoming 2" do
  #   incoming_change = {:insert, 11, "HELLO"}

  #   pending_changes = [
  #     {:insert, 4, "HI HELLO"},
  #     {:insert, 15, "HI HELLO"},
  #     {:delete, 25, 5}
  #   ]

  #   expected = nil
  #   assert ClientServer.transform_incoming(incoming_change, pending_changes)
  #     == expected
  # end

  # test "transform_incoming 3" do
  #   incoming_change = {:insert, 10, "TESTING..."}

  #   pending_changes = [
  #     {:delete, 0, 10},
  #     {:insert, 8, "HI"},
  #   ]

  #   expected = nil
  #   assert ClientServer.transform_incoming(incoming_change, pending_changes)
  #     == expected
  # end

  # test "localize_incoming" do
  #   incoming_changes = [
  #     {:insert, 10, "TESTING..."},
  #     {:delete, 12, 5},
  #     {:insert, 5, "HI HELLO"}
  #   ]

  #   pending_changes = [
  #     {:delete, 0, 10},
  #     {:insert, 8, "HI"},
  #   ]

  #   expected = {
  #     [],
  #     [
  #       {:delete, 0, 23},
  #       {:insert, 8, "HI"},
  #     ]
  #   }

  #   assert ClientServer.localize_incoming(incoming_changes, pending_changes)
  #     == expected
  # end

  # test "handle_pull", %{docserver: docserver} do

  #   Task.await(Task.async(fn ->
  #     #12345678901234567890
  #     {:ok, _} = GenServer.call(docserver, {:change, {:insert, 10, "TESTING..."}, 0})
  #     #1234567890TESTING...1234567890
  #     {:ok, _} = GenServer.call(docserver, {:change, {:delete, 12, 5}, 1})
  #     #12345HI HELLO67890TE...1234567890
  #     {:ok, _} = GenServer.call(docserver, {:change, {:insert, 5, "HI HELLO"}, 2})
  #   end))

  #   state = %{
  #     last_pulled: 0,
  #     document: "12345678HI90",
  #     server: docserver,
  #     pending_changes: [
  #       #12345678HI90
  #       {:insert, 8, "HI"},
  #       #1234567890
  #       {:delete, 0, 10},
  #       #12345678901234567890
  #     ]
  #   }

  #   new_state = ClientServer.handle_pull(state)

  #   assert new_state == %{
  #     last_pulled: 3,
  #     document: "TE...12345678HI90",
  #     server: docserver,
  #     pending_changes: [
  #       {:insert, 26, "HI"},
  #       {:delete, 0, 18},
  #     ]
  #   }
  # end








  # test "handle_push 1", %{docserver: docserver} do
  #   state = %{
  #     last_pulled: 0,
  #     document: "12345HI HELLO67890TE...1234567890",
  #     server: docserver,
  #     pending_changes: [
  #       {:insert, 5, "HI HELLO"},
  #       {:delete, 12, 5},
  #       {:insert, 10, "TESTING..."},
  #     ]
  #   }

  #   new_state = ClientServer.handle_push(state)

  #   assert new_state == %{
  #     last_pulled: 0,
  #     document: "12345HI HELLO67890TE...1234567890",
  #     server: docserver,
  #     pending_changes: []
  #   }
  # end

  # test "handle_push 2", %{docserver: docserver} do
  #   Task.await(Task.async(fn ->
  #     {:ok, _} = GenServer.call(docserver, {:change, {:insert, 10, "TESTING..."}, 0})
  #     {:ok, _} = GenServer.call(docserver, {:change, {:delete, 12, 5}, 1})
  #     {:ok, _} = GenServer.call(docserver, {:change, {:insert, 5, "HI HELLO"}, 2})
  #   end))

  #   state = %{
  #     last_pulled: 0,
  #     document: "1234901234567890",
  #     server: docserver,
  #     pending_changes: [
  #       {:delete, 4, 4}
  #     ]
  #   }

  #   new_state = ClientServer.handle_push(state)

  #   assert new_state == %{
  #     last_pulled: 0,
  #     document: "1234901234567890",
  #     server: docserver,
  #     pending_changes: []
  #   }

  #   assert DocServer.read(docserver) == "123490TE...1234567890"
  # end

  # # need to test pushing these changes afterwards

  # # test this exact test on server transform_request!!

  # # pushed change should be tranformed against all of the pending changes to become relative to the last pushed version
  # # need to test this with adding something and then deleting it
  # test "handle_push 3", %{docserver: docserver} do
  #   Task.await(Task.async(fn ->
  #     {:ok, _} = GenServer.call(docserver, {:change, {:insert, 10, "TESTING..."}, 0})
  #     {:ok, _} = GenServer.call(docserver, {:change, {:delete, 12, 5}, 1})
  #     {:ok, _} = GenServer.call(docserver, {:change, {:insert, 5, "HI HELLO"}, 2})
  #   end))

  #   state = %{
  #     last_pulled: 0,
  #     document: "1234901234567890",
  #     server: docserver,
  #     pending_changes: [
  #       {:delete, 4, 4}
  #     ]
  #   }

  #   ClientServer.handle_push(state)
  #   assert DocServer.read(docserver) == "123490TE...1234567890"


  #   Task.await(Task.async(fn ->
  #     {:ok, _} = GenServer.call(docserver, {:change, {:insert, 11, "TESTING..."}, 4})
  #   end))
  #   assert DocServer.read(docserver) == "123490TE...TESTING...1234567890"

  #   state = %{
  #     last_pulled: 0,
  #     document: "12349012HI HELLO34567890",
  #     server: docserver,
  #     pending_changes: [
  #       {:insert, 8, "HI HELLO"}
  #     ]
  #   }

  #   new_state = ClientServer.handle_push(state)

  #   assert new_state == %{
  #     last_pulled: 0,
  #     document: "12349012HI HELLO34567890",
  #     server: docserver,
  #     pending_changes: []
  #   }

  #   assert DocServer.read(docserver) == "123490TE...TESTING...12HI HELLO34567890"
  # end
end

defmodule Nc.Servers.ClientServerIntegrationTest do
  use ExUnit.Case, async: true
end
