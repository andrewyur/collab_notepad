defmodule Nc.Servers.ClientServer do
  @moduledoc """
  this is just for internal testing, and to figure out the client logic. the end goal is for the client's state to be kept on the client
  """

  use Agent

  alias Nc.Servers.DocServer

  @type state() :: %{
          last_pulled: non_neg_integer(),
          document: String.t(),
          server: pid(),
          pending_changes: [DocServer.change()]
        }

  @spec start_link(pid()) :: {:error, any()} | {:ok, pid()}
  def start_link(docserver) do
    server_state = GenServer.call(docserver, :start)

    client_state = %{
      last_pulled: server_state.current_id,
      document: Nc.Core.DocTree.tree_to_string(server_state.current_doctree),
      server: docserver,
      pending_changes: []
    }

    Agent.start_link(fn ->
      client_state
    end)
  end

  @spec apply_change(DocServer.change(), String.t()) :: String.t()
  defp apply_change(change, document) do
    case change do
      {:insert, position, text} ->
        document_insert(document, position, text)

      {:delete, position, amount} ->
        document_delete(document, position, amount)
    end
  end

  @spec document_insert(String.t(), non_neg_integer(), String.t()) :: String.t()
  defp document_insert(string, position, text) do
    {front, back} = String.split_at(string, position)
    front <> text <> back
  end

  @spec document_delete(String.t(), non_neg_integer(), non_neg_integer()) :: String.t()
  defp document_delete(string, position, amount) do
    {front, rest} = String.split_at(string, position)
    {_, back} = String.split_at(rest, amount)
    front <> back
  end

  @spec handle_edit(DocServer.change(), state()) :: state()
  def handle_edit(change, state) do
    new_document = apply_change(change, state.document)

    new_pending_changes = [change | state.pending_changes]

    %{
      state
      | document: new_document,
        pending_changes: new_pending_changes
    }
  end

  # assuming recieve searches the process mailbox from earliest to latest,
  # these should be sorted from earliest to latest
  @spec collect_change_messages() :: {[DocServer.change()], integer()}
  def collect_change_messages() do
    receive do
      {:change, change, current_id} ->
        {changes, new_id} = collect_change_messages()
        {[change | changes], max(current_id, new_id)}
    after
      0 ->
        {[], -1}
    end
  end

  @spec transform_incoming(DocServer.change(), [DocServer.change()]) ::
          {[DocServer.change()] | DocServer.change() | nil, [DocServer.change()]}
  def transform_incoming(incoming_change, pending_changes) do
    case pending_changes do
      [pending_change | pending_changes] ->
        localized_change = Nc.Sync.Transforms.transform_incoming(incoming_change, pending_change)

        case localized_change do
          nil ->
            new_pending_change =
              Nc.Sync.Transforms.transform_outgoing(pending_change, incoming_change)

            {nil, [new_pending_change | pending_changes]}

          {_, _, _} ->
            new_pending_change =
              Nc.Sync.Transforms.transform_outgoing(pending_change, incoming_change)

            {new_localized_change, pending_changes} =
              transform_incoming(localized_change, pending_changes)

            {new_localized_change, [new_pending_change | pending_changes]}

          [change1, change2] ->
            binding() |> IO.inspect()
            {new_change1, pending_changes1} = transform_incoming(change1, pending_changes)
            {new_change2, pending_changes2} = transform_incoming(change2, pending_changes1)

            new_pending_change =
              Nc.Sync.Transforms.transform_outgoing(pending_change, incoming_change)

            {[new_change1, new_change2], [new_pending_change | pending_changes2]}
        end

      [] ->
        {incoming_change, pending_changes}
    end
  end

  # I know this code is very gross looking, maybe ill clean it up later

  # expects pending changes in chronological order
  @spec localize_incoming([DocServer.change()], [DocServer.change()]) ::
          {[DocServer.change()], [DocServer.change()]}
  def localize_incoming(incoming_changes, pending_changes) do
    case incoming_changes do
      [incoming | incoming_rest] ->
        incoming |> IO.inspect(label: "incoming")
        pending_changes |> IO.inspect(label: "pending")

        localized =
          transform_incoming(incoming, pending_changes) |> IO.inspect(label: "localized")

        pending =
          Enum.map(
            pending_changes,
            fn pending_change ->
              Nc.Sync.Transforms.transform_outgoing(pending_change, incoming)
            end
          )
          |> IO.inspect(label: "new pending")

        case localized do
          nil ->
            localize_incoming(incoming_rest, pending)

          {_, _, _} ->
            {rest_localized, rest_pending} = localize_incoming(incoming_rest, pending)
            {[localized | rest_localized], rest_pending}

          [_change1, _change2] ->
            localized = List.flatten(localized) |> Enum.filter(& &1)
            {rest_localized, rest_pending} = localize_incoming(incoming_rest, pending)
            {localized ++ rest_localized, rest_pending}
        end

      [] ->
        {[], pending_changes}
    end
  end

  @spec handle_pull(state()) :: state()
  def handle_pull(state) do
    %{
      document: document,
      pending_changes: pending_changes
    } = state

    # collect all existing :change messages from the mailbox
    {incoming_changes, current_id} =
      collect_change_messages() |> IO.inspect(label: "incoming changes")

    if current_id == -1 do
      # it would be cool if there were an early return in elixir...
      state
    else
      # transform those incoming changes against the client's list of pending changes
      localized_incoming_changes =
        localize_incoming(incoming_changes, Enum.reverse(pending_changes))
        |> IO.inspect(label: "localized changes")

      # apply those transformed changes
      new_document = Enum.reduce(localized_incoming_changes, document, &apply_change/2)

      #  transform the pending changes against the incoming ones
      transformed_pending_changes =
        Enum.map(pending_changes, fn pending_change ->
          Enum.reduce(localized_incoming_changes, pending_change, fn transformer, transformee ->
            Nc.Sync.Transforms.transform_outgoing(transformee, transformer)
          end)
        end)

      %{
        state
        | last_pulled: current_id,
          document: new_document,
          pending_changes: transformed_pending_changes
      }
    end
  end

  @spec handle_push(state()) :: state()
  def handle_push(state) do
    # unfortunately, one of the downfalls of OT is that transformations cannot be reversed
    # without storing some sort of additional information about how it was affected.
    # because this is a lot of effort to add, and because the space required grows exponentially
    # with every new change, this is unfeasable to implement, hence the call to pull_changes here.
    # (i assume this is the reason why you must pull before pushing in git)
    state = handle_pull(state)

    # order matters here... pending changes are in reverse chronological order
    # we want to send the server the changes in chronological order

    Enum.reverse(state.pending_changes)
    |> Enum.map(fn change ->
      GenServer.call(
        state.server,
        {:change, change, state.last_pulled}
      )
    end)

    %{
      state
      | pending_changes: []
    }
  end

  @spec insert(pid(), non_neg_integer(), String.t()) :: any()
  def insert(client, position, text) do
    Agent.update(client, &handle_edit({:insert, position, text}, &1))
  end

  @spec delete(pid(), non_neg_integer(), non_neg_integer()) :: any()
  def delete(client, position, amount) do
    Agent.update(client, &handle_edit({:delete, position, amount}, &1))
  end

  @spec push(pid()) :: any()
  def push(client) do
    Agent.update(client, &handle_push/1)
  end

  @spec pull(pid()) :: any()
  def pull(client) do
    Agent.update(client, &handle_pull/1)
  end

  # realistically, this is how the client would work if i were trying to create a seamless editing experience
  # but i have already done all the work to allow pull & push to happen separately
  # it would be fun to let the user control when they push and pull though
  @spec sync(pid()) :: any()
  def sync(client) do
    Agent.update(client, &handle_pull/1)
    Agent.update(client, &handle_push/1)
  end

  @spec read(pid()) :: any()
  def read(client) do
    Agent.get(client, fn state -> state.document end)
  end

  @spec kill(pid()) :: any()
  def kill(client) do
    Agent.stop(client)
  end
end
