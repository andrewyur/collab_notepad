defmodule Nc.Servers.DocServer do
  @moduledoc """
  The core functionality for hosting a document
  """

  use GenServer

  alias Nc.Core.DocTree

  @type change() :: {
    :insert,
    position :: non_neg_integer(),
    text :: String.t()
  } | {
    :delete,
    position :: non_neg_integer(),
    amount :: non_neg_integer()
  }

  @type log() :: %{
    id: non_neg_integer(),
    change: change(),
    from: pid()
  }

  @type change_request :: {
    :change,
    change(),
    last_synced :: non_neg_integer()
  }

  @type state() :: %{
    changelog: [log()],
    clients: [pid()],
    current_id: non_neg_integer(),
    doctree: Nc.Core.DocTree.t()
  }

  @spec start_link(String.t()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(text) do
    GenServer.start_link(__MODULE__, text)
  end

  @spec init(String.t()) :: {:ok, state()}
  def init(text) do
    # current_id is 1 because version 0 is the starting text
    {:ok, %{ doctree: DocTree.new(text), changelog: [], current_id: 1, clients: []}}
  end

  @spec transform_change(
    change(),
    non_neg_integer(),
    pid(),
    [log()]
  ) :: change()
  def transform_change(change, last_synced, from, changelog) do
    case changelog do
      [head | rest] when head.id > last_synced ->
        change = transform_change(change, last_synced, from, rest)
        if(from != head.from) do
          Nc.Sync.Transforms.transform_outgoing(change, head.change)
        else
          change
        end
      _ -> change
    end
  end

  def handle_call(request, from, state) do
    case request do
      :start -> handle_start(from, state)
      :read -> handle_read(state)
      :state -> {:reply, state, state}
      _ -> handle_change(request, from, state)
    end
  end

  #message passing copies its contents, so we want to do this as little as possible.
  @spec handle_start(GenServer.from(), state()) :: {:reply, response :: map(), state()}
  def handle_start(from, current_state) do
    {
      :reply,
      %{
        current_id: current_state.current_id,
        current_doctree: current_state.doctree
      },
      %{ current_state | clients: [elem(from, 0) | current_state.clients]}
    }
  end

  @spec handle_read(state()) :: {:reply, response :: String.t(), state()}
  def handle_read(current_state) do
    {:reply, Nc.Core.DocTree.tree_to_string(current_state.doctree), current_state}
  end

  @spec handle_change(change_request(), GenServer.from(), state()) :: {:reply, {:ok, non_neg_integer()}, state()}
  def handle_change(request, from, current_state) do

    {
      :change,
      change,
      last_synced
    } = request

    %{
      changelog: changelog,
      clients: clients,
      current_id: current_id,
      doctree: doctree
    } = current_state

    # transform the change with changes in the changelog with ids greater than last_synced
    change = transform_change(change, last_synced, elem(from, 0), changelog)

    # apply the transformed request
    new_doctree = case change do
      {:insert, position, text} ->
        DocTree.insert(doctree, max(position, 0), text)
      {:delete, position, amount} ->
        DocTree.delete(doctree, max(position, 0), max(amount, 0))
    end

    # occasionally restructure the doctree
    new_doctree = if rem(current_id, 50) == 0 do
      DocTree.restructure_if_necessary(new_doctree)
    else
      new_doctree
    end

    # send change out to all other clients, along with change version
    Enum.each(clients, fn client ->
      if client != elem(from, 0) do
        send(client, {:change, change, current_id})
      end
    end)

    new_log = %{
      id: current_id,
      change: change,
      from: elem(from, 0),
    }

    new_state = %{
      current_state |
      doctree: new_doctree,
      changelog: [new_log | changelog],
      current_id: current_id + 1,
    }

    # acknowledge
    {:reply, {:ok, current_id}, new_state}
  end

  @spec read(pid()) :: any()
  def read(docserver) do
    GenServer.call(docserver, :read)
  end

  @spec kill(pid()) :: any()
  def kill(docserver) do
    GenServer.stop(docserver)
  end
end
