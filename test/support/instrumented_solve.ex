defmodule MathViz.TestSupport.InstrumentedSolve do
  @moduledoc false

  alias MathViz.API.SolveRequest
  alias MathViz.Solve

  @spec run(map() | SolveRequest.t(), keyword()) ::
          {:ok, MathViz.API.SolveResponse.t()} | {:error, Ecto.Changeset.t() | term()}
  def run(%SolveRequest{} = request, opts) do
    do_run(SolveRequest.effective_query(request), request, opts)
  end

  def run(params, opts) when is_map(params) do
    do_run(extract_query(params), params, opts)
  end

  defp do_run("hang forever" = query, request_or_params, opts) do
    notify_test({:solve_started, query, self()})

    receive do
      :release -> Solve.run(request_or_params, opts)
    end
  end

  defp do_run(query, request_or_params, opts) do
    notify_test({:solve_started, query, self()})
    result = Solve.run(request_or_params, opts)
    notify_test({:solve_finished, query, result})
    result
  end

  defp extract_query(params) do
    Map.get(params, "query") || Map.get(params, :query) || ""
  end

  defp notify_test(message) do
    if pid = Application.get_env(:math_viz, :solve_test_pid) do
      send(pid, message)
    end

    :ok
  end
end
