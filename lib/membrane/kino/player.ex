defmodule Membrane.Kino.Player do
  @moduledoc """
  Kino component capable of playing a H264 video and AAC audio from the stream buffers.

  Element provides asynchronous API for sending frames to the player:
  ```elixir
  # upper cell
  alias Membrane.Kino.Player, as: KinoPlayer
  kino = KinoPlayer.new(:video)

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

  @type buffer_t() :: binary() | %{video: binary(), audio: binary()}
  @type buffer_info_t() :: %{type: :video | :audio | :both}

  @doc """
  Creates a new Membrane.Kino.Player component. Returns a handle to the player.
  Should be invoked at the end of the cell or explicitly rendered.
  """
  @spec new(:video | :audio | :both, flush_time: Time.t()) :: t()
  def new(type \\ :video, opts \\ []) do
    opts = Keyword.validate!(opts, flush_time: Time.milliseconds(0))

    info = Map.new(opts) |> Map.update!(:flush_time, &Time.round_to_milliseconds/1)
    Kino.JS.Live.new(__MODULE__, {type, info})
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
  @spec create(t(), framerate: float()) :: {:ok, :player_created} | {:error, :already_created}
  def create(kino, framerate) do
    Kino.JS.Live.call(kino, {:create, framerate})
  end

  @doc """
  Sends a buffer to the player.

  Buffer should be a binary or a map with :video and :audio keys.
  Field `info` should specify the type of the buffer.

  It is required to create player before sending buffers to it.
  See `create/2` function.
  """
  @spec send_buffer(t(), buffer_t(), buffer_info_t()) :: :ok
  def send_buffer(kino, buffer, info) do
    Kino.JS.Live.cast(kino, {:buffer, buffer, info})
  end

  @impl true
  def init({type, info}, ctx) do
    {:ok,
     assign(ctx,
       clients: [],
       type: type,
       jmuxer_ready: false,
       info: info,
       created_from: nil,
       initialized: false,
       jmuxer_options: nil
     )}
  end

  @impl true
  def handle_call(:get_type, _from, ctx) do
    {:reply, ctx.assigns.type, ctx}
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
  def handle_cast({:buffer, %{video: video, audio: audio}, info}, ctx)
      when ctx.assigns.type == :both do
    info = info |> Map.put(:video_size, byte_size(video)) |> Map.put_new(:type, :both)
    payload = {:binary, info, video <> audio}
    send_payload(payload, ctx)
  end

  @impl true
  def handle_cast({:buffer, buffer, %{type: type} = info}, ctx)
      when type in [:audio, :video] and
             ctx.assigns.type == :both do
    payload = {:binary, info, buffer}
    send_payload(payload, ctx)
  end

  @impl true
  def handle_cast({:buffer, buffer, info}, ctx) when ctx.assigns.type in [:audio, :video] do
    payload = {:binary, info, buffer}
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

    info = %{
      type: ctx.assigns.type,
      flush_time: ctx.assigns.info.flush_time,
      client_id: client_id
    }

    {:ok, info, update(ctx, :clients, &(&1 ++ [client_id]))}
  end

  defp random_id() do
    :crypto.strong_rand_bytes(5) |> Base.encode32(case: :lower)
  end
end
