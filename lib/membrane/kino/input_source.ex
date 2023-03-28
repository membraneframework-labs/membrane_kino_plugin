defmodule Membrane.Kino.InputSource do
  use Membrane.Source

  alias Membrane.{
    RemoteStream,
    Kino,
    Opus,
    Time,
    Buffer
  }

  def_options kino: [
                spec: Kino.JS.Live.t(),
                description: "Kino.JS.Live handle"
              ]

  def_output_pad :output,
    accepted_format: %RemoteStream{content_format: Opus},
    availability: :always,
    mode: :push

  @impl true
  def handle_playing(_ctx, state) do
    {[stream_format: {:output, %RemoteStream{content_format: Opus}}], state}
  end

  @impl true
  def handle_info({:audio_frame, info, binary}, _ctx, state) do
    buffer = %Buffer{
      payload: binary,
      metadata: %{
        duration: Time.milliseconds(info.duration)
      }
    }

    {[buffer: {:output, buffer}], state}
  end
end
