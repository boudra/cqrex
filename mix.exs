defmodule Cqrex.Mixfile do
  use Mix.Project

  def project do
    [app: :cqrex,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test],
   ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:phoenix, :cowboy, :logger, :postgrex, :ecto],
      mod: {Main, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:excoveralls, "~> 0.4", only: :test},
      {:exrm, "~> 1.0.0-rc7"},
      {:postgrex, ">= 0.0.0"},
      {:sqlite_ecto, "~> 1.0.0"},
      {:ecto, "~> 1.1"},
      {:phoenix, "~> 1.1"},
      {:exprof, "~> 0.2.0", only: :test},
      {:poison, "~> 1.5"},
      {:cowboy, "~> 1.0"}
    ]
  end
end
