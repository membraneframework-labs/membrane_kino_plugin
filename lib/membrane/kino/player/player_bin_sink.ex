defmodule Membrane.Kino.Player.Bin.Sink do
  @moduledoc """
  This module provides an universal video and audio player sink compatible with the Livebook environment.
  """

  use Membrane.Bin

  require Membrane.Logger

  alias Kino.JS.Live, as: KinoPlayer
  alias Membrane.{AAC, H264, RemoteStream, Realtimer}

  alias Membrane.Kino

  def_options kino: [
                spec: KinoPlayer.t(),
                description:
                  "Kino element handle. It should be initialized before the pipeline is started."
              ]

  def_input_pad :input,
    accepted_format:
      any_of(
        H264,
        AAC,
        %RemoteStream{type: :bytestream, content_format: content_format}
        when content_format in [nil, MP4]
      )

  @impl true
  def handle_init(_ctx, %__MODULE__{} = options) do
    kino = options.kino
    type = KinoPlayer.call(kino, :get_type)

    structure =
      case type do
        :both ->
          demuxer_structure(kino)

        :audio ->
          bin_input()
          |> via_in(:audio)
          |> child(:player, %Kino.Player.Sink{kino: kino})

        :video ->
          bin_input()
          |> via_in(:video)
          # |> child(:realtimer, Realtimer)
          |> child(:player, %Kino.Player.Sink{kino: kino})

      end

    {[spec: structure], %{}}
  end

  defp demuxer_structure(_kino) do
    raise "Player bin sink cannot handle MP4 yet. Membrane.MP4 does not support depayloader yet."
  end
end
