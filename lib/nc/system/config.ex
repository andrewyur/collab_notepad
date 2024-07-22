defmodule Nc.System.Config do
  def start_system do
    Supervisor.start_link(
      [
        Nc.System.DocumentRegistry,
        Nc.System.DocumentSupervisor,
        {Bandit, bandit_options()}
      ],
      strategy: :one_for_one
    )
  end

  defp bandit_options do
    [
      plug: Nc.System.Router,
      port: 4000
    ]
  end
end
