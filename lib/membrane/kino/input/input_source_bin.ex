defmodule Membrane.Kino.Input.SourceBin do
  @moduledoc """
  This module provides a video input source compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Membrane.Kino.Input` element into the Membrane pipeline.
  """
  use Membrane.Bin

  alias Membrane.{
    Funnel,
    Kino,
    Matroska,
    Opus,
    H264
  }

  def_options kino: [
                spec: Membrane.Kino.Input.t(),
                description: "Membrane.Kino.Player handle."
              ]

  def_output_pad :video,
    accepted_format: H264,
    availability: :always

  def_output_pad :audio,
    accepted_format: Opus,
    availability: :always

  @impl true
  def handle_init(_ctx, options) do
    spec = [
      # video
      child(:remote_stream, %Kino.Input.Source.RemoteStream{kino: options.kino}),
      child(:funnel_video, Funnel) |> bin_output(:video),

      # audio
      get_child(:remote_stream)
      |> via_out(:audio)
      |> child(:demuxer, Matroska.Demuxer),
      child(:funnel_audio, Funnel) |> bin_output(:audio)
    ]

    {[spec: spec], %{framerate: nil, tracks: 2}}
  end

  @impl true
  def handle_child_notification(%{framerate: framerate}, :remote_stream, _ctx, state) do
    spec =
      get_child(:remote_stream)
      |> via_out(Pad.ref(:video))
      |> child(:parser, %H264.Parser{
        generate_best_effort_timestamps: %{framerate: {framerate, 1}}
      })
      |> get_child(:funnel_video)

    {[spec: spec, setup: :complete], state}
    # {[spec: spec], state}
  end

  @impl true
  def handle_child_notification({:new_track, {track_id, track_info}}, :demuxer, _ctx, state) do
    case track_info.codec do
      :opus ->
        structure =
          get_child(:demuxer)
          |> via_out(Pad.ref(:output, track_id))
          |> get_child(:funnel_audio)

        {[spec: structure], state}

      _else ->
        raise "Unsupported codec: #{inspect(track_info.codec)}"
    end
  end

  @impl true
  def handle_setup(_ctx, _state) do
    {[setup: :incomplete], %{}}
  end
end
