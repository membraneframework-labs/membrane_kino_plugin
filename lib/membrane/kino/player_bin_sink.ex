defmodule Membrane.Kino.Player.Bin.Sink do
  @moduledoc """
  This module provides an universal video and audio player sink compatible with the Livebook environment.

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
    |> child(:video_player, %Kino.Player.Bin.Sink{kino: kino})

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

  def_input_pad :input,
    accepted_format:
      any_of(
        H264,
        AAC,
        %RemoteStream{type: :bytestream, content_format: content_format}
        when content_format in [nil, MP4]
      )

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    kino = options.kino
    type = KinoPlayer.call(kino, :get_type)

    structure =
      case type do
        :both ->
          demuxer_structure(kino)

        type when type in [:video, :audio] ->
          bin_input() |> via_in(type) |> child(:player, %Kino.Player.Sink{kino: kino})
      end

    {[spec: structure], %{}}
  end

  defp demuxer_structure(_kino) do
    raise "Player bin sink cannot handle MP4 yet. Membrane.MP4 does not support depayloader yet."
  end
end
