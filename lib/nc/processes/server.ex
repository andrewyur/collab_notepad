defmodule Nc.Processes.Server do
  @moduledoc """
  The core functionality for hosting a document
  """

  use GenServer

  alias Nc.Sync
  alias Nc.Processes.ServerState
  alias Nc.Core.DocTree

  @spec start_link(String.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(text) do
    GenServer.start_link(__MODULE__, text)
  end

  @spec init(String.t()) :: {:ok, ServerState.t()}
  def init(text) do
    {:ok, ServerState.new(text)}
  end

  def handle_call(request, from, state) do
    client = elem(from, 0)

    case request do
      :start -> handle_start(client, state)
      :read -> handle_read(state)
      {:pull, last_pulled} -> handle_pull(state, client, last_pulled)
      {:push, changes} -> handle_push(state, client, changes)
    end
  end

  @spec handle_start(pid(), ServerState.t()) ::
          {:reply, {DocTree.t(), non_neg_integer()}, ServerState.t()}
  def handle_start(from, state) do
    {state, document, current_id} = ServerState.add_new_client(state, from)

    {:reply, {document, current_id}, state}
  end

  # for testing purposes only
  @spec handle_read(ServerState.t()) :: {:reply, String.t(), ServerState.t()}
  def handle_read(state) do
    {:reply, DocTree.tree_to_string(state.document), state}
  end

  @spec handle_pull(ServerState.t(), pid(), non_neg_integer()) ::
          {:reply, {[Sync.change()], non_neg_integer()}, ServerState.t()}
  def handle_pull(state, from, last_pulled) do
    {state, pulled_changes, current_id} = ServerState.handle_pull(state, from, last_pulled)

    {:reply, {pulled_changes, current_id}, state}
  end

  @spec handle_push(ServerState.t(), pid(), [Sync.change()]) :: {:reply, :ok, ServerState.t()}
  def handle_push(state, from, changes) do
    state = ServerState.handle_push(state, from, changes)

    {:reply, :ok, state}
  end

  @spec read(pid()) :: String.t()
  def read(docserver) do
    GenServer.call(docserver, :read)
  end

  @spec kill(pid()) :: :ok
  def kill(docserver) do
    GenServer.stop(docserver)
  end
end
