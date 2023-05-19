defmodule Membrane.Kino.InputSourceBin do
  use Membrane.Bin

  alias Membrane.{
    Kino,
    Opus,
    Matroska,
    Funnel
  }

  def_options kino: [
                spec: Membrane.Kino.Player.t(),
                description: "Membrane.Kino.Player handle"
              ]

  def_output_pad :output,
    accepted_format: Opus,
    availability: :always,
    mode: :push

  @impl true
  def handle_init(_ctx, options) do
    structure = [
      child(:source, %Kino.InputSource{kino: options.kino})
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
