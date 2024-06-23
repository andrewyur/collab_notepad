defmodule Mdc.Servers.DocServer do
  use GenServer

  alias Mdc.Core.DocTree

  def init(text) do
    DocTree.new(text)
  end

  def handle_cast(request, current_doctree) do
    new_doctree =
      case request do
        {:insert, position, text} ->
          DocTree.insert(current_doctree, position, text)
        {:delete, position, amount} ->
          DocTree.delete(current_doctree, position, amount)
      end

      {:noreply, new_doctree}
  end
end
