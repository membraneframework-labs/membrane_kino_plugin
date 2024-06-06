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
      child(:remote_stream, %Kino.Input.Source.RemoteStream{kino: options.kino})
      |> child(:demuxer, Matroska.Demuxer),

      child(:video_funnel, Funnel) |> bin_output(:video),
      child(:audio_funnel, Funnel) |> bin_output(:audio)
    ]

    {[spec: spec], %{framerate: nil}}
  end

  @impl true
  def handle_child_notification(%{framerate: framerate}, :remote_stream, _ctx, state) do
    {[], %{state | framerate: framerate}}
  end

  def handle_child_notification({:new_track, {track_id, track_info}}, :demuxer, _context, state) do
    cond do
      track_info.codec == :opus ->
        structure =
          get_child(:demuxer)
          |> via_out(Pad.ref(:output, track_id))
          |> child(:audio_funnel)

        {[spec: structure], state}

      track_info.codec == :h264 ->
        structure =
          get_child(:demuxer)
          |> via_out(Pad.ref(:output, track_id))
          |> child(:parser, %H264.Parser{
            generate_best_effort_timestamps: %{framerate: {state.framerate, 1}}
          })
          |> child(:video_funnel, Funnel)

        {[spec: structure], state}

      true ->
        raise "Unsupported codec #{track_info.codec}"
    end
  end

  @impl true
  def handle_setup(_ctx, _state) do
    {[setup: :incomplete], %{}}
  end
end
