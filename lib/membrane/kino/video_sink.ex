defmodule Membrane.Kino.Video.Sink do
  @moduledoc """
  This module provides a video player sink compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Kino.Video.Binary` element into the Membrane pipeline and shows video in livebook's cells.

  ## Example
  ``` elixir
  # upper cell
  kino = Kino.Video.Binary.new()

  # lower cell
  # TODO add example in the next PR
  ```

  """

  use Membrane.Sink

  require Membrane.Logger

  alias Membrane.{Buffer, Time}
  alias Membrane.{RawVideo, H264}
  alias Kino.JS.Live, as: KinoPlayer

  def_options kino: [
                spec: KinoPlayer.t(),
                description:
                  "Kino element handle. It should be initialized before the pipeline is started."
              ]

  # The measured latency needed to show a frame on a screen.
  @latency 20 |> Time.milliseconds()

  def_input_pad :input,
    # accepted_format: %RawVideo{pixel_format: :RGBA} | H264,
    accepted_format: _any,
    demand_unit: :buffers

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    IO.inspect("Kino.Sink handle_init")

    state = %{kino: options.kino, timer_started?: false, index: 0}
    {[latency: @latency], state}
  end

  @impl true
  def handle_stream_format(:input, stream_format, ctx, state) do
    IO.inspect("Kino.Sink handle_stream_format/4")

    %{input: input} = ctx.pads
    %{kino: kino} = state

    if !input.stream_format or stream_format == input.stream_format do
      IO.inspect("Kino.Sink handle_stream_format/4 bin")
      KinoPlayer.cast(kino, {:create, {0, 0}})
      {[], state}
    else
      raise "Stream format has changed while playing. This is not supported."
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
    IO.inspect(state.index, label: "index")

    payload = Membrane.Payload.to_binary(payload)
    KinoPlayer.cast(state.kino, {:buffer, payload})
    {[], %{state | index: state.index + 1}}
  end

  @impl true
  def handle_tick(:demand_timer, _ctx, state) do
    IO.inspect("Kino.Sink handle_tick")

    {[demand: :input], state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    IO.inspect("Kino.Sink handle_end_of_stream")

    if state.timer_started? do
      {[stop_timer: :demand_timer], %{state | timer_started?: false, index: 0}}
    else
      {[], state}
    end
  end
end
