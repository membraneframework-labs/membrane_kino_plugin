defmodule Kino.Video.Binary do
  use Kino.JS, assets_path: "lib/assets/video_binary"
  use Kino.JS.Live

  @type t() :: Kino.JS.Live.t()

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
    IO.inspect("Kino.Video.Binary handle_cast create")

    payload = %{framerate: framerate}
    broadcast_event(ctx, "create", payload)
    {:noreply, ctx}
  end

  @impl true
  def handle_cast({:buffer, buffer, info}, ctx) do
    IO.inspect("Kino.Video.Binary handle_cast buffer")

    payload = {:binary, info, buffer}
    broadcast_event(ctx, "buffer", payload)
    {:noreply, ctx}
  end

  defp random_id() do
    :crypto.strong_rand_bytes(5) |> Base.encode32(case: :lower)
  end
end
