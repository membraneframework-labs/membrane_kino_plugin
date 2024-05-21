defmodule Membrane.Kino.Input.Source do
  @moduledoc """
  This module provides a audio microphone (and video camera in the future) input source
  compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Membrane.Kino.Input` element into the Membrane pipeline.

  ## Example
  ``` elixir
  # upper cell
  kino = Membrane.Kino.Input.new(audio: true)

  # lower cell
  import Membrane.ChildrenSpec

  alias Membrane.{
    Kino,
    Opus,
    File
  }
  alias Membrane.H264.FFmpeg.Parser
  alias Membrane.RemoteControlled, as: RC

  output_filepath = "path/to/file.h264"

  structure =
    child(:audio_input, %Kino.Input.Source{kino: kino})
    |> child(:decoder, %Opus.Decoder)
    |> child(:file_output, %File.Sink{location: output_filepath})

  pipeline = RC.Pipeline.start!()
  RC.Pipeline.exec_actions(pipeline, spec: structure)
  RC.Pipeline.exec_actions(pipeline, playback: :playing)
  ```
  """

  alias Membrane.H264
  use Membrane.Bin
  alias Membrane.{
    Kino,
    Opus,
    Matroska,
    Funnel
  }

  def_options kino: [
                spec: Membrane.Kino.Input.t(),
                description: "Membrane.Kino.Player handle."
              ],
              audio: [
                spec: boolean(),
                default: false,
                description: "Enable audio support"
              ],
              video: [
                spec: boolean(),
                default: false,
                description: "Enable video support"
              ]

  def_output_pad :output,
    accepted_format: any_of(Opus, H264),
    availability: :always
    # flow_control: :auto

  @impl true
  def handle_init(_ctx, %{audio: true, video: false} = options) do
    structure = [
      child(:source, %Kino.Input.Source.RemoteStream{kino: options.kino})
      |> child(:demuxer, Matroska.Demuxer),
      child(:funnel, Funnel) |> bin_output()
    ]
    {[spec: structure], %{}}
  end

  @impl true
  def handle_init(_ctx, %{audio: false, video: true} = options) do
    structure = [
      child(:source, %Kino.Input.Source.RemoteStreamVideo{kino: options.kino})
      |> child(:parser, %Membrane.H264.Parser{generate_best_effort_timestamps: %{framerate: {30, 1}}})
      |> bin_output()
    ]
    {[spec: structure], %{}}
  end

  @impl true
  def handle_init(_ctx, %{audio: false, video: false} = _options) do
    raise "one of :video or :audio options must be set to true"
  end

  @impl true
  def handle_init(_ctx, %{audio: true, video: true} = _options) do
    raise "Video&Audio mode not yet developed"
  end

  @impl true
  def handle_child_notification({:new_track, {track_id, track_info}}, :demuxer, _ctx, state) do
    case track_info.codec do
      :opus ->
        structure =
          get_child(:demuxer)
          |> via_out(Pad.ref(:output, track_id))
          |> get_child(:funnel)

        {[spec: structure], state}

      _else ->
        raise "Unsupported codec: #{inspect(track_info.codec)}"
    end
  end
end
