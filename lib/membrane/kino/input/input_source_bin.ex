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

    {[spec: spec], %{framerate: nil, tracks: 2}}
  end

  @impl true
  def handle_child_notification(%{framerate: framerate}, :remote_stream, _ctx, state) do
    state = Map.put(state, :framerate, framerate)
    {[], state}
  end

  def handle_child_notification({:new_track, {track_id, track_info}}, :demuxer, _context, state) do
    IO.inspect(track_info.codec, label: "new_track")
    cond do
      track_info.codec == :opus ->
        structure =
          get_child(:demuxer)
          |> via_out(Pad.ref(:output, track_id))
          |> get_child(:audio_funnel)

        {[spec: structure], state}

      track_info.codec == :h264 ->
        structure =
          get_child(:demuxer)
          |> via_out(Pad.ref(:output, track_id))
          |> child(%Membrane.Debug.Filter{handle_buffer: &IO.inspect/1})
          |> child(:parser, %H264.Parser{
            generate_best_effort_timestamps: %{framerate: {30, 1}},
            output_stream_structure: :avc3
          })
          |> get_child(:video_funnel)

        {[spec: structure], state}

      true ->
        raise "Unsupported codec #{track_info.codec}"
    end
  end

  # @impl true
  # def handle_setup(_ctx, _state) do
  #   {[setup: :incomplete], %{}}
  # end
end
