defmodule Nc.System.Config do
  def start_system do
    Supervisor.start_link(
      [
        Nc.System.DocumentRegistry,
        Nc.System.DocumentSupervisor
      ],
      strategy: :one_for_one
    )
  end
end
