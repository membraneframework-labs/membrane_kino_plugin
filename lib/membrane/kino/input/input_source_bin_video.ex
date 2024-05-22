defmodule Membrane.Kino.Input.VideoSource do
  @moduledoc """
  todo
  """

  alias Membrane.H264
  use Membrane.Bin
  alias Membrane.Kino

  def_options kino: [
                spec: Membrane.Kino.Input.t(),
                description: "Membrane.Kino.Player handle."
              ],
              framerate: [
                spec: H264.framerate(),
                default: %{framerate: {30, 1}},
                description: "Target framerate that video will be parsed to"
              ]

  def_output_pad :output,
    accepted_format: H264,
    availability: :always

  @impl true
  def handle_init(_ctx,  options) do
    structure = [
      child(:source, %Kino.Input.Source.RemoteStreamVideo{kino: options.kino})
      |> child(:parser, %Membrane.H264.Parser{generate_best_effort_timestamps: options.framerate})
      |> bin_output()
    ]
    {[spec: structure], %{}}
  end

  # todo
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
