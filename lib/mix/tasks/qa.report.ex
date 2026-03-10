defmodule Mix.Tasks.Qa.Report do
  @moduledoc "Runs the QA harness and writes a report under tmp/qa."

  use Mix.Task

  alias MathViz.QA.Harness

  @shortdoc "Run ExUnit + browser QA and emit report artifacts"

  @switches [scope: :string, browser: :string, output: :string]

  @impl true
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, switches: @switches)

    {:ok, summary} =
      Harness.run(
        scope: Keyword.get(opts, :scope, "smoke"),
        browser: Keyword.get(opts, :browser, "all"),
        output_dir: Keyword.get(opts, :output, "tmp/qa/latest")
      )

    Mix.shell().info("QA report written to #{summary.artifacts.report}")
    Mix.shell().info(File.read!(summary.artifacts.report))

    if Enum.any?(summary.lanes, &(&1.status == "failed")) do
      Mix.raise("qa.report detected failing lanes")
    end
  end
end
