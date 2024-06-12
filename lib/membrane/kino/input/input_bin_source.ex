defmodule Membrane.Kino.Input.Bin.Source do
  @moduledoc """
  This module provides audio and/or video input source compatible with the Livebook environment.

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
    availability: :on_request

  def_output_pad :audio,
    accepted_format: Opus,
    availability: :on_request

  @impl true
  def handle_init(_ctx, options) do
    spec =
      child(:remote_stream, %Kino.Input.Source{kino: options.kino})

    {[spec: spec], %{framerate: nil, tracks: %{}}}
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

    {[spec: spec], %{state | framerate: framerate}}
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
        raise "Unsupported audio codec: #{inspect(track_info.codec)}"
    end
  end

  @impl true
  def handle_pad_added({_membrane_pad, name, _ref} = pad, _ctx, state) do
    spec =
      case name do
        :audio ->
          [
            get_child(:remote_stream)
            |> via_out(:audio)
            |> child(:demuxer, Matroska.Demuxer),
            child(:funnel_audio, Funnel) |> bin_output(pad)
          ]

        :video ->
          child(:funnel_video, Funnel)
          |> bin_output(pad)

        true ->
          raise "adding unknown pad"
      end

    {[spec: spec], %{state | tracks: Map.put(state.tracks, pad, Track)}}
  end
end
