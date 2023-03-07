defmodule Membrane.Kino.Player.Sink do
  @moduledoc """
  This module provides a video and audio player sink compatible with the Livebook environment.

  Livebook handles multimedia and specific media by using the Kino library and its extensions.
  This module integrate special `Membrane.Kino.Player` element into the Membrane pipeline and shows video in livebook's cells.

  ## Example
  ``` elixir
  # upper cell
  kino = Membrane.Kino.Player.new(:video)

  # lower cell
  import Membrane.ChildrenSpec

  alias Membrane.{
    File,
    RawVideo,
    Kino
  }
  alias Membrane.H264.FFmpeg.Parser
  alias Membrane.RemoteControlled, as: RC

  input_filepath = "path/to/file.h264"

  structure =
    child(:file_input, %File.Source{location: input_filepath})
    |> child(:parser, %Parser{framerate: {60, 1}})
    |> via_in(:video)
    |> child(:video_player, %Kino.Player.Sink{kino: kino})

  pipeline = RC.Pipeline.start!()
  RC.Pipeline.exec_actions(pipeline, spec: structure)
  RC.Pipeline.exec_actions(pipeline, playback: :playing)
  ```
  """

  defmodule Track do
    @moduledoc false

    defstruct pad: nil, framerate: nil, eos: false, stream_type: nil, mp4: %{}

    def new() do
      %__MODULE__{}
    end

    def stop(%__MODULE__{} = track) do
      %__MODULE__{track | eos: true}
    end

    def stopped?(%__MODULE__{eos: eos}) do
      eos
    end

    def ready?(track = %__MODULE__{framerate: framerate, pad: pad}) do
      framerate != nil and pad != nil and not stopped?(track)
    end
  end

  use Membrane.Sink

  require Membrane.Logger

  alias Kino.JS.Live, as: KinoPlayer
  alias Membrane.{AAC, Buffer, H264, Time}
  alias Membrane.MP4

  def_options kino: [
                spec: KinoPlayer.t(),
                description:
                  "Kino element handle. It should be initialized before the pipeline is started."
              ]

  def_input_pad :audio,
    accepted_format:
      any_of(
        AAC,
        %MP4.Payload{content: %MP4.Payload.AAC{}}
      ),
    demand_unit: :buffers,
    availability: :on_request

  def_input_pad :video,
    accepted_format:
      any_of(
        H264,
        %MP4.Payload{content: %MP4.Payload.AVC1{}}
      ),
    demand_unit: :buffers,
    availability: :on_request

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    kino = options.kino
    type = KinoPlayer.call(kino, :get_type)

    tracks =
      case type do
        :video -> %{video: Track.new()}
        :audio -> %{audio: Track.new()}
        :both -> %{video: Track.new(), audio: Track.new()}
      end

    state = %{
      kino: kino,
      timer_started?: false,
      index: 0,
      type: type,
      tracks: tracks
    }

    {[], state}
  end

  @impl true
  def handle_stream_format({_mod, pad, _ref} = pad_ref, stream_format, _ctx, state) do
    if Track.ready?(state.tracks[pad]) do
      raise "Stream format changed for pad #{inspect(pad)} but it was already ready."
    end

    framerate = get_framerate(stream_format)
    stream_type = get_stream_type(stream_format)

    codec =
      case stream_format do
        %MP4.Payload{content: %MP4.Payload.AVC1{avcc: avcc}} ->
          avcc
          |> Membrane.Kino.H264.Parser.DecoderConfiguration.parse()
          |> then(fn {:ok, res} -> res end)
          |> Membrane.Kino.H264.Parser.DecoderConfiguration.to_avc1()

        _else ->
          nil
      end

    tracks =
      Map.update!(state.tracks, pad, fn track ->
        %Track{
          track
          | stream_type: stream_type,
            pad: pad_ref,
            framerate: framerate,
            mp4: %{codec: codec}
        }
      end)

    {[], %{state | tracks: tracks}}
  end

  defp get_framerate(stream_format = %H264{}) do
    stream_format.framerate
  end

  defp get_framerate(stream_format = %AAC{}) do
    num = stream_format.sample_rate
    den = stream_format.samples_per_frame
    {num, den}
  end

  defp get_framerate(stream_format = %MP4.Payload{content: content}) do
    case content do
      %MP4.Payload.AVC1{} -> {stream_format.timescale, 256}
      %MP4.Payload.AAC{} -> {stream_format.timescale, 1024}
    end
  end

  defp get_stream_type(%MP4.Payload{}) do
    :mp4
  end

  defp get_stream_type(_stream_format) do
    :raw
  end

  @impl true
  def handle_start_of_stream(_pad, _ctx, state = %{timer_started?: true}) do
    {[], state}
  end

  @impl true
  def handle_start_of_stream(_pad, _ctx, state) do
    {actions, state} =
      if all_tracks_ready?(state.tracks) do
        IO.inspect(state.tracks, label: "tracks")
        create_player(state.tracks, state.kino)
        {start_actions(state.tracks), %{state | timer_started?: true}}
      else
        {[], state}
      end

    {actions, state}
  end

  defp all_tracks_ready?(tracks) do
    Enum.all?(tracks, fn {_pad, track} -> Track.ready?(track) end)
  end

  defp create_player(tracks, kino) do
    main_track = Map.get(tracks, :video) || Map.get(tracks, :audio)
    {num, den} = main_track.framerate

    info = %{
      framerate: num / den
    }

    info = if main_track.stream_type == :mp4, do: Map.put(info, :mp4, main_track.mp4), else: info

    KinoPlayer.cast(kino, {:create, info})
  end

  defp start_actions(tracks) do
    Enum.flat_map(tracks, fn {_pad, track} ->
      {nom, denom} = track.framerate

      [
        start_timer: {{:demand_timer, track.pad}, Ratio.new(Time.seconds(denom), nom)},
        demand: track.pad
      ]
    end)
  end

  @impl true
  def handle_write({_mod, pad, _ref}, %Buffer{payload: payload, dts: dts}, _ctx, state) do
    track = state.tracks[pad]
    stream_type = track.stream_type
    payload = Membrane.Payload.to_binary(payload)
    info = %{index: state.index, type: pad, stream: stream_type, dts: dts, mp4: track.mp4}
    data = {:buffer, payload, info}

    IO.inspect(data, label: "data")

    KinoPlayer.cast(state.kino, data)

    {[], %{state | index: state.index + 1}}
  end

  @impl true
  def handle_tick({:demand_timer, pad_ref}, _ctx, state) do
    {[demand: pad_ref], state}
  end

  @impl true
  def handle_end_of_stream({_mod, pad, _ref} = pad_ref, _ctx, state) do
    tracks = Map.update!(state.tracks, pad, &Track.stop/1)

    state =
      if all_tracks_stopped?(tracks) do
        %{state | timer_started?: false, index: 0}
      else
        state
      end

    {[stop_timer: {:demand_timer, pad_ref}], %{state | tracks: tracks}}
  end

  defp all_tracks_stopped?(tracks) do
    Enum.all?(tracks, fn {_pad, track} -> Track.stopped?(track) end)
  end
end
