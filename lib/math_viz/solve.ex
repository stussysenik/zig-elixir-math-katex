defmodule MathViz.Solve do
  @moduledoc "Shared headless solve service used by the API, LiveView, and CLI."

  alias MathViz.API.{SolveRequest, SolveResponse}
  alias MathViz.Pipeline

  def run(request_or_params, opts \\ [])

  @spec run(map() | SolveRequest.t(), keyword()) ::
          {:ok, SolveResponse.t()} | {:error, Ecto.Changeset.t() | term()}
  def run(%SolveRequest{} = request, opts) do
    pipeline_opts =
      opts
      |> Keyword.put(:query_metadata, SolveRequest.query_metadata(request))
      |> maybe_put_vision(request)

    with {:ok, result} <- Pipeline.run(request.query, pipeline_opts),
         {:ok, response} <- SolveResponse.new(request, result) do
      {:ok, response}
    end
  end

  def run(params, opts) when is_map(params) do
    with {:ok, request} <- SolveRequest.new(params) do
      run(request, opts)
    end
  end

  defp maybe_put_vision(opts, %SolveRequest{vision: nil}), do: Keyword.delete(opts, :vision)

  defp maybe_put_vision(opts, %SolveRequest{vision: vision}) do
    Keyword.put(opts, :vision, %{
      bytes: vision.content,
      mime: vision.mime,
      filename: vision.filename,
      size: vision.size
    })
  end
end
