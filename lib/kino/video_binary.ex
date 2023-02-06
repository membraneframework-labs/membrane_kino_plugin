defmodule Kino.Video.Binary do
  use Kino.JS, assets_path: "lib/assets/video_binary"
  use Kino.JS.Live

  @type t() :: Kino.JS.Live.t()

  def new() do
    Kino.JS.Live.new(__MODULE__, nil)
  end

  @impl true
  def init(_args, ctx) do
    IO.inspect("Kino.Video.Binary init")

    {:ok, assign(ctx, clients: [])}
  end

  @impl true
  def handle_connect(ctx) do
    IO.inspect("Kino.Video.Binary handle_connect")

    client_id = random_id()

    info = %{
      client_id: client_id,
      clients: ctx.assigns.clients
    }

    broadcast_event(ctx, "client_join", %{client_id: client_id})

    {:ok, info, update(ctx, :clients, &(&1 ++ [client_id]))}
  end

  @impl true
  def handle_cast({:create, {width, height}}, ctx) do
    IO.inspect("Kino.Video.Binary handle_cast create")

    payload = %{width: width, height: height}
    broadcast_event(ctx, "create", payload)
    {:noreply, ctx}
  end

  @impl true
  def handle_cast({:buffer, buffer}, ctx) do
    IO.inspect("Kino.Video.Binary handle_cast buffer")

    payload = {:binary, info, buffer}
    broadcast_event(ctx, "buffer", payload)
    {:noreply, ctx}
  end

  # @impl true
  # def handle_event("ping", {:binary, _info, binary}, ctx) do
  #   reply_payload = {:binary, %{message: "pong"}, <<1, 2, binary::binary>>}
  #   broadcast_event(ctx, "pong", reply_payload)
  #   {:noreply, ctx}
  # end

  defp random_id() do
    :crypto.strong_rand_bytes(5) |> Base.encode32(case: :lower)
  end
end
