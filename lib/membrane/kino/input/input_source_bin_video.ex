defmodule Membrane.Kino.Input.VideoSource do
  @moduledoc """
  This module provides a video input source compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Membrane.Kino.Input` element into the Membrane pipeline.
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
                description: "This should be set to the same value as framerate provided to Membrane.Kino.Input to ensure correct timestamps"
              ]

  def_output_pad :output,
    accepted_format: H264,
    availability: :always

  @impl true
  def handle_init(_ctx,  options) do
    structure = [
      child(:source, %Kino.Input.Source.RemoteStreamVideo{kino: options.kino})
      |> child(:parser, %H264.Parser{generate_best_effort_timestamps: options.framerate})
      |> bin_output()
    ]
    {[spec: structure], %{}}
  end
end
