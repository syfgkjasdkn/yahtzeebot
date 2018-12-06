defmodule Yahtzeebot.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      dialyzer: dialyzer(),
      deps: deps()
    ]
  end

  defp dialyzer do
    [
      flags: [:error_handling, :race_conditions, :underspecs]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:distillery, "~> 2.0", runtime: false},
      {:dialyxir, "~> 1.0-rc", runtime: false, only: :dev}
    ]
  end
end
