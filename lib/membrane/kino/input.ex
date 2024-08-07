defmodule Membrane.Kino.Input do
  @moduledoc """
  Kino component capable of capturing audio from the microphone or video from the camera.

  Element provides synchronous API for sending frames to the different processes:
  ```elixir
  # upper cell
  alias Membrane.Kino.Input, as: KinoInput
  kino = KinoInput.new(audio: true)

  #lower cell

  KinoInput.register(kino, self())
  Enum.each(1..20, fn _ ->
    receive do
      {:audio_frame, info, binary} ->
        IO.puts("Received audio frame with info: " <> inspect(info))
    end
  end)

  KinoInput.unregister(kino, self())

  ```
  """
  use Kino.JS, assets_path: "lib/assets/input"
  use Kino.JS.Live

  alias Membrane.Time

  defmodule InputError do
    defexception [:message]
  end

  @type t() :: Kino.JS.Live.t()

  @doc """
  Creates a new Membrane.Kino.Input component. Returns a handle to the input.
  Should be invoked at the end of the cell or explicitly rendered.
  """
  @spec new(audio: boolean(), video: boolean() | %{}, flush_time: Time.t()) :: t()
  def new(opts) do
    opts = Keyword.validate!(opts, video: false, audio: false, flush_time: Time.milliseconds(1))

    if opts[:video] == false and opts[:audio] == false do
      raise ArgumentError, "At least one of :video or :audio should be true"
    end

    info = %{
      type: %{
        video: sanitize_video_parameters(opts[:video]),
        audio: opts[:audio]
      },
      flush_time: Time.as_milliseconds(opts[:flush_time], :round)
    }

    Kino.JS.Live.new(__MODULE__, info)
  end

  defp sanitize_video_parameters(%{} = video) do
    video
    |> Map.put_new(:desired_width, 1920)
    |> Map.put_new(:desired_height, 1080)
    |> Map.put_new(:desired_framerate, 30)
  end

  defp sanitize_video_parameters(true = _video) do
    %{desired_width: 1920, desired_height: 1080, desired_framerate: 30}
  end

  defp sanitize_video_parameters(_video), do: false

  @doc """
  Registers a process to receive audio frames from the input. Process will receive
  {:audio_frame, info, binary} messages.

  Only one process can be registered at a time.
  """
  @spec register(t(), pid()) :: :ok | {:error, :already_registered}
  def register(kino, registering_pid) do
    Kino.JS.Live.call(kino, {:register, registering_pid})
  end

  @doc """
  Unregisters a process from receiving audio frames from the input.
  """
  @spec unregister(t(), pid()) :: :ok | {:error, :not_registered}
  def unregister(kino, unregistered_pid) do
    Kino.JS.Live.call(kino, {:unregister, unregistered_pid})
  end

  @impl true
  def init(info, ctx) do
    {:ok, assign(ctx, info: info, client: nil, client_ref: nil)}
  end

  @impl true
  def handle_connect(ctx) do
    info = ctx.assigns.info

    {:ok, info, ctx}
  end

  @impl true
  def handle_event("audio_frame", {:binary, info, binary}, ctx) do
    if ctx.assigns.client do
      send(ctx.assigns.client, {:audio_frame, info, binary})
    end

    {:noreply, ctx}
  end

  @impl true
  def handle_event("framerate", framerate, ctx) do
    if ctx.assigns.client do
      send(ctx.assigns.client, {:framerate, framerate})
    end

    {:noreply, ctx}
  end

  @impl true
  def handle_event("video_frame", {:binary, info, binary}, ctx) do
    if ctx.assigns.client do
      send(ctx.assigns.client, {:video_frame, info, binary})
    end

    {:noreply, ctx}
  end

  def handle_event("audio_video_frame", {:binary, info, binary}, ctx) do
    if ctx.assigns.client do
      send(ctx.assigns.client, {:audio_video_frame, info, binary})
    end

    {:noreply, ctx}
  end

  @impl true
  def handle_event("recording_started", _info, ctx) do
    {:noreply, ctx}
  end

  @impl true
  def handle_event("recording_stopped", _info, ctx) do
    if ctx.assigns.client do
      send(ctx.assigns.client, :end_of_stream)
    end

    {:noreply, ctx}
  end

  @impl true
  def handle_event("error", error, _ctx) do
    raise InputError, message: error
  end

  @impl true
  def handle_call({:register, from}, _sender, ctx) do
    if ctx.assigns.client do
      {:reply, {:error, :already_registered}, ctx}
    else
      ref = Process.monitor(from)
      {:reply, :ok, assign(ctx, client: from, client_ref: ref)}
    end
  end

  @impl true
  def handle_call({:unregister, from}, _sender, ctx) do
    case unregister_listener(from, ctx) do
      {:ok, ctx} ->
        {:reply, :ok, ctx}

      {:error, :not_registered} ->
        {:reply, {:error, :not_registered}, ctx}
    end
  end

  @impl true
  def handle_call(:get_type, _sender, ctx) do
    {:reply, ctx.assigns.info.type, ctx}
  end

  defp unregister_listener(from, ctx) do
    if ctx.assigns.client in [from, nil] do
      {:ok, assign(ctx, client: nil)}
    else
      {:error, :not_registered}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, ctx) when ctx.assigns.client_ref == ref do
    case unregister_listener(pid, ctx) do
      {:ok, ctx} ->
        {:noreply, ctx}

      {:error, :not_registered} ->
        raise InputError, message: "Unexpected DOWN message"
    end
  end
end
