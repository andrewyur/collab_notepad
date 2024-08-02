defmodule Nc.System.Application do
  use Application

  @impl Application
  def start(_start_type, _start_args) do
    Supervisor.start_link(
      [
        Nc.System.DocumentRegistry,
        Nc.System.DocumentSupervisor,
        {Bandit, bandit_options()}
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  defp bandit_options do
    [
      plug: Nc.System.Router,
      port: 4000
    ]
  end
end
