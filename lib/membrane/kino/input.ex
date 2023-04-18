defmodule Membrane.Kino.Input do
  use Kino.JS, assets_path: "lib/assets/audio_input"
  use Kino.JS.Live

  alias Membrane.Time

  def new(_type \\ :audio, opts \\ []) do
    opts = Keyword.validate!(opts, flush_time: Time.milliseconds(1))

    info = Map.new(opts) |> Map.update!(:flush_time, &Time.round_to_milliseconds/1)
    Kino.JS.Live.new(__MODULE__, info)
  end

  @impl true
  def init(info, ctx) do
    {:ok, assign(ctx, info: info)}
  end

  @impl true
  def handle_connect(ctx) do
    info = ctx.assigns.info

    ctx = assign(ctx, client: nil)

    {:ok, info, ctx}
  end

  @impl true
  def handle_event("audio_frame", {:binary, info, binary}, ctx) do
    if ctx.assigns.client do
      send(ctx.assigns.client, {:audio_frame, info, binary})
    end

    {:noreply, ctx}
  end

  @impl true
  def handle_event("recording_started", _info, ctx) do
    {:noreply, ctx}
  end

  @impl true
  def handle_event("recording_stopped", _info, ctx) do
    if ctx.assigns.client do
      send(ctx.assigns.client, :end_of_stream)
    end

    {:noreply, ctx}
  end

  @impl true
  def handle_call(:register, {from, _alias}, ctx) do
    {:reply, :ok, assign(ctx, client: from)}
  end

  @spec register(Kino.JS.Live.t(), pid()) :: :ok
  def register(kino, from) do
    Kino.JS.Live.cast(kino, {:register, from})
  end
end
