defmodule Kino.Video.Binary do
  @moduledoc """
  Kino component capable of playing a video from the h264 binary frames.

  Element provides asynchronous API for sending frames to the player:
  ```elixir
  # upper cell
  kino = Kino.Video.Binary.new()

  #lower cell
  alias = Kino.JS.Live, as: KinoPlayer

  framerate = 30

  KinoPlayer.cast(kino, {:create, framerate})

  for frame <- generate_h264_frames() do
    KinoPlayer.cast(kino, {:buffer, frame, %{}})
    Process.sleep(round(1000 / framerate)))
  end
  ```
  """

  use Kino.JS, assets_path: "lib/assets/video_binary"
  use Kino.JS.Live

  @type t() :: Kino.JS.Live.t()

  @doc """
  Creates a new Kino.Video.Binary component. Returns a handle to the element.
  Should be invoked at the end of the cell or explicitly rendered.
  """
  def new(_opts \\ []) do
    Kino.JS.Live.new(__MODULE__, {})
  end

  @impl true
  def init(_args, ctx) do
    {:ok, assign(ctx, clients: [])}
  end

  @impl true
  def handle_connect(ctx) do
    client_id = random_id()

    info = %{
      client_id: client_id,
      clients: ctx.assigns.clients
    }

    {:ok, info, update(ctx, :clients, &(&1 ++ [client_id]))}
  end

  @impl true
  def handle_cast({:create, framerate}, ctx) do
    payload = %{framerate: framerate}
    broadcast_event(ctx, "create", payload)
    {:noreply, ctx}
  end

  @impl true
  def handle_cast({:buffer, buffer, info}, ctx) do
    payload = {:binary, info, buffer}
    broadcast_event(ctx, "buffer", payload)
    {:noreply, ctx}
  end

  defp random_id() do
    :crypto.strong_rand_bytes(5) |> Base.encode32(case: :lower)
  end
end
