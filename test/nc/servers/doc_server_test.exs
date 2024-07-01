defmodule Nc.Servers.DocServerUnitTest do
  use ExUnit.Case

  alias Nc.Core.DocTree
  alias Nc.Servers.DocServer

  test "transform_change 1" do
    transformee = {:delete, 10, 5}
    last_synced = 10

    sender = spawn(fn -> nil end)

    transformers = [
      %{id: 12, change: {:insert, 5, "HI HELLO"}, from: sender},
      %{id: 11, change: {:delete, 12, 5}, from: sender},
      %{id: 10, change: {:insert, 10, "NOT COUNTED"}, from: sender}
    ]

    expected = {:delete, 18, 2}

    assert DocServer.transform_change(transformee, last_synced, self(), transformers)
      == expected
  end

  test "transform_change 2" do
    transformee = {:delete, 12, 5}
    last_synced = 0

    sender = spawn(fn -> nil end)

    transformers = [
      %{id: 2, change: {:insert, 5, "HI HELLO"}, from: sender},
      %{id: 1, change: {:insert, 10, "TESTING..."}, from: sender}
    ]

    expected = {:delete, 12 + 8 + 10, 5 }

    assert DocServer.transform_change(transformee, last_synced, self(), transformers)
      == expected
  end

  test "transform_change 3" do
    transformee = {:delete, 10, 5}
    last_synced = 0

    sender = spawn(fn -> nil end)

    transformers = [
      %{id: 3, change: {:insert, 10, "NOT COUNTED"}, from: self()},
      %{id: 2, change: {:delete, 12, 5}, from: self()},
      %{id: 1, change: {:insert, 5, "HI HELLO"}, from: sender},
    ]

    expected = {:delete, 18, 5}

    assert DocServer.transform_change(transformee, last_synced, self(), transformers)
      == expected
  end

  test "handle_start" do
    from = {self(), nil}

    state = %{
      changelog: [],
      clients: [],
      current_id: 10,
      doctree: DocTree.new("HI HELLO HI"),
    }

    assert DocServer.handle_start(from, state) ==
      {
        :reply,
        %{
          current_id: 10,
          current_doctree: DocTree.new("HI HELLO HI"),
        },
        %{
          clients: [self()],
          changelog: [],
          current_id: 10,
          doctree: DocTree.new("HI HELLO HI")
        }
      }
  end

  test "handle_change" do
    change_request = {:change, {:delete, 10, 5}, 10}

    changelog = [
        %{id: 12, change: {:insert, 5, "HI HELLO"}, from: self()},
        %{id: 11, change: {:delete, 12, 5}, from: self()},
        %{id: 10, change: {:insert, 10, "NOT COUNTED"}, from: self()}
      ]

    doctree = DocTree.new("123456789012345678901234567890")

    state = %{
      changelog: changelog,
      clients: [self()],
      current_id: 13,
      doctree: doctree
    }

    sender = spawn(fn -> nil end)

    {:reply, response, new_state} = DocServer.handle_change(
      change_request,
      {sender, nil},
      state
    )

    assert new_state.changelog == [%{id: 13, change: {:delete, 18, 2}, from: sender} | changelog]
    assert new_state.clients == [self()]
    assert new_state.current_id == 14
    assert new_state.doctree == DocTree.delete(doctree, 18, 2)

    assert_receive {:change, {:delete, 18, 2}, 13}, 5000

    assert response == {:ok, 13}
  end
end

defmodule Nc.Servers.DocServerIntegrationTest do
  use ExUnit.Case, async: true

  alias Nc.Servers.DocServer

  setup do
    docserver = start_supervised!({DocServer, "12345678901234567890"})
    %{docserver: docserver}
  end

  test "DocServer single client", %{docserver: docserver} do

    {:ok, _} = GenServer.call(docserver, {:change, {:insert, 10, "TESTING..."}, 0})
    {:ok, _} = GenServer.call(docserver, {:change, {:insert, 5, "HI HELLO"}, 1})
    {:ok, _} = GenServer.call(docserver, {:change, {:delete, 12, 5}, 2})

    assert DocServer.read(docserver) == "12345HI HELL0TESTING...1234567890"
  end

  test "DocServer many client 1", %{docserver: docserver} do

    _sender = Task.await(Task.async(fn ->
      {:ok, 1} = GenServer.call(docserver, {:change, {:insert, 10, "TESTING..."}, 0})
    end))
    _sender = Task.await(Task.async(fn ->
      {:ok, 2} = GenServer.call(docserver, {:change, {:insert, 5, "HI HELLO"}, 0})
    end))
    _sender = Task.await(Task.async(fn ->
      {:ok, 3} = GenServer.call(docserver, {:change, {:delete, 12, 5}, 0})
    end))

    assert DocServer.read(docserver) == "12345HI HELLO67890TESTING...12890"
  end
end
