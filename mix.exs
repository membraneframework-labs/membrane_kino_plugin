defmodule Membrane.Kino.Mixfile do
  use Mix.Project

  @version "0.3.2"
  @github_url "https://github.com/membraneframework-labs/membrane_kino_plugin/"

  def project do
    [
      app: :membrane_kino_plugin,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # hex
      description: "Kino Plugin for Membrane Multimedia Framework",
      package: package(),

      # docs
      name: "Membrane Kino plugin",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:membrane_core, "~> 1.0"},
      {:kino, "~> 0.9.4"},
      {:membrane_h264_format, "~> 0.6.1"},
      {:membrane_aac_format, "~> 0.8.0"},
      {:membrane_opus_format, "~> 0.3.0"},
      {:membrane_matroska_format, "~> 0.1.0"},
      {:membrane_funnel_plugin, "~> 0.9.0"},

      # Testing
      {:membrane_file_plugin, "~> 0.17.0"},
      {:membrane_raw_video_format, "~> 0.4.0", only: :test},
      {:membrane_opus_plugin, "~> 0.19.1", only: :test},
      {:membrane_aac_fdk_plugin, "~> 0.18.2", only: :test},
      {:membrane_matroska_plugin, "~> 0.5.1", only: :test},
      {:membrane_generator_plugin, "~> 0.10.0", only: :test},

      # Development
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling]
    ]

    if System.get_env("CI") == "true" do
      # Store PLTs in cacheable directory for CI
      [plt_local_path: "priv/plts", plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.Kino]
    ]
  end
end
