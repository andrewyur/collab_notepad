# this module implements the WebSock behaviour, and translates the json messages the client sends through the websocket server into erlang terms, and sends them as messages to the server
defmodule Nc.Workers.ClientHandler do
  def handle_in({json, [opcode: :text]}, pid) do
    message = json_to_message(json)

    response =
      GenServer.call(pid, message)
      |> response_to_json()
      |> Poison.encode!()

    {:push, {:text, response}, pid}
  end

  def init(id) do
    case Registry.lookup(Nc.System.DocumentRegistry, id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        {:stop, :normal, {1000, "Document Not Found"}, id}
    end
  end

  # I would much prefer to not have to do this manually, but there are not a lot of options at the moment
  def json_to_message(json_string) do
    case Poison.decode!(json_string) do
      "start" ->
        :start

      %{
        "type" => "push",
        "changes" => changes
      } ->
        {:push, Enum.map(changes, &map_to_change/1)}

      %{
        "type" => "pull",
        "lastPulled" => last_pulled
      } ->
        {:pull, last_pulled}
    end
  end

  def map_to_change(map) do
    case map do
      nil ->
        nil

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
      {:start, doctree, current_verison} ->
        %{
          "type" => "start",
          "document" => Nc.Core.DocTree.tree_to_string(doctree),
          "currentId" => current_verison
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
