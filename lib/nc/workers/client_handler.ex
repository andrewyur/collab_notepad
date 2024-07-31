defmodule Nc.Workers.ClientHandler do
  @moduledoc """
  this module implements the WebSock behaviour, and translates the json messages the client sends through the websocket server into erlang terms, and sends them as messages to the server
  """

  # this needs to be rate limited
  def handle_in({json, [opcode: :text]}, {pid, ip}) do
    with {:allow, _} <- Hammer.check_rate("msg:#{ip}", 500, 10),
         {:ok, map} <- Poison.decode(json),
         {:ok, {message, id}} <- json_to_message(map) do
      response =
        GenServer.call(pid, message)
        |> response_to_json()

      str =
        Poison.encode!(%{
          id: id,
          response: response
        })

      {:push, {:text, str}, {pid, ip}}
    else
      # any incorrect/invalid websocket messages will come from outside code
      _ -> {:push, {:text, "Error"}, {pid, ip}}
    end
  end

  def init({id, ip}) do
    case Registry.lookup(Nc.System.DocumentRegistry, id) do
      [{pid, _}] ->
        {:ok, {pid, ip}}

      [] ->
        {:stop, :normal, {1000, "Document Not Found"}, id}
    end
  end

  def handle_info(message, {pid, ip}) do
    case message do
      {:editor, editors} ->
        {:push, {:text, Poison.encode!(%{type: :editor, editors: editors})}, {pid, ip}}

      _ ->
        {:ok, {pid, ip}}
    end
  end

  def terminate(:remote, {pid, _ip}) do
    GenServer.call(pid, :end)
  end

  # need to have a matching clause for the rest of the terminate clause
  def terminate(_, _), do: nil

  # I would much prefer to not have to do this manually, but there are not a lot of options at the moment
  def json_to_message(map) do
    case map["message"] do
      "start" ->
        {:ok, {:start, map["id"]}}

      %{
        "type" => "push",
        "changes" => changes
      } ->
        {:ok, {{:push, Enum.map(changes, &map_to_change/1)}, map["id"]}}

      %{
        "type" => "pull",
        "lastPulled" => last_pulled
      } ->
        {:ok, {{:pull, last_pulled}, map["id"]}}

      _ ->
        {:error, "unrecognized message"}
    end
  end

  def map_to_change(map) do
    case map do
      %{
        "type" => "insert",
        "position" => position,
        "text" => text,
        "from" => from
      } ->
        {:insert, position, text, from}

      %{
        "type" => "delete",
        "position" => position,
        "amount" => amount,
        "from" => from
      } ->
        {:delete, position, amount, from}

      _ ->
        nil
    end
  end

  def change_to_map(change) do
    case change do
      nil ->
        nil

      {:insert, position, text, from} ->
        %{
          "type" => "insert",
          "position" => position,
          "text" => text,
          "from" => from
        }

      {:delete, position, amount, from} ->
        %{
          "type" => "delete",
          "position" => position,
          "amount" => amount,
          "from" => from
        }
    end
  end

  def response_to_json(message) do
    case message do
      {:start, doctree, current_verison, name} ->
        %{
          "type" => "start",
          "document" => Nc.Core.DocTree.tree_to_string(doctree),
          "currentId" => current_verison,
          "title" => name
        }

      :push ->
        "push"

      {:pull, pulled_changes, current_id} ->
        %{
          "type" => "pull",
          "pulledChanges" => Enum.map(pulled_changes, &change_to_map/1),
          "currentId" => current_id
        }
    end
  end
end
