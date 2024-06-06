defmodule Membrane.Kino.Input.VideoSource do
  @moduledoc """
  This module provides a video input source compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Membrane.Kino.Input` element into the Membrane pipeline.
  """
  use Membrane.Bin

  alias Membrane.Funnel
  alias Membrane.H264
  alias Membrane.Kino

  def_options kino: [
                spec: Membrane.Kino.Input.t(),
                description: "Membrane.Kino.Player handle."
              ]

  def_output_pad :output,
    accepted_format: H264,
    availability: :always

  @impl true
  def handle_init(_ctx, options) do
    spec = [
      child(:remote_stream_video, %Kino.Input.Source.RemoteStreamVideo{kino: options.kino}),
      child(:funnel_out, Funnel)
      |> bin_output()
    ]

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification(%{framerate: framerate}, :remote_stream_video, _ctx, state) do
    spec =
      get_child(:remote_stream_video)
      |> via_out(Pad.ref(:output))
      |> child(:parser, %H264.Parser{
        generate_best_effort_timestamps: %{framerate: {framerate, 1}}
      })
      |> get_child(:funnel_out)

    {[spec: spec, setup: :complete], state}
  end

  @impl true
  def handle_setup(_ctx, _state) do
    {[setup: :incomplete], %{}}
  end
end
