defmodule MathViz.QA.HarnessTest do
  use ExUnit.Case, async: true

  alias MathViz.QA.Harness

  test "writes summary, report, and call graph artifacts" do
    output_dir = Path.join(System.tmp_dir!(), "math-viz-qa-#{System.unique_integer([:positive])}")

    runner = fn
      "mix", ["test" | _files], _opts ->
        {"Running ExUnit with seed: 1\n\n...\nFinished in 0.1 seconds\n3 tests, 0 failures\n", 0}

      "bun", ["run", "test:e2e:playwright"], _opts ->
        {"Running 4 tests\n4 passed (5.5s)\n", 0}

      "bun", ["run", "test:e2e:cypress"], _opts ->
        {"MathViz smoke\n4 passing\n", 0}
    end

    pipeline_runner = fn _prompt, opts ->
      MathViz.QA.CallGraph.record_call(
        Keyword.get(opts, :call_graph_pid),
        "pipeline.run",
        "pipeline.route",
        %{
          from_kind: "function",
          to_kind: "function",
          status: :passed,
          duration_ms: 1
        }
      )

      {:ok, :probe}
    end

    assert {:ok, summary} =
             Harness.run(
               scope: :smoke,
               browser: :all,
               output_dir: output_dir,
               command_runner: runner,
               pipeline_runner: pipeline_runner
             )

    assert File.exists?(summary.artifacts.summary)
    assert File.exists?(summary.artifacts.report)
    assert File.exists?(summary.artifacts.tool_call_graph)
    assert Enum.map(summary.lanes, & &1.name) == ["exunit", "playwright", "cypress"]
  end
end
