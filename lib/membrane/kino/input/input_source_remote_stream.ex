defmodule Membrane.Kino.Input.Source.RemoteStream do
  @moduledoc """
  This module provides a video input source compatible with the Livebook environment.
  This module returns raw video data in H264 format.
  For more practical usage, see `Membrane.Kino.Input.VideoSource`.
  """
  use Membrane.Source

  alias Membrane.Kino.Input, as: KinoInput

  alias Membrane.{
    Buffer,
    RemoteStream,
    Time
  }

  defmodule KinoSourceAlreadyOccupiedError do
    defexception [:message]
  end

  def_options kino: [
                spec: KinoInput.t(),
                description: "Membrane.Kino.Input.t() handle"
              ]

  def_output_pad :video,
    accepted_format: %RemoteStream{content_format: :H264, type: :bytestream},
    availability: :on_request,
    flow_control: :push

  def_output_pad :audio,
    accepted_format: %RemoteStream{content_format: :WEBM, type: :bytestream},
    availability: :always,
    flow_control: :push

  @impl true
  def handle_init(_ctx, options) do
    {[], %{kino: options.kino, tracks: %{}, video_ref: nil}}
  end

  @impl true
  def handle_setup(ctx, state) do
    pid = self()

    case KinoInput.register(state.kino, pid) do
      :ok ->
        :ok

      {:error, :already_registered} ->
        raise KinoSourceAlreadyOccupiedError, message: "Kino source already occupied"
    end

    Membrane.ResourceGuard.register(
      ctx.resource_guard,
      fn -> :ok = KinoInput.unregister(state.kino, pid) end
    )

    {[], state}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[
      stream_format: {state.video_ref, %RemoteStream{content_format: :H264, type: :bytestream}},
      stream_format: {:audio, %RemoteStream{content_format: :WEBM, type: :bytestream}}
    ],
     state}
  end

  @impl true
  def handle_info({:audio_frame, info, binary}, _ctx, state) do
    # IO.inspect("remote stream audio frame")
    duration = Map.get(info, "duration", 0)

    buffer = %Buffer{
      payload: binary,
      metadata: %{
        duration: Time.milliseconds(duration)
      }
    }

    if state.video_ref == nil do
      {[], state}
    else
      {[buffer: {:audio, buffer}], state}
    end
  end

  @impl true
  def handle_info({:video_frame, info, binary}, _ctx, state) do
    duration = Map.get(info, "duration", 0)

    buffer = %Buffer{
      payload: binary,
      metadata: %{
        duration: Time.milliseconds(duration)
      }
    }

    {[buffer: {state.video_ref, buffer}], state}
  end

  @impl true
  def handle_info({:framerate, framerate}, _ctx, state) do
    {[notify_parent: %{framerate: framerate}], state}
  end

  @impl true
  def handle_info(:end_of_stream, _ctx, state) do
    {[{:end_of_stream, :output}], state}
  end

  @impl true
  def handle_pad_added(pad, _ctx, state) do
    {[], %{state | video_ref: pad, tracks: Map.put(state.tracks, pad, Track)}}
  end
end
