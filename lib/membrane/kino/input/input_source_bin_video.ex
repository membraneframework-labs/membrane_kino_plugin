defmodule Membrane.Kino.Input.VideoSource do
  @moduledoc """
  This module provides a video input source compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Membrane.Kino.Input` element into the Membrane pipeline.
  """
  use Membrane.Bin

  alias Membrane.H264
  alias Membrane.Kino

  def_options kino: [
                spec: Membrane.Kino.Input.t(),
                description: "Membrane.Kino.Player handle."
              ],
              framerate: [
                spec: H264.framerate(),
                default: %{framerate: {30, 1}},
                description:
                  "This should be set to the same value as framerate provided to Membrane.Kino.Input to ensure correct timestamps"
              ],
              resolution: [
                spec: %{width: non_neg_integer(), height: non_neg_integer()},
                default: %{width: 1920, height: 1080},
                description:
                  "Desired output resolution. If it cannot be acheived natively the video will be scaled."
              ]

  def_output_pad :output,
    accepted_format: H264,
    availability: :always

  @impl true
  def handle_init(_ctx, options) do
    IO.inspect(options)
    structure = [
      child(:source, %Kino.Input.Source.RemoteStreamVideo{kino: options.kino})
      |> child(:parser, %H264.Parser{generate_best_effort_timestamps: options.framerate})
      # |> child(:parser, %H264.Parser{generate_best_effort_timestamps: false})
      # |> child(%Membrane.Debug.Filter{handle_buffer: &IO.inspect/1})
      |> child(:decoder, Membrane.H264.FFmpeg.Decoder)
      |> child(:scaler, %Membrane.FFmpeg.SWScale.Scaler{output_width: options.resolution.width, output_height: options.resolution.height})
      |> child(:encoder, %Membrane.H264.FFmpeg.Encoder{profile: :baseline})
      |> bin_output()
    ]

    {[spec: structure], %{}}
  end
end
