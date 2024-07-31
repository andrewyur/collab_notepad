defmodule Nc.System.Config do
  @moduledoc """
  Configuration options for various services, (should probably be moved to config.exs...)
  """

  def start_system do
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
