defmodule UBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :ubot,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {UBot.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # TODO consider https://github.com/lattenwald/erl-tdlib
      # it uses rust nifs instead of stdin/stdout
      {:tdlib, github: "syfgkjasdkn/tdlib", tag: "v0.0.3"},
      {:core, in_umbrella: true},
      {:tgbot, in_umbrella: true}
    ]
  end
end
