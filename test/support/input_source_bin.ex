defmodule Membrane.KinoTest.InputSourceBin do
  @moduledoc false
  use Membrane.Bin

  alias Membrane.{
    File,
    Funnel,
    Matroska,
    Opus
  }

  def_options location: [
                spec: String.t(),
                description: "Input file location"
              ]

  def_output_pad :output,
    accepted_format: Opus,
    availability: :always

  @impl true
  def handle_init(_ctx, options) do
    structure = [
      child(:source, %File.Source{location: options.location})
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
