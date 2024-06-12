defmodule Membrane.Kino.Input.Source do
  @moduledoc """
  This module provides audio and video input source compatible with the Livebook environment.
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
    availability: :on_request,
    flow_control: :push

  @impl true
  def handle_init(_ctx, options) do
    kino_mode = Kino.JS.Live.call(options.kino, {:get_type})

    mode =
      cond do
        kino_mode.audio and kino_mode.video ->
          [:audio, :video]

        kino_mode.audio ->
          [:audio]

        kino_mode.video ->
          [:video]
      end

    {[], %{kino: options.kino, tracks: %{}, mode: mode}}
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
    audio_pad = get_pad(:audio, state)
    video_pad = get_pad(:video, state)

    actions =
      cond do
        audio_pad != nil and video_pad != nil ->
          [
            stream_format: {audio_pad, %RemoteStream{content_format: :WEBM, type: :bytestream}},
            stream_format: {video_pad, %RemoteStream{content_format: :H264, type: :bytestream}}
          ]

        audio_pad != nil ->
          [stream_format: {audio_pad, %RemoteStream{content_format: :WEBM, type: :bytestream}}]

        video_pad != nil ->
          [stream_format: {video_pad, %RemoteStream{content_format: :H264, type: :bytestream}}]

        true ->
          []
      end

    {actions, state}
  end

  @impl true
  def handle_info({:audio_frame, info, binary}, ctx, state) do
    duration = Map.get(info, "duration", 0)

    buffer = %Buffer{
      payload: binary,
      metadata: %{
        duration: Time.milliseconds(duration)
      }
    }

    audio_pad = get_pad(:audio, state)

    actions =
      if audio_pad != nil do
        %{stream_format: stream_format, end_of_stream?: end_of_stream} =
          Map.get(ctx.pads, audio_pad)

        cond do
          stream_format == nil ->
            [
              stream_format: {audio_pad, %RemoteStream{content_format: :WEBM, type: :bytestream}},
              buffer: {audio_pad, buffer}
            ]

          end_of_stream ->
            []

          true ->
            [buffer: {audio_pad, buffer}]
        end
      end

    {actions, state}
  end

  @impl true
  def handle_info({:video_frame, info, binary}, ctx, state) do
    duration = Map.get(info, "duration", 0)

    buffer = %Buffer{
      payload: binary,
      metadata: %{
        duration: Time.milliseconds(duration)
      }
    }

    video_pad = get_pad(:video, state)

    actions =
      if video_pad != nil do
        %{stream_format: stream_format, end_of_stream?: end_of_stream} =
          Map.get(ctx.pads, video_pad)

        cond do
          stream_format == nil ->
            [
              stream_format: {video_pad, %RemoteStream{content_format: :H264, type: :bytestream}},
              buffer: {video_pad, buffer}
            ]

          end_of_stream ->
            []

          true ->
            [buffer: {video_pad, buffer}]
        end
      end

    {actions, state}
  end

  @impl true
  def handle_info({:framerate, framerate}, _ctx, state) do
    {[notify_parent: %{framerate: framerate}], state}
  end

  @impl true
  def handle_info(:end_of_stream, _ctx, state) do
    audio_pad = get_pad(:audio, state)
    video_pad = get_pad(:video, state)

    actions =
      cond do
        audio_pad != nil and video_pad != nil ->
          [{:end_of_stream, audio_pad}, {:end_of_stream, video_pad}]

        audio_pad != nil ->
          [{:end_of_stream, audio_pad}]

        video_pad != nil ->
          [{:end_of_stream, video_pad}]

        true ->
          []
      end

    {actions, state}
  end

  @impl true
  def handle_pad_added({_membrane_pad, name, _ref} = pad, _ctx, state) do
    if get_pad(name, state) != nil do
      raise "Pad #{name} for Kino.Input.Source already exists."
    end

    if not Enum.member?(state.mode, name) do
      raise "Pad #{name} not allowed for Kino.Input.Source."
    end

    {[], %{state | tracks: Map.put(state.tracks, pad, Track)}}
  end

  defp get_pad(target, state) do
    state.tracks
    |> Map.keys()
    |> Enum.filter(fn {_membrane_pad, pad_name, _ref} -> pad_name == target end)
    |> Enum.map(fn pad -> pad end)
    |> List.first()
  end
end
