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
    |> child(:video_player, %Kino.Player.Sink{kino: kino})

  pipeline = RC.Pipeline.start!()
  RC.Pipeline.exec_actions(pipeline, spec: structure)
  RC.Pipeline.exec_actions(pipeline, playback: :playing)
  ```
  """

  defmodule Track do
    @moduledoc false

    defstruct pad: nil, buffered: Qex.new()

    def new() do
      %__MODULE__{}
    end

    def set_pad(%__MODULE__{} = track, pad) do
      %__MODULE__{track | pad: pad}
    end

    def ready?(%__MODULE__{buffered: buffered}) do
      not Enum.empty?(buffered)
    end

    def push(%__MODULE__{buffered: buffered} = track, buffer) do
      %__MODULE__{track | buffered: Qex.push(buffered, buffer)}
    end

    def pop!(%__MODULE__{buffered: buffered} = track) do
      {buffer, buffered} = Qex.pop!(buffered)
      {buffer, %__MODULE__{track | buffered: buffered}}
    end
  end

  use Membrane.Sink

  require Membrane.Logger

  alias Kino.JS.Live, as: KinoPlayer
  alias Membrane.{AAC, Buffer, H264, Time}

  def_options kino: [
                spec: KinoPlayer.t(),
                description:
                  "Kino element handle. It should be initialized before the pipeline is started."
              ]

  def_input_pad :audio,
    accepted_format: AAC,
    demand_unit: :buffers,
    availability: :on_request

  def_input_pad :video,
    accepted_format: H264,
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
      framerate: nil,
      type: type,
      tracks: tracks
    }

    {[], state}
  end

  @impl true
  def handle_stream_format(
        {_mod, pad, _ref} = pad_ref,
        stream_format,
        _ctx,
        %{type: type} = state
      )
      when pad in [:video, :audio] and type == pad do
    %{kino: kino} = state
    {num, den} = get_framerate(stream_format)
    framerate_float = num / den
    KinoPlayer.cast(kino, {:create, framerate_float})
    tracks = %{state.tracks | pad => Track.set_pad(state.tracks[pad], pad_ref)}

    {[], %{state | framerate: {num, den}, tracks: tracks}}
  end

  @impl true
  def handle_stream_format(_pad, stream_format, ctx, %{type: :both, framerate: nil} = state) do
    %{input: input} = ctx.pads
    %{kino: kino} = state

    if !input.stream_format or stream_format == input.stream_format do
      {num, den} = get_framerate(stream_format)
      framerate_float = num / den
      KinoPlayer.cast(kino, {:create, framerate_float})
      {[], %{state | framerate: {num, den}}}
    else
      raise "Stream format has changed while playing. This is not supported."
    end
  end

  @impl true
  def handle_stream_format(_pad, _stream_format, _ctx, %{type: :both} = state) do
    {[], state}
  end

  defp get_framerate(stream_format = %H264{}) do
    stream_format.framerate
  end

  defp get_framerate(stream_format = %AAC{}) do
    num = stream_format.sample_rate
    den = stream_format.samples_per_frame
    {num, den}
  end

  @impl true
  def handle_start_of_stream(pad, _ctx, state) do
    timer_actions =
      if state.timer_started? do
        []
      else
        {nom, denom} = state.framerate
        timer = {:demand_timer, Ratio.new(Time.seconds(denom), nom)}
        [start_timer: timer]
      end

    demand_actions = [demand: pad]

    {timer_actions ++ demand_actions, %{state | timer_started?: true}}
  end

  @impl true
  def handle_write({_mod, pad, _ref}, %Buffer{payload: payload}, _ctx, state) do
    %{tracks: tracks} = state

    tracks = %{tracks | pad => Track.push(tracks[pad], payload)}
    state = %{state | tracks: tracks}

    if ready_to_send?(tracks) do
      {buffers, tracks} = pop_buffers(tracks)

      payload = prepare_payload(buffers, state.type)

      KinoPlayer.cast(state.kino, {:buffer, payload, %{index: state.index}})

      {[], %{state | index: state.index + 1, tracks: Map.new(tracks)}}
    else
      {[], state}
    end
  end

  defp ready_to_send?(tracks) do
    Map.values(tracks) |> Enum.all?(&Track.ready?/1)
  end

  defp prepare_payload(buffers, type) do
    case type do
      :video ->
        buffers |> then(fn [{_name, buffer}] -> buffer end) |> Membrane.Payload.to_binary()

      :audio ->
        buffers |> then(fn [{_name, buffer}] -> buffer end) |> Membrane.Payload.to_binary()

      :both ->
        Map.new(buffers, fn {name, buffer} -> {name, Membrane.Payload.to_binary(buffer)} end)
    end
  end

  defp pop_buffers(tracks) do
    tracks
    |> Enum.map(fn {name, track} -> {name, Track.pop!(track)} end)
    |> Enum.map(fn {name, {buffer, track}} -> {{name, buffer}, {name, track}} end)
    |> Enum.unzip()
  end

  @impl true
  def handle_tick(:demand_timer, _ctx, state) do
    demand_actions = get_demand_actions(state.tracks)
    {demand_actions, state}
  end

  defp get_demand_actions(tracks) do
    Map.values(tracks) |> Enum.map(fn %Track{pad: pad} -> {:demand, pad} end)
  end

  @impl true
  def handle_end_of_stream(_pad, _ctx, state) do
    if state.timer_started? do
      {[stop_timer: :demand_timer], %{state | timer_started?: false, index: 0}}
    else
      {[], state}
    end
  end
end
