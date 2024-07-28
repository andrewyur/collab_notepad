defmodule Nc.System.DocumentRegistry do
  def start_link(args) do
    Registry.start_link(args)
  end

  def via_tuple(id, name) do
    {:via, Registry, {__MODULE__, id, name}}
  end

  def child_spec(_arg) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def get_document(id) do
    Registry.lookup(__MODULE__, id)
  end
end
