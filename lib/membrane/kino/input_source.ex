defmodule Membrane.Kino.InputSource do
  defmodule KinoSourceAlreadyOccupiedError do
    defexception [:message]
  end

  use Membrane.Source

  alias Membrane.Kino.Input, as: KinoInput

  alias Membrane.{
    RemoteStream,
    Time,
    Buffer
  }

  def_options kino: [
                spec: KinoInput.t(),
                description: "Membrane.Kino.Input.t() handle"
              ]

  def_output_pad :output,
    accepted_format: %RemoteStream{content_format: :WEBM, type: :bytestream},
    availability: :always,
    mode: :push

  @impl true
  def handle_init(_ctx, options) do
    {[], %{kino: options.kino}}
  end

  @impl true
  def handle_setup(ctx, state) do
    pid = self()

    case KinoInput.register(state.kino, pid) do
      :ok ->
        :ok

      {:error, :already_registered} ->
        raise KinoSourceAlreadyOccupiedError, message: "Kino source already occupied"
    end

    Membrane.ResourceGuard.register(
      ctx.resource_guard,
      fn -> :ok = KinoInput.unregister(state.kino, pid) end
    )

    {[], state}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[stream_format: {:output, %RemoteStream{content_format: :WEBM, type: :bytestream}}], state}
  end

  @impl true
  def handle_info({:audio_frame, info, binary}, ctx, state) do
    duration = Map.get(info, "duration", 0)

    buffer = %Buffer{
      payload: binary,
      metadata: %{
        duration: Time.milliseconds(duration)
      }
    }

    if ctx.pads.output.end_of_stream? do
      {[], state}
    else
      {[buffer: {:output, buffer}], state}
    end
  end

  @impl true
  def handle_info(:end_of_stream, _ctx, state) do
    {[{:end_of_stream, :output}], state}
  end
end
