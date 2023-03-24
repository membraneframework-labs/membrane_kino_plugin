defmodule Membrane.Kino.Input do
  use Kino.JS, assets_path: "lib/assets/audio_input"
  use Kino.JS.Live

  def new() do
    Kino.JS.Live.new(__MODULE__, nil)
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, nil, ctx}
  end
end
