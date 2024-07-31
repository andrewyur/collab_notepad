defmodule Nc.Workers.DocumentState do
  @moduledoc """
  the definition of the server state is done here, as well as all of the functions for manipulating the state
  """

  # all lists will be in proper chronological order! premature optimization causes a lot of problems. Ill fix it when I get to it.

  alias Nc.Core.Sync
  alias Nc.Core.DocTree

  @type t() :: %{
          document: DocTree.t(),
          name: String.t(),
          current_id: non_neg_integer(),
          changelog: [changelog()],
          clients: %{pid() => [Sync.change()]}
        }

  @type changelog() :: %{
          change: Sync.change(),
          version: non_neg_integer()
        }

  @spec new(String.t(), String.t()) :: t()
  def new(name, text) do
    %{
      document: DocTree.new(text),
      name: name,
      current_id: 1,
      changelog: [],
      clients: %{}
    }
  end

  defp apply_change(document, change) do
    case change do
      {:insert, position, text, _from} ->
        DocTree.insert(document, position, text)

      {:delete, position, amount, _from} ->
        DocTree.delete(document, position, amount)

      nil ->
        document
    end
  end

  defp apply_change_list(document, change_list) do
    Enum.reduce(change_list, document, &apply_change(&2, &1))
  end

  @spec add_new_client(t(), pid()) :: {t(), DocTree.t(), non_neg_integer(), String.t()}
  def add_new_client(state, client_pid) do
    {
      %{
        state
        | clients: Map.put_new(state.clients, client_pid, [])
      },
      state.document,
      state.current_id - 1,
      state.name
    }
  end

  def remove_client(state, client_pid) do
    %{
      state
      | clients: Map.delete(state.clients, client_pid)
    }
  end

  # assumes client is up to date or will transform the changes
  @spec handle_pull(t(), pid(), non_neg_integer()) :: {t(), [Sync.change()], non_neg_integer()}
  def handle_pull(state, client_pid, last_pulled) do
    relevant_changes =
      for %{change: change, version: version} when version > last_pulled <- state.changelog,
          do: change

    {%{
       state
       | clients: Map.put(state.clients, client_pid, [])
     }, relevant_changes, state.current_id - 1}
  end

  @spec handle_push(t(), pid(), [Sync.change()]) :: t()
  def handle_push(state, client_pid, client_changes) do
    %{
      document: document,
      current_id: current_id,
      changelog: changelog,
      clients: clients
    } = state

    client_changelog = Map.fetch!(clients, client_pid)

    {changes_to_apply, new_client_changelog} =
      Sync.reconcile_against(client_changes, client_changelog)

    new_document = apply_change_list(document, changes_to_apply)

    new_clients =
      for {c_pid, c_changelog} <- clients, into: %{}, do: {c_pid, c_changelog ++ changes_to_apply}

    new_clients = Map.put(new_clients, client_pid, new_client_changelog)

    new_changelog =
      changelog ++
        (Enum.zip(changes_to_apply, Stream.iterate(current_id, &(&1 + 1)))
         |> Enum.map(fn {change, version} -> %{change: change, version: version} end))

    new_current_id = Enum.count(client_changes) + current_id

    %{
      state
      | document: new_document,
        current_id: new_current_id,
        changelog: new_changelog,
        clients: new_clients
    }
  end
end
