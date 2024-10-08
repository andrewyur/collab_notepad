defmodule Nc.System.DocumentSupervisor do
  @moduledoc """
  Dynamic supervisor for starting documents
  """

  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def new_document(name, text) do
    document_id = UUID.uuid4()

    {DynamicSupervisor.start_child(__MODULE__, {Nc.Workers.Document, {document_id, name, text}}),
     document_id}
  end
end
