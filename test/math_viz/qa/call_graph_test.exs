defmodule MathViz.QA.CallGraphTest do
  use ExUnit.Case, async: true

  alias MathViz.QA.CallGraph

  test "records nodes and edges" do
    {:ok, pid} = CallGraph.start_link()

    CallGraph.record_call(pid, "qa.report", "playwright", %{
      from_kind: "harness",
      to_kind: "tool",
      duration_ms: 12,
      status: :passed
    })

    graph = CallGraph.snapshot(pid)

    assert Enum.any?(graph.nodes, &(&1.id == "qa.report"))
    assert Enum.any?(graph.nodes, &(&1.id == "playwright"))

    assert [
             %{
               from: "qa.report",
               to: "playwright",
               duration_ms: 12,
               kind: "calls",
               status: "passed"
             }
           ] = graph.edges
  end
end
