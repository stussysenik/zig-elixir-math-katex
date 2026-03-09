defmodule Mix.Tasks.Math.Prove do
  @moduledoc "Runs the verified-first pipeline from the terminal."

  use Mix.Task

  @shortdoc "Prove and render a math prompt"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    query = Enum.join(args, " ") |> String.trim()

    if query == "" do
      Mix.raise("usage: mix math.prove \"calculate the derivative of sin(x)\"")
    end

    notify = fn stage, _payload -> Mix.shell().info("-> #{stage}") end

    case MathViz.Pipeline.run(query, notify: notify) do
      {:ok, result} ->
        Mix.shell().info("")
        Mix.shell().info("Adapter: #{result.adapter}")
        Mix.shell().info("Verified: #{result.is_verified}")
        Mix.shell().info("Expression: #{result.symbol.expression}")
        Mix.shell().info("LaTeX: #{result.symbol.latex}")
        Mix.shell().info("Proof: #{result.proof.state}")
        Mix.shell().info("Desmos: #{Jason.encode!(result.graph.desmos)}")
        Mix.shell().info("GeoGebra: #{Jason.encode!(result.graph.geogebra)}")

      {:error, reason} ->
        Mix.raise("pipeline failed: #{inspect(reason)}")
    end
  end
end
