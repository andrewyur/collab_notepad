defmodule Nc.Workers.Document do
  @moduledoc """
  The core functionality for hosting a document
  """

  use GenServer, restart: :temporary

  alias Nc.Core.Sync
  alias Nc.Core.DocTree
  alias Nc.Workers.DocumentState
  alias Nc.System.DocumentRegistry

  def start_link({id, name, text}) do
    GenServer.start_link(__MODULE__, {name, text}, name: DocumentRegistry.via_tuple(id, name))
  end

  def init({name, text}) do
    {:ok, DocumentState.new(name, text)}
  end

  def handle_call(request, from, state) do
    client = elem(from, 0)

    case request do
      :start -> handle_start(state, client)
      :end -> handle_end(state, client)
      {:pull, last_pulled} -> handle_pull(state, client, last_pulled)
      {:push, changes} -> handle_push(state, client, changes)
    end
  end

  @spec handle_start(DocumentState.t(), pid()) ::
          {:reply, {:start, DocTree.t(), non_neg_integer(), String.t()}, DocumentState.t(),
           timeout()}
  def handle_start(state, from) do
    {state, document, current_id, name} = DocumentState.add_new_client(state, from)

    # GenServer.cast doesn't trigger handle_info...
    Enum.each(Map.keys(state.clients), fn pid ->
      send(pid, {:editor, Enum.count(state.clients)})
    end)

    {:reply, {:start, document, current_id, name}, state, 1000 * 60 * 15}
  end

  def handle_end(state, from) do
    state = DocumentState.remove_client(state, from)

    Enum.each(Map.keys(state.clients), fn pid ->
      send(pid, {:editor, Enum.count(state.clients)})
    end)

    if Enum.empty?(state.clients) do
      {:reply, :ok, state, 1000 * 5}
    else
      {:reply, :ok, state, 1000 * 60 * 15}
    end
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  @spec handle_pull(DocumentState.t(), pid(), non_neg_integer()) ::
          {:reply, {:pull, [Sync.change()], non_neg_integer()}, DocumentState.t(), timeout()}
  def handle_pull(state, from, last_pulled) do
    {state, pulled_changes, current_id} = DocumentState.handle_pull(state, from, last_pulled)

    {:reply, {:pull, pulled_changes, current_id}, state, 1000 * 60 * 15}
  end

  @spec handle_push(DocumentState.t(), pid(), [Sync.change()]) ::
          {:reply, :push, DocumentState.t(), timeout()}
  def handle_push(state, from, changes) do
    state = DocumentState.handle_push(state, from, changes)

    {:reply, :push, state, 1000 * 60 * 15}
  end
end
