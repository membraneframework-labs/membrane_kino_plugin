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

  @impl true
  def handle_event("audio_frame", {:binary, info, binary}, ctx) do
    if Map.has_key?(ctx.assigns, :client) do
      send(ctx.assigns.client, {:audio_frame, info, binary})
    end

    {:noreply, ctx}
  end

  @impl true
  def handle_cast({:register, from}, ctx) do
    {:noreply, assign(ctx, client: from)}
  end

  @spec register(Kino.JS.Live.t(), pid()) :: :ok
  def register(kino, from) do
    Kino.JS.Live.cast(kino, {:register, from})
  end
end
