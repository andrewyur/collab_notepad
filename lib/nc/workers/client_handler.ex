# this module implements the WebSock behaviour, and translates the json messages the client sends through the websocket server into erlang terms, and sends them as messages to the server
defmodule Nc.Workers.ClientHandler do
  def handle_in({_json, [opcode: :text]}, state) do
    {:push, {:text, "HELLO"}, state}
  end

  def init(id) do
    case Registry.lookup(Nc.System.DocumentRegistry, id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        {:stop, :normal, {1000, "Document Not Found"}, id}
    end
  end
end
