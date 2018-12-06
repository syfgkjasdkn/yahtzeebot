defmodule TGBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :tgbot,
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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nadia, "~> 0.4"},
      {:core, in_umbrella: true},
      {:httpoison, "~> 1.4", override: true},
      {:mox, "~> 0.4", only: :test}
    ]
  end
end
