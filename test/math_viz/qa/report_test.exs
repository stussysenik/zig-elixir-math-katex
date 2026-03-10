defmodule MathViz.QA.ReportTest do
  use ExUnit.Case, async: true

  alias MathViz.QA.Report

  test "renders markdown with lane summaries" do
    summary = %{
      generated_at: "2026-03-10T12:00:00Z",
      scope: "smoke",
      browser: "all",
      lanes: [
        %{
          name: "exunit",
          status: "passed",
          exit_code: 0,
          duration_ms: 120,
          counts: %{total: 3, passed: 3, failed: 0, skipped: 0},
          log_path: "tmp/qa/latest/raw/exunit.log"
        }
      ],
      observations: ["playwright failed. Inspect tmp/qa/latest/raw/playwright.log"],
      artifacts: %{report: "tmp/qa/latest/report.md"}
    }

    markdown = Report.render_markdown(summary)

    assert markdown =~ "# QA Report"
    assert markdown =~ "### exunit"
    assert markdown =~ "Status: passed"
    assert markdown =~ "playwright failed"
  end
end
