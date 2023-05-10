defmodule Membrane.Kino.Input do
  defmodule InputError do
    defexception [:message]
  end

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
  def handle_event("error", error, _ctx) do
    raise InputError, message: error
  end

  @impl true
  def handle_call({:register, from}, _sender, ctx) do
    if ctx.assigns.client do
      {:reply, {:error, :already_registered}, ctx}
    else
      {:reply, :ok, assign(ctx, client: from)}
    end
  end

  @impl true
  def handle_call({:unregister, from}, _sender, ctx) do
    if ctx.assigns.client == from do
      {:reply, :ok, assign(ctx, client: nil)}
    else
      if ctx.assign.client == nil do
        {:reply, :ok, ctx}
      else
        {:reply, {:error, :not_registered}, ctx}
      end
    end
  end
end
