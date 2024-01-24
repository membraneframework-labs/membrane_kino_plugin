defmodule Membrane.Kino.Player do
  @moduledoc """
  Kino component capable of playing a H264 video and AAC audio from the stream buffers.

  Element provides asynchronous API for sending frames to the player:
  ```elixir
  # upper cell
  alias Membrane.Kino.Player, as: KinoPlayer
  kino = KinoPlayer.new(video: true)

  #lower cell
  framerate = 30

  KinoPlayer.create(kino, framerate)

  Enum.each(generate_h264_frames(),
  fn frame ->
    KinoPlayer.send_buffer(kino, frame, %{type: :video})
    Process.sleep(round(1000 / framerate)))
  end
  )
  ```
  """

  defmodule PlayerError do
    defexception [:message]
  end

  defmodule JMuxerError do
    defexception [:message]
  end

  use Kino.JS, assets_path: "lib/assets/player"
  use Kino.JS.Live

  alias Membrane.Time

  @type t() :: Kino.JS.Live.t()

  @type buffer() :: %{optional(:video) => binary() | nil, optional(:audio) => binary() | nil}
  @type buffer_info() :: %{}

  @doc """
  Creates a new Membrane.Kino.Player component. Returns a handle to the player.
  Should be invoked at the end of the cell or explicitly rendered.

  At least one of the `:video` or `:audio` options should be set to `true`.
  """
  @spec new(video: boolean(), audio: boolean(), flush_time: Time.t()) :: t()
  def new(opts) do
    opts = Keyword.validate!(opts, video: false, audio: false, flush_time: Time.milliseconds(0))

    type = Keyword.take(opts, [:video, :audio])

    if not (opts[:video] or opts[:audio]) do
      raise ArgumentError, "At least one of :video or :audio should be true"
    end

    info = %{
      type: type,
      flush_time: Time.as_milliseconds(opts[:flush_time], :round)
    }

    Kino.JS.Live.new(__MODULE__, info)
  end

  @doc """
  Gets the type of the player.
  """
  @spec get_type(t()) :: :video | :audio | :both
  def get_type(kino) do
    Kino.JS.Live.call(kino, :get_type)
  end

  @doc """
  Creates a player with the given framerate.

  It is required to create player before sending buffers to it.
  """
  @spec create(t(), float()) :: {:ok, :player_created} | {:error, :already_created}
  def create(kino, framerate) do
    Kino.JS.Live.call(kino, {:create, framerate})
  end

  @doc """
  Sends a buffer to the player.

  Buffer should be a map with :video and :audio keys with binary payloads.

  It is required to create player before sending buffers to it.
  See `create/2` function.
  """
  @spec send_buffer(t(), buffer(), buffer_info()) :: :ok
  def send_buffer(kino, buffer, info) do
    IO.inspect(buffer, label: "send_buffer")

    Kino.JS.Live.cast(kino, {:buffer, buffer, info})
  end

  @impl true
  def init(info, ctx) do
    {:ok,
     assign(ctx,
       clients: [],
       jmuxer_ready: false,
       info: info,
       created_from: nil,
       initialized: false,
       jmuxer_options: nil
     )}
  end

  @impl true
  def handle_call(:get_type, _from, ctx) do
    {:reply, ctx.assigns.info.type, ctx}
  end

  @impl true
  def handle_call({:create, framerate}, from, ctx) do
    if ctx.assigns.created_from do
      {:reply, {:error, :already_created}, ctx}
    else
      payload = %{framerate: framerate}

      if ctx.assigns.initialized do
        broadcast_event(ctx, "create", payload)
      end

      {:noreply, assign(ctx, created_from: from, jmuxer_options: payload)}
    end
  end

  @impl true
  def handle_cast({:buffer, buffers, info}, ctx) do
    type = ctx.assigns.info.type

    if buffers[:video] && not type[:video] do
      raise JMuxerError,
        message: "Player was created without video support, video buffer provided"
    end

    if buffers[:audio] && not type[:audio] do
      raise JMuxerError,
        message: "Player was created without audio support, audio buffer provided"
    end

    video = Map.get(buffers, :video, <<>>)
    audio = Map.get(buffers, :audio, <<>>)

    info = info |> Map.put(:video_size, byte_size(video))
    payload = {:binary, info, video <> audio}
    send_payload(payload, ctx)
  end

  @impl true
  def handle_event("initialized", _info, ctx) do
    if ctx.assigns.created_from do
      payload = ctx.assigns.jmuxer_options
      broadcast_event(ctx, "create", payload)
    end

    {:noreply, assign(ctx, initialized: true)}
  end

  @impl true
  def handle_event("jmuxer_ready", _info, ctx) do
    GenServer.reply(ctx.assigns.created_from, {:ok, :player_created})
    {:noreply, assign(ctx, jmuxer_ready: true)}
  end

  @impl true
  def handle_event("error", error, _ctx) do
    raise PlayerError, message: error
  end

  defp send_payload(payload, ctx) do
    broadcast_event(ctx, "buffer", payload)
    {:noreply, ctx}
  end

  @impl true
  def handle_connect(ctx) do
    client_id = random_id()

    info =
      ctx.assigns.info
      |> Map.update!(:type, &type_to_strings/1)
      |> Map.put(:client_id, client_id)

    {:ok, info, update(ctx, :clients, &(&1 ++ [client_id]))}
  end

  defp type_to_strings(type) do
    Enum.map(type, fn {key, val} -> {key, Atom.to_string(val)} end) |> Map.new()
  end

  defp random_id() do
    :crypto.strong_rand_bytes(5) |> Base.encode32(case: :lower)
  end
end
