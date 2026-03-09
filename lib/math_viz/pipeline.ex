defmodule MathViz.Pipeline do
  @moduledoc "CLI-first orchestration for the verified-first math pipeline."

  alias MathViz.Core.{Graph, Query}
  alias MathViz.Result

  @type notify_fun :: (atom(), map() -> any())

  @spec run(String.t(), keyword()) :: {:ok, Result.t()} | {:error, term()}
  def run(query_text, opts \\ []) when is_binary(query_text) do
    notify = Keyword.get(opts, :notify, fn _, _ -> :ok end)
    query = Query.new(query_text)

    with {:ok, symbol, adapter, nlp_ms} <- route(query, opts, notify),
         {:ok, proof, verify_ms} <- verify(symbol, opts, notify) do
      case proof.verified do
        true ->
          with {:ok, graph, graph_ms} <- render(symbol, proof, opts, notify) do
            result =
              %Result{
                query: query,
                symbol: symbol,
                proof: proof,
                graph: graph,
                is_verified: true,
                status: :rendering,
                timings: %{nlp_ms: nlp_ms, verify_ms: verify_ms, graph_ms: graph_ms},
                adapter: adapter
              }

            notify.(:complete, %{result: result})
            {:ok, result}
          end

        false ->
          result =
            %Result{
              query: query,
              symbol: symbol,
              proof: proof,
              graph: %Graph{latex_block: symbol.latex},
              is_verified: false,
              status: :error,
              timings: %{nlp_ms: nlp_ms, verify_ms: verify_ms, graph_ms: 0},
              adapter: adapter,
              error: :verification_failed
            }

          notify.(:complete, %{result: result})
          {:ok, result}
      end
    else
      {:error, _} = error ->
        error
    end
  end

  defp route(query, opts, notify) do
    notify.(:computing, %{query: query.text})

    timed(fn ->
      adapter_module = nlp_adapter(Keyword.get(opts, :mode, Application.get_env(:math_viz, :nlp_mode, :stub)))

      case adapter_module.to_symbol(query, opts) do
        {:ok, symbol} -> {:ok, symbol, symbol.source}
        {:error, reason} -> fallback_nlp(query, reason, opts)
      end
    end)
    |> expand_timing()
  end

  defp verify(symbol, opts, notify) do
    notify.(:verifying, %{symbol: symbol.expression})

    timed(fn ->
      verifier = Keyword.get(opts, :verifier, Application.fetch_env!(:math_viz, :verifier))
      verifier.verify(symbol, opts)
    end)
    |> case do
      {{:ok, proof}, duration_ms} -> {:ok, proof, duration_ms}
      {{:error, _} = error, _duration_ms} -> error
    end
  end

  defp render(symbol, proof, opts, notify) do
    notify.(:rendering, %{symbol: symbol.expression, proof: proof.state})

    timed(fn ->
      graph_builder = Keyword.get(opts, :graph_builder, Application.fetch_env!(:math_viz, :graph_builder))
      graph_builder.build(symbol, proof, opts)
    end)
    |> case do
      {{:ok, graph}, duration_ms} -> {:ok, graph, duration_ms}
      {{:error, _} = error, _duration_ms} -> error
    end
  end

  defp fallback_nlp(query, reason, opts) do
    mode = Keyword.get(opts, :mode, Application.get_env(:math_viz, :nlp_mode, :stub))

    if mode in [:dual, "dual", :nim, "nim"] do
      {:ok, symbol} = MathViz.Morphisms.NlpRouter.Stub.to_symbol(query, opts)
      {:ok, %{symbol | source: :stub, notes: ["Fell back after NIM error: #{inspect(reason)}" | symbol.notes]}, :stub}
    else
      {:error, reason}
    end
  end

  defp expand_timing({{:ok, symbol, adapter}, duration_ms}), do: {:ok, symbol, adapter, duration_ms}
  defp expand_timing({other, _duration_ms}), do: other

  defp nlp_adapter(:nim), do: MathViz.Morphisms.NlpRouter.Nim
  defp nlp_adapter("nim"), do: MathViz.Morphisms.NlpRouter.Nim
  defp nlp_adapter(:dual), do: MathViz.Morphisms.NlpRouter.Nim
  defp nlp_adapter("dual"), do: MathViz.Morphisms.NlpRouter.Nim
  defp nlp_adapter(_), do: MathViz.Morphisms.NlpRouter.Stub

  defp timed(fun) do
    started_at = System.monotonic_time()
    result = fun.()
    duration_ms = System.monotonic_time() - started_at |> System.convert_time_unit(:native, :millisecond)
    {result, duration_ms}
  end
end
