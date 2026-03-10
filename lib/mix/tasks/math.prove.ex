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

    case MathViz.Solve.run(%{"query" => query}, notify: notify) do
      {:ok, response} ->
        symbol = response.symbol || %{}
        proof = response.proof || %{}
        graph = response.graph || %{}

        Mix.shell().info("")
        Mix.shell().info("Adapter: #{response.adapter}")
        Mix.shell().info("Mode: #{response.mode}")
        Mix.shell().info("Verified: #{response.verified}")
        Mix.shell().info("Chat reply: #{response.chat_reply || "n/a"}")
        Mix.shell().info("Expression: #{Map.get(symbol, :expression, "n/a")}")
        Mix.shell().info("LaTeX: #{Map.get(symbol, :latex, "n/a")}")
        Mix.shell().info("Proof: #{Map.get(proof, :state, "n/a")}")
        Mix.shell().info("Desmos: #{Jason.encode!(Map.get(graph, :desmos, %{}))}")
        Mix.shell().info("GeoGebra: #{Jason.encode!(Map.get(graph, :geogebra, %{}))}")
        Mix.shell().info("Timings: #{inspect(response.timings)}")

      {:error, %Ecto.Changeset{} = changeset} ->
        Mix.raise(
          "invalid request: #{inspect(Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end))}"
        )

      {:error, reason} ->
        Mix.raise("pipeline failed: #{inspect(reason)}")
    end
  end
end
