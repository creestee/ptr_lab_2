defmodule PtrLab2.MixProject do
  use Mix.Project

  def project do
    [
      app: :ptr_lab_2,
      version: "0.1.0",
      elixir: "~> 1.14",
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
      {:httpoison, "~> 2.0"},
      {:json, "~> 1.4"},
      {:statistics, "~> 0.6.2"}
    ]
  end
end
