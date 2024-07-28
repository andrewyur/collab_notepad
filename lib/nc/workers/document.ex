defmodule Nc.Workers.Document do
  @moduledoc """
  The core functionality for hosting a document
  """

  use GenServer, restart: :temporary

  alias Nc.Core.Sync
  alias Nc.Core.DocTree
  alias Nc.Workers.DocumentState
  alias Nc.System.DocumentRegistry

  def start_link(id) do
    GenServer.start_link(__MODULE__, nil, name: DocumentRegistry.via_tuple(id))
  end

  def init(_init_arg) do
    {:ok,
     DocumentState.new(
       "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
     )}
  end

  def handle_call(request, from, state) do
    client = elem(from, 0)

    case request do
      :start -> handle_start(state, client)
      :end -> handle_end(state, client)
      :read -> handle_read(state)
      :debug -> handle_debug(state)
      {:pull, last_pulled} -> handle_pull(state, client, last_pulled)
      {:push, changes} -> handle_push(state, client, changes)
    end
  end

  @spec handle_start(DocumentState.t(), pid()) ::
          {:reply, {:start, DocTree.t(), non_neg_integer()}, DocumentState.t()}
  def handle_start(state, from) do
    {state, document, current_id} = DocumentState.add_new_client(state, from)

    {:reply, {:start, document, current_id}, state}
  end

  def handle_end(state, from) do
    state = DocumentState.remove_client(state, from)

    if Enum.count(state.clients) == 0 do
      # 5 second time out after last client has left
      {:reply, :ok, state, 5000}
    else
      {:reply, :ok, state}
    end
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  @spec handle_debug(DocumentState.t()) :: {:reply, DocumentState.t(), DocumentState.t()}
  def handle_debug(state) do
    {:reply, state, state}
  end

  # for testing purposes only
  @spec handle_read(DocumentState.t()) :: {:reply, String.t(), DocumentState.t()}
  def handle_read(state) do
    {:reply, DocTree.tree_to_string(state.document), state}
  end

  @spec handle_pull(DocumentState.t(), pid(), non_neg_integer()) ::
          {:reply, {:pull, [Sync.change()], non_neg_integer()}, DocumentState.t()}
  def handle_pull(state, from, last_pulled) do
    {state, pulled_changes, current_id} = DocumentState.handle_pull(state, from, last_pulled)

    {:reply, {:pull, pulled_changes, current_id}, state}
  end

  @spec handle_push(DocumentState.t(), pid(), [Sync.change()]) ::
          {:reply, :push, DocumentState.t()}
  def handle_push(state, from, changes) do
    state = DocumentState.handle_push(state, from, changes)

    {:reply, :push, state}
  end

  @spec read(pid()) :: String.t()
  def read(server) do
    GenServer.call(server, :read)
  end

  @spec kill(pid()) :: :ok
  def kill(server) do
    GenServer.stop(server)
  end

  @spec debug(pid()) :: DocumentState.t()
  def debug(server) do
    GenServer.call(server, :debug)
  end
end
