defmodule MarkdownCollab.MixProject do
  use Mix.Project

  def project do
    [
      app: :collab_notepad,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [ignore_warnings: "config/dialyzer.ignore"],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
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
