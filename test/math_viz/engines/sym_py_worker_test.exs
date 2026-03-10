defmodule MathViz.Engines.SymPyWorkerTest do
  use ExUnit.Case, async: true

  alias MathViz.Engines.SymPyWorker

  test "executes an allowed SymPy expression" do
    assert {:ok, response} = SymPyWorker.execute("diff(x^2, x)")
    assert response.ok
    assert response.result_string == "2*x"
    assert response.result_latex == "2 x"
  end

  test "rejects unsupported identifiers" do
    assert {:error, {:sympy_execution_failed, message}} = SymPyWorker.execute("reject(x)")
    assert message =~ "Unsupported identifier"
  end
end
