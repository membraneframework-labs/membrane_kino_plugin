defmodule Membrane.Kino.Video.Sink do
  @moduledoc """
  This module provides a video player sink compatible with the Livebook.
  """

  use Membrane.Sink

  require Membrane.Logger

  alias Membrane.{Buffer, Time}
  alias Membrane.RawVideo
  alias Kino.JS.Live, as: KinoPlayer

  def_options kino_player: [
                spec: KinoPlayer.t(),
                description: "Kino element handle. It should be initialized before the pipeline."
              ]

  # The measured latency needed to show a frame on a screen.
  @latency 20 |> Time.milliseconds()

  def_input_pad :input, accepted_format: RawVideo, demand_unit: :buffers

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    IO.inspect("Kino.Sink handle_init")

    state = %{kino_player: options.kino_player, timer_started?: false}
    {[latency: @latency], state}
  end

  @impl true
  def handle_stream_format(:input, stream_format, ctx, state) do
    IO.inspect("Kino.Sink handle_stream_format/4")

    %{input: input} = ctx.pads
    %{kino_player: kino_player} = state

    if !input.stream_format || stream_format == input.stream_format do
      IO.inspect("Kino.Sink handle_stream_format/4 bin")
      :ok = KinoPlayer.call(kino_player, {:create, {stream_format.width, stream_format.height}})
      {[], state}
    else
      raise "Stream format have changed while playing. This is not supported."
    end
  end

  @impl true
  def handle_start_of_stream(:input, ctx, state) do
    IO.inspect("Kino.Sink handle_start_of_stream")

    use Ratio
    {nom, denom} = ctx.pads.input.stream_format.framerate
    timer = {:demand_timer, Time.seconds(denom) <|> nom}

    {[demand: :input, start_timer: timer], %{state | timer_started?: true}}
  end

  @impl true
  def handle_write(:input, %Buffer{payload: payload}, _ctx, state) do
    IO.inspect("Kino.Sink handle_write input")

    payload = Membrane.Payload.to_binary(payload)
    :ok = KinoPlayer.call(state.kino_player, {:buffor, payload})
    {[], state}
  end

  @impl true
  def handle_tick(:demand_timer, _ctx, state) do
    IO.inspect("Kino.Sink handle_tick")

    {[demand: :input], state}
  end
end
