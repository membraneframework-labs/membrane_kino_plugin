defmodule Membrane.Kino.Player.Sink do
  @moduledoc """
  This module provides a video and audio player sink compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Membrane.Kino.Player` element into the Membrane pipeline and shows video in livebook's cells.

  ## Example
  ``` elixir
  # upper cell
  kino = Membrane.Kino.Player.new(:video)

  # lower cell
  import Membrane.ChildrenSpec

  alias Membrane.{
    File,
    RawVideo,
    Kino
  }
  alias Membrane.H264.FFmpeg.Parser
  alias Membrane.RemoteControlled, as: RC

  input_filepath = "path/to/file.h264"

  structure =
    child(:file_input, %File.Source{location: input_filepath})
    |> child(:parser, %Parser{framerate: {60, 1}})
    |> child(:video_player, %Kino.Player.Sink{kino: kino})

  pipeline = RC.Pipeline.start!()
  RC.Pipeline.exec_actions(pipeline, spec: structure)
  RC.Pipeline.exec_actions(pipeline, playback: :playing)
  ```

  """

  use Membrane.Sink

  require Membrane.Logger

  alias Kino.JS.Live, as: KinoPlayer
  alias Membrane.{AAC, Buffer, H264, Time}

  def_options kino: [
                spec: KinoPlayer.t(),
                description:
                  "Kino element handle. It should be initialized before the pipeline is started."
              ]

  # The measured latency needed to show a frame on a screen.
  @latency 20 |> Time.milliseconds()

  def_input_pad :input,
    accepted_format: any_of(H264, AAC),
    demand_unit: :buffers

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    state = %{kino: options.kino, timer_started?: false, index: 0, framerate: nil}
    {[latency: @latency], state}
  end

  @impl true
  def handle_stream_format(:input, stream_format, ctx, state) do
    %{input: input} = ctx.pads
    %{kino: kino} = state

    if !input.stream_format or stream_format == input.stream_format do
      {num, den} = get_framerate(stream_format)
      framerate_float = num / den
      KinoPlayer.cast(kino, {:create, framerate_float})
      {[], %{state | framerate: {num, den}}}
    else
      raise "Stream format has changed while playing. This is not supported."
    end
  end

  defp get_framerate(stream_format = %H264{}) do
    stream_format.framerate
  end

  defp get_framerate(stream_format = %AAC{}) do
    num = stream_format.sample_rate
    den = stream_format.samples_per_frame
    {num, den}
  end

  @impl true
  def handle_start_of_stream(:input, _ctx, state) do
    {nom, denom} = state.framerate

    timer = {:demand_timer, Ratio.new(Time.seconds(denom), nom)}

    {[demand: :input, start_timer: timer], %{state | timer_started?: true}}
  end

  @impl true
  def handle_write(:input, %Buffer{payload: payload}, _ctx, state) do
    payload = Membrane.Payload.to_binary(payload)
    KinoPlayer.cast(state.kino, {:buffer, payload, %{index: state.index}})
    {[], %{state | index: state.index + 1}}
  end

  @impl true
  def handle_tick(:demand_timer, _ctx, state) do
    {[demand: :input], state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    if state.timer_started? do
      {[stop_timer: :demand_timer], %{state | timer_started?: false, index: 0}}
    else
      {[], state}
    end
  end
end
