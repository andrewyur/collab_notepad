defmodule MarkdownCollab.MixProject do
  use Mix.Project

  def project do
    [
      app: :collab_notepad,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      releases: [
        collab_notepad: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent, logger: :permanent]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Nc.System.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_uuid, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:poison, "~> 6.0"},
      {:websock_adapter, "~> 0.5.6"},
      {:hammer, "~> 6.2"},
      {:credo, "~> 1.7"},
      {:remote_ip, "~> 1.2"}
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
