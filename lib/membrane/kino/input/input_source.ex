defmodule Membrane.Kino.Input.Source do
  @moduledoc """
  This module provides audio and video input source compatible with the Livebook environment.
  Currently video capture works only in Chrome, audio capture in Chrome and Firefox.

  This module returns raw video data in H264 format and/or audio data in WEBM format (opus codec).
  For more practical usage, see `Membrane.Kino.Input.Bin.Source`.
  """
  use Membrane.Source

  alias Membrane.Kino.Input, as: KinoInput

  alias Membrane.{
    Buffer,
    RemoteStream,
    Time
  }

  @audio_stream_format %RemoteStream{content_format: :WEBM, type: :bytestream}
  @video_stream_format %RemoteStream{content_format: :H264, type: :bytestream}

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
    availability: :on_request,
    flow_control: :push

  @impl true
  def handle_init(_ctx, options) do
    {[], %{kino: options.kino, mode: []}}
  end

  @impl true
  def handle_setup(ctx, state) do
    pid = self()

    case KinoInput.register(state.kino, pid) do
      :ok ->
        :ok

      {:error, :already_registered} ->
        raise RuntimeError, message: "Cannot register KinoInput because it is already occupied"
    end

    Membrane.ResourceGuard.register(
      ctx.resource_guard,
      fn -> :ok = KinoInput.unregister(state.kino, pid) end
    )

    kino_mode = Kino.JS.Live.call(state.kino, :get_type)

    mode =
      cond do
        kino_mode.audio and kino_mode.video ->
          [:audio, :video]

        kino_mode.audio ->
          [:audio]

        kino_mode.video ->
          [:video]
      end

    {[], %{state | mode: mode}}
  end

  @impl true
  def handle_playing(ctx, state) do
    audio_pad = get_pad(:audio, ctx)
    video_pad = get_pad(:video, ctx)

    actions =
      [
        stream_format: {audio_pad, @audio_stream_format},
        stream_format: {video_pad, @video_stream_format}
      ]
      |> Enum.reject(fn {:stream_format, {pad, _stream_format}} -> pad == nil end)

    {actions, state}
  end

  @impl true
  def handle_info({:audio_frame, info, binary}, ctx, state) do
    audio_pad = get_pad(:audio, ctx)
    handle_frame(audio_pad, info, binary, @audio_stream_format, ctx, state)
  end

  @impl true
  def handle_info({:video_frame, info, binary}, ctx, state) do
    video_pad = get_pad(:video, ctx)
    handle_frame(video_pad, info, binary, @video_stream_format, ctx, state)
  end

  @impl true
  def handle_info({:framerate, framerate}, _ctx, state) do
    {[notify_parent: {:framerate, framerate}], state}
  end

  @impl true
  def handle_info(:end_of_stream, ctx, state) do
    audio_pad = get_pad(:audio, ctx)
    video_pad = get_pad(:video, ctx)

    actions =
      [end_of_stream: audio_pad, end_of_stream: video_pad]
      |> Enum.reject(fn {:end_of_stream, pad} -> pad == nil end)

    {actions, state}
  end

  @impl true
  def handle_pad_added(Pad.ref(name, _ref), ctx, state) do
    assert_pad_count!(name, ctx)

    if not Enum.member?(state.mode, name) do
      raise "Pad #{name} not allowed for #{__MODULE__}."
    end

    {[], state}
  end

  defp get_pad(target, ctx) do
    ctx.pads
    |> Map.keys()
    |> Enum.find(fn pad_ref -> Pad.name_by_ref(pad_ref) == target end)
  end

  defp assert_pad_count!(name, ctx) do
    count =
      ctx.pads
      |> Map.keys()
      |> Enum.count(fn pad_ref -> Pad.name_by_ref(pad_ref) == name end)

    if count > 1 do
      raise "Pad #{name} for #{__MODULE__} already exists."
    end

    :ok
  end

  defp handle_frame(pad, info, binary, target_stream_format, ctx, state) do
    duration = Map.get(info, "duration", 0)

    buffer = %Buffer{
      payload: binary,
      metadata: %{
        duration: Time.milliseconds(duration)
      }
    }

    actions =
      if pad != nil do
        %{stream_format: stream_format, end_of_stream?: end_of_stream?} =
          Map.get(ctx.pads, pad)

        cond do
          stream_format == nil ->
            [
              stream_format: {pad, target_stream_format},
              buffer: {pad, buffer}
            ]

          end_of_stream? ->
            []

          true ->
            [buffer: {pad, buffer}]
        end
      else
        []
      end

    {actions, state}
  end
end
