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
                description: "This must be set to the same value as framerate provided to Membrane.Kino.Input to ensure correct timestamps"
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
  def handle_child_notification({:new_track, {_track_id, _track_info}}, :demuxer, _ctx, _state) do
    raise "video bin handle_child_notification not implemented"
  end
end
