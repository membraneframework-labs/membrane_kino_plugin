# Membrane Kino Plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_template_plugin.svg)](https://hex.pm/packages/membrane_template_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_template_plugin)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_template_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_template_plugin)

Package required to play media in the Livebook, directly from the Membrane pipeline.

Supports playing audio and video streams.

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

The package can be installed by adding `membrane_kino_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_kino_plugin, github: "membraneframework-labs/membrane_kino_plugin", tag: "v0.3.2"}
  ]
end
```

## Usage

For usage examples, see livebooks in the [`examples`](./examples) directory.
