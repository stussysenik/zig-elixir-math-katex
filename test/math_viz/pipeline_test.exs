defmodule MathViz.PipelineTest.RejectingVerifier do
  @behaviour MathViz.Morphisms.Verifier

  alias MathViz.Core.{Proof, Symbol}

  @impl true
  def verify(%Symbol{}, _opts) do
    {:ok,
     %Proof{
       verified: false,
       state: "Verification rejected",
       summary: "Rejected by the test verifier."
     }}
  end
end

defmodule MathViz.PipelineTest do
  use ExUnit.Case, async: true

  alias MathViz.Pipeline

  test "stub mode returns a verified result and graph payloads" do
    assert {:ok, result} = Pipeline.run("Graph the derivative of x^2", mode: :stub)

    assert result.is_verified
    assert result.symbol.expression == "2*x"
    assert result.proof.state == "Proof complete"
    assert result.graph.desmos.expressions |> hd() |> Map.get(:latex) == "y=2*x"
    assert result.graph.geogebra.command == "f(x)=2*x"
    assert is_integer(result.timings.sympy_ms)
  end

  test "dual mode falls back to the stub when NIM is unavailable" do
    assert {:ok, result} = Pipeline.run("derivative of sin(x)", mode: :dual)

    assert result.adapter == :stub
    assert Enum.any?(result.symbol.notes, &String.contains?(&1, "Fell back after NIM error"))
  end

  test "verification failure blocks graph rendering" do
    assert {:ok, result} =
             Pipeline.run("derivative of sin(x)",
               mode: :stub,
               verifier: MathViz.PipelineTest.RejectingVerifier
             )

    refute result.is_verified
    assert result.error == :verification_failed
    assert result.graph.desmos == %{}
    assert result.graph.geogebra == %{}
  end

  test "stub mode stays deterministic when a vision payload is attached" do
    assert {:ok, result} =
             Pipeline.run("",
               mode: :stub,
               vision: %{
                 bytes:
                   Base.decode64!(
                     "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP+X2VINQAAAABJRU5ErkJggg=="
                   ),
                 mime: "image/png",
                 filename: "whiteboard.png"
               }
             )

    assert result.is_verified
    assert result.graph.desmos.expressions |> hd() |> Map.get(:latex) == "y=x^2"
    assert Enum.any?(result.symbol.notes, &String.contains?(&1, "Vision input attached"))
  end
end
