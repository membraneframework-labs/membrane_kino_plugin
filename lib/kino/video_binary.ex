defmodule Kino.Video.Binary do
  use Kino.JS, assets_path: "lib/assets/video_binary"
  use Kino.JS.Live

  @type t() :: Kino.JS.Live.t()

  def new() do
    Kino.JS.Live.new(__MODULE__, nil)
  end

  @impl true
  def handle_connect(ctx) do
    IO.inspect("handle_connect")

    payload = {:binary, %{message: "hello"}, <<1, 2>>}
    {:ok, payload, ctx}
  end

  @impl true
  def handle_call({:create, {width, height}}, _from, ctx) do
    IO.inspect("handle_call create")

    payload = %{width: width, height: height}
    broadcast_event(ctx, "create", payload)
    {:reply, :ok, ctx}
  end

  @impl true
  def handle_call({:buffer, buffer}, _from, ctx) do
    IO.inspect("handle_call buffer")

    payload = {:binary, %{}, buffer}
    broadcast_event(ctx, "buffer", payload)
    {:reply, :ok, ctx}
  end

  # @impl true
  # def handle_event("ping", {:binary, _info, binary}, ctx) do
  #   reply_payload = {:binary, %{message: "pong"}, <<1, 2, binary::binary>>}
  #   broadcast_event(ctx, "pong", reply_payload)
  #   {:noreply, ctx}
  # end
end
