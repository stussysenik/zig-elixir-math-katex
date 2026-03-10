defmodule MathViz.Pipeline do
  @moduledoc "CLI-first orchestration for the verified-first math pipeline."

  alias MathViz.Contracts
  alias MathViz.Core.{Graph, Query}
  alias MathViz.Engines.SymPyWorker
  alias MathViz.Result

  @type notify_fun :: (atom(), map() -> any())

  @spec run(String.t(), keyword()) :: {:ok, Result.t()} | {:error, term()}
  def run(query_text, opts \\ []) when is_binary(query_text) do
    notify = Keyword.get(opts, :notify, fn _, _ -> :ok end)
    query = Query.new(query_text, Keyword.get(opts, :query_metadata, %{}))

    with {:ok, ai_response, adapter, nlp_ms} <-
           trace_call(
             opts,
             "pipeline.run",
             "pipeline.route",
             %{
               from_kind: "function",
               to_kind: "function"
             },
             fn -> route(query, opts, notify) end
           ) do
      case ai_response.mode do
        :chat ->
          result =
            %Result{
              query: query,
              mode: :chat,
              chat_reply: ai_response.chat_reply,
              chat_steps: ai_response.reasoning_steps,
              graph: %Graph{},
              is_verified: false,
              status: :complete,
              timings: %{nlp_ms: nlp_ms, sympy_ms: 0, verify_ms: 0, graph_ms: 0},
              adapter: adapter
            }

          notify.(:complete, %{result: result})
          {:ok, result}

        :computation ->
          run_computation(query, ai_response, adapter, nlp_ms, opts, notify)
      end
    else
      {:error, _} = error ->
        error
    end
  end

  defp run_computation(query, ai_response, adapter, nlp_ms, opts, notify) do
    with {:ok, sympy_response, sympy_ms} <- execute_sympy(ai_response, opts),
         {:ok, symbol} <- build_symbol(query, ai_response, sympy_response, adapter),
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
                mode: :computation,
                status: :rendering,
                timings: %{
                  nlp_ms: nlp_ms,
                  sympy_ms: sympy_ms,
                  verify_ms: verify_ms,
                  graph_ms: graph_ms
                },
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
              mode: :computation,
              status: :error,
              timings: %{nlp_ms: nlp_ms, sympy_ms: sympy_ms, verify_ms: verify_ms, graph_ms: 0},
              adapter: adapter,
              error: :verification_failed
            }

          notify.(:complete, %{result: result})
          {:ok, result}
      end
    end
  end

  defp route(query, opts, notify) do
    notify.(:computing, %{query: query.text})

    adapter_module =
      nlp_adapter(Keyword.get(opts, :mode, Application.get_env(:math_viz, :nlp_mode, :stub)))

    adapter = adapter_name(adapter_module)

    timed(fn ->
      trace_call(
        opts,
        "pipeline.route",
        "nlp_router.#{adapter}",
        %{from_kind: "function", to_kind: "tool"},
        fn ->
          case adapter_module.to_contract(query, opts) do
            {:ok, contract} -> {:ok, contract, adapter}
            {:error, reason} -> fallback_nlp(query, reason, opts)
          end
        end
      )
    end)
    |> expand_timing()
  end

  defp execute_sympy(ai_response, opts) do
    timed(fn ->
      trace_call(
        opts,
        "pipeline.run_computation",
        "sympy_worker.execute",
        %{from_kind: "function", to_kind: "tool"},
        fn -> SymPyWorker.execute(ai_response.sympy_executable, opts) end
      )
    end)
    |> case do
      {{:ok, response}, duration_ms} -> {:ok, response, duration_ms}
      {{:error, _} = error, _duration_ms} -> error
    end
  end

  defp build_symbol(query, ai_response, sympy_response, adapter) do
    case Contracts.to_symbol(query, ai_response, sympy_response) do
      {:ok, symbol} -> {:ok, %{symbol | source: adapter}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify(symbol, opts, notify) do
    notify.(:verifying, %{symbol: symbol.expression, raw_latex: symbol.latex})

    verifier = Keyword.get(opts, :verifier, Application.fetch_env!(:math_viz, :verifier))

    timed(fn ->
      trace_call(
        opts,
        "pipeline.run_computation",
        "verifier.#{inspect(verifier)}",
        %{from_kind: "function", to_kind: "tool", to_label: inspect(verifier)},
        fn -> verifier.verify(symbol, opts) end
      )
    end)
    |> case do
      {{:ok, proof}, duration_ms} -> {:ok, proof, duration_ms}
      {{:error, _} = error, _duration_ms} -> error
    end
  end

  defp render(symbol, proof, opts, notify) do
    notify.(:rendering, %{symbol: symbol.expression, proof: proof.state})

    graph_builder =
      Keyword.get(opts, :graph_builder, Application.fetch_env!(:math_viz, :graph_builder))

    timed(fn ->
      trace_call(
        opts,
        "pipeline.run_computation",
        "graph_builder.#{inspect(graph_builder)}",
        %{from_kind: "function", to_kind: "tool", to_label: inspect(graph_builder)},
        fn -> graph_builder.build(symbol, proof, opts) end
      )
    end)
    |> case do
      {{:ok, graph}, duration_ms} -> {:ok, graph, duration_ms}
      {{:error, _} = error, _duration_ms} -> error
    end
  end

  defp fallback_nlp(query, reason, opts) do
    mode = Keyword.get(opts, :mode, Application.get_env(:math_viz, :nlp_mode, :stub))

    fallback_mode =
      Keyword.get(
        opts,
        :nim_fallback_mode,
        Application.get_env(:math_viz, :nim_fallback_mode, :fallback)
      )

    if mode in [:dual, "dual", :nim, "nim"] and fallback_mode != :strict do
      {:ok, contract} = MathViz.Morphisms.NlpRouter.Stub.to_contract(query, opts)

      fallback_contract = %{
        contract
        | reasoning_steps: [
            "Fell back after NIM error: #{inspect(reason)}" | contract.reasoning_steps
          ]
      }

      {:ok, fallback_contract, :stub}
    else
      {:error, reason}
    end
  end

  defp expand_timing({{:ok, contract, adapter}, duration_ms}),
    do: {:ok, contract, adapter, duration_ms}

  defp expand_timing({other, _duration_ms}), do: other

  defp adapter_name(MathViz.Morphisms.NlpRouter.Nim), do: :nim
  defp adapter_name(MathViz.Morphisms.NlpRouter.Stub), do: :stub

  defp nlp_adapter(:nim), do: MathViz.Morphisms.NlpRouter.Nim
  defp nlp_adapter("nim"), do: MathViz.Morphisms.NlpRouter.Nim
  defp nlp_adapter(:dual), do: MathViz.Morphisms.NlpRouter.Nim
  defp nlp_adapter("dual"), do: MathViz.Morphisms.NlpRouter.Nim
  defp nlp_adapter(_), do: MathViz.Morphisms.NlpRouter.Stub

  defp timed(fun) do
    started_at = System.monotonic_time()
    result = fun.()

    duration_ms =
      (System.monotonic_time() - started_at) |> System.convert_time_unit(:native, :millisecond)

    {result, duration_ms}
  end

  defp trace_call(opts, from, to, metadata, fun) do
    started_at = System.monotonic_time()
    result = fun.()

    duration_ms =
      System.monotonic_time()
      |> Kernel.-(started_at)
      |> System.convert_time_unit(:native, :millisecond)

    MathViz.QA.CallGraph.record_call(Keyword.get(opts, :call_graph_pid), from, to, %{
      from_kind: Map.get(metadata, :from_kind, "function"),
      to_kind: Map.get(metadata, :to_kind, "function"),
      from_label: Map.get(metadata, :from_label, from),
      to_label: Map.get(metadata, :to_label, to),
      kind: Map.get(metadata, :kind, "calls"),
      status: call_status(result),
      duration_ms: duration_ms,
      metadata: Map.get(metadata, :metadata, %{})
    })

    result
  end

  defp call_status({:ok, _result}), do: "passed"
  defp call_status({:error, _reason}), do: "failed"
  defp call_status(_result), do: "passed"
end
