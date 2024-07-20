defmodule Nc.System.DocumentSupervisor do
  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def new_document do
    document_id = UUID.uuid4()
    DynamicSupervisor.start_child(__MODULE__, {Nc.Workers.Server, {document_id, ""}})
  end
end
