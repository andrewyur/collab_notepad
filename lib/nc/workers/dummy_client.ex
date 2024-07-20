defmodule Nc.Workers.DummyClient do
  @moduledoc """
  this is just for internal testing, and to figure out the client logic. the end goal is for the client's state to be kept on the client
  """

  use Agent

  alias Nc.Workers.DummyClientState

  @spec start_link(pid()) :: {:error, any()} | {:ok, pid()}
  def start_link(server) do
    Agent.start_link(fn ->
      {server_document, current_id} = GenServer.call(server, :start)

      DummyClientState.new(server, server_document, current_id)
    end)
  end

  @spec insert(pid(), non_neg_integer(), String.t()) :: :ok
  def insert(client, position, text) do
    Agent.update(
      client,
      &DummyClientState.make_change(&1, {:insert, position, text, self()})
    )
  end

  @spec delete(pid(), non_neg_integer(), non_neg_integer()) :: :ok
  def delete(client, position, amount) do
    Agent.update(
      client,
      &DummyClientState.make_change(&1, {:delete, position, amount, self()})
    )
  end

  # these synchronization functions will happen asynchronously in the actual client, no point in doing that here though

  @spec push(pid()) :: :ok
  def push(client) do
    Agent.update(client, fn state ->
      {state, changes} = DummyClientState.start_push(state)

      GenServer.call(state.server, {:push, changes})

      state
    end)
  end

  @spec pull(pid()) :: :ok
  def pull(client) do
    Agent.update(client, fn state ->
      {state, last_pulled} = DummyClientState.start_pull(state)

      {pulled_changes, current_id} = GenServer.call(state.server, {:pull, last_pulled})

      DummyClientState.recieve_pull(state, pulled_changes, current_id)
    end)
  end

  @spec read(pid()) :: String.t()
  def read(client) do
    Agent.get(client, fn state -> state.document end) |> Nc.Core.DocTree.tree_to_string()
  end

  @spec kill(pid()) :: :ok
  def kill(client) do
    Agent.stop(client)
  end

  @spec debug(pid()) :: DummyClientState.t()
  def debug(client) do
    Agent.get(client, & &1)
  end
end
