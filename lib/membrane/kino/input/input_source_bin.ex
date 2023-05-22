defmodule Membrane.Kino.Input.Source do
  @moduledoc """
  This module provides a audio microphone (and video camera in the future) input source
  compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Membrane.Kino.Input` element into the Membrane pipeline.

  Kino player will be automatically created if not given.

  ## Example
  ``` elixir
  # upper cell
  kino = Membrane.Kino.Input.new(video: true)

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

  use Membrane.Bin

  alias Membrane.{
    Kino,
    Opus,
    Matroska,
    Funnel
  }

  def_options kino: [
                spec: Membrane.Kino.Input.t(),
                description:
                  "Membrane.Kino.Player handle. If not given, new input will be created.",
                default: nil
              ]

  def_output_pad :output,
    accepted_format: Opus,
    availability: :always,
    mode: :push

  @impl true
  def handle_init(_ctx, options) do
    structure = [
      child(:source, %Kino.Input.Source.RemoteStream{kino: options.kino})
      |> child(:demuxer, Matroska.Demuxer),
      child(:funnel, Funnel) |> bin_output()
    ]

    {[spec: structure], %{}}
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
