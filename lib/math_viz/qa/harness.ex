defmodule MathViz.QA.Harness do
  @moduledoc false

  alias MathViz.QA.{CallGraph, Report}

  @smoke_test_files [
    "test/math_viz/pipeline_test.exs",
    "test/math_viz_web/live/math_orchestrator_live_test.exs",
    "test/math_viz_web/controllers/solve_controller_test.exs"
  ]

  @smoke_probes [
    {"pipeline.probe.computation", "Graph the derivative of x^2"},
    {"pipeline.probe.chat", "What is an integral?"}
  ]

  @type scope :: :smoke | :full
  @type browser :: :playwright | :cypress | :all
  @type runner :: (String.t(), [String.t()], keyword() -> {String.t(), non_neg_integer()})
  @type pipeline_runner :: (String.t(), keyword() -> {:ok, term()} | {:error, term()})

  @spec run(keyword()) :: {:ok, map()}
  def run(opts \\ []) do
    Mix.Task.run("app.start")

    scope = normalize_scope(Keyword.get(opts, :scope, :smoke))
    browser = normalize_browser(Keyword.get(opts, :browser, :all))
    output_dir = Keyword.get(opts, :output_dir, "tmp/qa/latest")
    runner = Keyword.get(opts, :command_runner, &default_runner/3)
    pipeline_runner = Keyword.get(opts, :pipeline_runner, &MathViz.Pipeline.run/2)

    File.mkdir_p!(Path.join(output_dir, "raw"))

    {:ok, graph_pid} = CallGraph.start_link()

    probe_observations = run_pipeline_probes(graph_pid, pipeline_runner)

    lanes =
      []
      |> Kernel.++([run_exunit_lane(scope, output_dir, graph_pid, runner)])
      |> maybe_add_playwright_lane(browser, output_dir, graph_pid, runner)
      |> maybe_add_cypress_lane(browser, output_dir, graph_pid, runner)

    observations =
      probe_observations ++
        Enum.flat_map(lanes, fn lane ->
          if lane.status == "failed" do
            ["#{lane.name} failed. Inspect #{lane.log_path}"]
          else
            []
          end
        end)

    graph = CallGraph.snapshot(graph_pid)
    graph_path = CallGraph.write!(graph, Path.join(output_dir, "tool_call_graph.json"))

    summary_path = Path.join(output_dir, "summary.json")
    report_path = Path.join(output_dir, "report.md")

    summary = %{
      generated_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      scope: Atom.to_string(scope),
      browser: Atom.to_string(browser),
      lanes: lanes,
      observations: observations,
      artifacts: %{
        summary: summary_path,
        report: report_path,
        tool_call_graph: graph_path
      }
    }

    File.write!(summary_path, Jason.encode!(summary, pretty: true))
    Report.write_markdown!(summary, report_path)

    {:ok, summary}
  end

  defp run_exunit_lane(scope, output_dir, graph_pid, runner) do
    args =
      case scope do
        :smoke -> ["test" | @smoke_test_files]
        :full -> ["test"]
      end

    run_lane("exunit", "mix", args, output_dir, graph_pid, runner, &parse_exunit_counts/1)
  end

  defp maybe_add_playwright_lane(lanes, browser, output_dir, graph_pid, runner)
       when browser in [:playwright, :all] do
    lane =
      run_lane(
        "playwright",
        "bun",
        ["run", "test:e2e:playwright"],
        output_dir,
        graph_pid,
        runner,
        &parse_playwright_counts/1
      )

    lanes ++ [lane]
  end

  defp maybe_add_playwright_lane(lanes, _browser, _output_dir, _graph_pid, _runner), do: lanes

  defp maybe_add_cypress_lane(lanes, browser, output_dir, graph_pid, runner)
       when browser in [:cypress, :all] do
    lane =
      run_lane(
        "cypress",
        "bun",
        ["run", "test:e2e:cypress"],
        output_dir,
        graph_pid,
        runner,
        &parse_cypress_counts/1
      )

    lanes ++ [lane]
  end

  defp maybe_add_cypress_lane(lanes, _browser, _output_dir, _graph_pid, _runner), do: lanes

  defp run_lane(name, command, args, output_dir, graph_pid, runner, parser) do
    {{output, exit_code}, duration_ms} =
      timed(fn ->
        try do
          {stdout, status} =
            runner.(command, args, cd: File.cwd!(), stderr_to_stdout: true, env: lane_env(name))

          {stdout, status}
        rescue
          error ->
            {"#{Exception.format(:error, error, __STACKTRACE__)}\n", 1}
        end
      end)

    log_path = write_lane_log!(output_dir, name, output)
    counts = parser.(output)
    status = if exit_code == 0, do: "passed", else: "failed"

    CallGraph.record_call(graph_pid, "qa.report", name, %{
      from_kind: "harness",
      to_kind: "tool",
      duration_ms: duration_ms,
      status: status,
      metadata: %{command: Enum.join([command | args], " "), log_path: log_path}
    })

    %{
      name: name,
      exit_code: exit_code,
      status: status,
      duration_ms: duration_ms,
      counts: counts,
      log_path: log_path
    }
  end

  defp run_pipeline_probes(graph_pid, pipeline_runner) do
    Enum.flat_map(@smoke_probes, fn {probe_name, prompt} ->
      {result, duration_ms} =
        timed(fn ->
          pipeline_runner.(prompt,
            mode: :stub,
            nim_fallback_mode: :fallback,
            call_graph_pid: graph_pid
          )
        end)

      status =
        case result do
          {:ok, _} -> "passed"
          {:error, _} -> "failed"
        end

      CallGraph.record_call(graph_pid, "qa.report", probe_name, %{
        from_kind: "harness",
        to_kind: "tool",
        kind: "probes",
        duration_ms: duration_ms,
        status: status,
        metadata: %{prompt: prompt}
      })

      case result do
        {:ok, _} -> []
        {:error, reason} -> ["#{probe_name} failed: #{inspect(reason)}"]
      end
    end)
  end

  defp lane_env("playwright"), do: [{"CI", "1"}]
  defp lane_env("cypress"), do: [{"CI", "1"}, {"NO_COLOR", "1"}]
  defp lane_env(_name), do: []

  defp write_lane_log!(output_dir, name, output) do
    path = Path.join([output_dir, "raw", "#{name}.log"])
    File.write!(path, output)
    path
  end

  defp parse_exunit_counts(output) do
    total = regex_count(output, ~r/(\d+)\s+tests?,\s+\d+\s+failures?/, 1)
    failed = regex_count(output, ~r/\d+\s+tests?,\s+(\d+)\s+failures?/, 1)
    skipped = regex_count(output, ~r/(\d+)\s+excluded/, 1)

    %{
      total: total,
      passed: max(total - failed - skipped, 0),
      failed: failed,
      skipped: skipped
    }
  end

  defp parse_playwright_counts(output) do
    passed = regex_count(output, ~r/(\d+)\s+passed/, 1)
    failed = regex_count(output, ~r/(\d+)\s+failed/, 1)
    skipped = regex_count(output, ~r/(\d+)\s+skipped/, 1)

    %{
      total: passed + failed + skipped,
      passed: passed,
      failed: failed,
      skipped: skipped
    }
  end

  defp parse_cypress_counts(output) do
    passed = regex_count(output, ~r/(\d+)\s+passing/, 1)
    failed = regex_count(output, ~r/(\d+)\s+failing/, 1)
    skipped = regex_count(output, ~r/(\d+)\s+pending/, 1)

    %{
      total: passed + failed + skipped,
      passed: passed,
      failed: failed,
      skipped: skipped
    }
  end

  defp regex_count(output, regex, capture_index) do
    case Regex.run(regex, output) do
      nil -> 0
      captures -> captures |> Enum.at(capture_index) |> String.to_integer()
    end
  end

  defp normalize_scope(:smoke), do: :smoke
  defp normalize_scope("smoke"), do: :smoke
  defp normalize_scope(:full), do: :full
  defp normalize_scope("full"), do: :full
  defp normalize_scope(_other), do: :smoke

  defp normalize_browser(:playwright), do: :playwright
  defp normalize_browser("playwright"), do: :playwright
  defp normalize_browser(:cypress), do: :cypress
  defp normalize_browser("cypress"), do: :cypress
  defp normalize_browser(:all), do: :all
  defp normalize_browser("all"), do: :all
  defp normalize_browser(_other), do: :all

  defp default_runner(command, args, opts), do: System.cmd(command, args, opts)

  defp timed(fun) do
    started_at = System.monotonic_time()
    result = fun.()

    duration_ms =
      System.monotonic_time()
      |> Kernel.-(started_at)
      |> System.convert_time_unit(:native, :millisecond)

    {result, duration_ms}
  end
end
