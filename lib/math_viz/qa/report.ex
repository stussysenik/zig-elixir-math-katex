defmodule MathViz.QA.Report do
  @moduledoc false

  @spec render_markdown(map()) :: String.t()
  def render_markdown(summary) do
    generated_at = Map.fetch!(summary, :generated_at)
    scope = Map.fetch!(summary, :scope)
    browser = Map.fetch!(summary, :browser)
    lanes = Map.get(summary, :lanes, [])
    artifacts = Map.get(summary, :artifacts, %{})
    observations = Map.get(summary, :observations, [])

    sections = [
      "# QA Report",
      "",
      "Generated at: #{generated_at}",
      "Scope: #{scope}",
      "Browser lanes: #{browser}",
      "",
      "## Results",
      "",
      Enum.map_join(lanes, "\n", &render_lane/1),
      "",
      "## Artifacts",
      "",
      Enum.map_join(artifacts, "\n", fn {name, path} -> "- #{name}: #{path}" end),
      "",
      "## Observations",
      ""
    ]

    sections =
      if observations == [] do
        sections ++ ["- None"]
      else
        sections ++ Enum.map(observations, &"- #{&1}")
      end

    Enum.join(sections, "\n")
  end

  @spec write_markdown!(map(), Path.t()) :: Path.t()
  def write_markdown!(summary, path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, render_markdown(summary))
    path
  end

  defp render_lane(lane) do
    counts = Map.get(lane, :counts, %{})

    """
    ### #{Map.fetch!(lane, :name)}

    - Status: #{Map.fetch!(lane, :status)}
    - Exit code: #{Map.fetch!(lane, :exit_code)}
    - Duration: #{Map.fetch!(lane, :duration_ms)} ms
    - Total: #{Map.get(counts, :total, "n/a")}
    - Passed: #{Map.get(counts, :passed, "n/a")}
    - Failed: #{Map.get(counts, :failed, "n/a")}
    - Skipped: #{Map.get(counts, :skipped, "n/a")}
    - Log: #{Map.fetch!(lane, :log_path)}
    """
    |> String.trim_trailing()
  end
end
