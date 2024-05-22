defmodule Membrane.Kino.Input.AudioSource do
  @moduledoc """
  This module provides a audio input source compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Membrane.Kino.Input` element into the Membrane pipeline.
  """

  use Membrane.Bin

  alias Membrane.{
    Funnel,
    Kino,
    Matroska,
    Opus
  }

  def_options kino: [
                spec: Membrane.Kino.Input.t(),
                description: "Membrane.Kino.Player handle."
              ]

  def_output_pad :output,
    accepted_format: Opus,
    availability: :always

  @impl true
  def handle_init(_ctx, options) do
    structure = [
      child(:source, %Kino.Input.Source.RemoteStreamAudio{kino: options.kino})
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
