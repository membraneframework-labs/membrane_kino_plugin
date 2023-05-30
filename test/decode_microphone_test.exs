defmodule Membrane.DecodeMicrophoneTest do
  use ExUnit.Case, async: true
  import Membrane.Testing.Assertions

  require Logger

  alias Membrane.Testing.Pipeline

  import Membrane.ChildrenSpec

  alias Membrane.{
    Opus,
    AAC,
    KinoTest
  }

  setup _ctx do
    %{}
  end

  @tag :tmp_dir
  @tag timeout: :infinity
  test "Checks if audio and video are interleaved correctly", %{tmp_dir: tmp_dir} do
    output_file = Path.join(tmp_dir, "output.aac")

    structure =
      child(:input, %KinoTest.InputSourceBin{location: "./test/fixtures/test.webm.opus"})
      |> child(:from_opus, Opus.Decoder)
      |> child(:to_aac, AAC.FDK.Encoder)
      |> child(:sink, %Membrane.File.Sink{location: output_file})

    pipeline = Pipeline.start_link_supervised!(structure: structure)

    assert_pipeline_play(pipeline)

    assert_end_of_stream(pipeline, :sink)

    assert File.exists?(output_file)
  end
end
