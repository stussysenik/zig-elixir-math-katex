defmodule MathViz.PipelineTest do
  use ExUnit.Case, async: true

  alias MathViz.Pipeline

  test "stub mode returns a verified result and graph payloads" do
    assert {:ok, result} = Pipeline.run("derivative of sin(x)", mode: :stub)

    assert result.is_verified
    assert result.symbol.expression == "cos(x)"
    assert result.proof.state == "Proof complete"
    assert result.graph.desmos.expression == "y=\\cos(x)"
    assert result.graph.geogebra.command == "f(x)=\\cos(x)"
  end

  test "dual mode falls back to the stub when NIM is unavailable" do
    assert {:ok, result} = Pipeline.run("derivative of sin(x)", mode: :dual)

    assert result.adapter == :stub
    assert Enum.any?(result.symbol.notes, &String.contains?(&1, "Fell back after NIM error"))
  end

  test "verification failure blocks graph rendering" do
    assert {:ok, result} = Pipeline.run("y=reject(x)", mode: :stub)

    refute result.is_verified
    assert result.error == :verification_failed
    assert result.graph.desmos == %{}
    assert result.graph.geogebra == %{}
  end
end
