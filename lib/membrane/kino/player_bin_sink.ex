defmodule Membrane.Kino.Player.Bin.Sink do
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

  use Membrane.Bin

  require Membrane.Logger

  alias Kino.JS.Live, as: KinoPlayer
  alias Membrane.{AAC, H264, RemoteStream}

  alias Membrane.Kino

  def_options kino: [
                spec: KinoPlayer.t(),
                description:
                  "Kino element handle. It should be initialized before the pipeline is started."
              ]

  # The measured latency needed to show a frame on a screen.
  def_input_pad :input,
    accepted_format:
      any_of(
        H264,
        AAC,
        %RemoteStream{type: :bytestream, content_format: content_format}
        when content_format in [nil, MP4]
      ),
    demand_unit: :buffers

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    kino = options.kino
    type = KinoPlayer.call(kino, :get_type)

    structure =
      case type do
        :both ->
          demuxer_structure(kino)

        type when type in [:video, :audio] ->
          bin_input() |> child(:player, %Kino.Player.Sink{kino: kino})
      end

    {[spec: structure], %{}}
  end

  defp demuxer_structure(_kino) do
    raise "Membrane.MP4 does not support depayloader yet."
    # [
    #   bin_input() |> child(:demuxer, Demuxer),
    #   get_child(:demuxer)
    #   |> via_out(Pad.ref(:output, 1))
    #   |> child(:h264_parser, Membrane.H264.FFmpeg.Parser)
    #   |> via_in(:video)
    #   |> get_child(:player),
    #   get_child(:demuxer)
    #   |> via_out(Pad.ref(:output, 2))
    #   |> child(:aac_parser, Membrane.AAC.Parser)
    #   |> via_in(:audio)
    #   |> get_child(:player),
    #   child(:player, %Kino.Player.Sink{kino: kino})
    # ]
  end
end
