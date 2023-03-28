defmodule Membrane.Kino.Player do
  @moduledoc """
  Kino component capable of playing a H264 video and AAC audio from the stream buffers.

  Element provides asynchronous API for sending frames to the player:
  ```elixir
  # upper cell
  kino = Membrane.Kino.Player.new(:video)

  #lower cell
  alias = Kino.JS.Live, as: KinoPlayer

  framerate = 30

  KinoPlayer.call(kino, {:create, framerate})

  Enum.each(generate_h264_frames(),
  fn frame ->
    KinoPlayer.cast(kino, {:buffer, frame, %{}})
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

  @type t() :: Kino.JS.Live.t()

  @type player_type_t :: :video | :audio | :both

  @jmuxer_check_interval_ms 1000

  @doc """
  Creates a new Membrane.Kino.Player component. Returns a handle to the player.
  Should be invoked at the end of the cell or explicitly rendered.
  """
  @spec new(player_type_t, []) :: t()
  def new(type \\ :video, _opts \\ []) do
    Kino.JS.Live.new(__MODULE__, type)
  end

  @impl true
  def init(type, ctx) do
    {:ok, assign(ctx, clients: [], type: type, jmuxer_ready: false)}
  end

  @impl true
  def handle_call(:get_type, _from, ctx) do
    {:reply, ctx.assigns.type, ctx}
  end

  @impl true
  def handle_call({:create, framerate}, from, ctx) do
    payload = %{framerate: framerate}

    broadcast_event(ctx, "create", payload)

    {:noreply, assign(ctx, created_from: from)}
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
      client_id: client_id
    }

    {:ok, info, update(ctx, :clients, &(&1 ++ [client_id]))}
  end

  defp random_id() do
    :crypto.strong_rand_bytes(5) |> Base.encode32(case: :lower)
  end
end
