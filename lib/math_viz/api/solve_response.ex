defmodule MathViz.API.SolveResponse do
  @moduledoc "Headless response payload shared by the API and the LiveView."

  use Ecto.Schema

  import Ecto.Changeset

  alias MathViz.API.SolveRequest
  alias MathViz.Result

  @primary_key false
  embedded_schema do
    field(:request_id, :string)
    field(:mode, :string)
    field(:status, :string)
    field(:adapter, :string)
    field(:verified, :boolean)
    field(:error, :string)
    field(:chat_reply, :string)
    field(:chat_steps, {:array, :string}, default: [])
    field(:request, :map, default: %{})
    field(:symbol, :map, default: %{})
    field(:proof, :map, default: %{})
    field(:graph, :map, default: %{})
    field(:timings, :map, default: %{})
  end

  @type t :: %__MODULE__{
          request_id: String.t() | nil,
          mode: String.t() | nil,
          status: String.t() | nil,
          adapter: String.t() | nil,
          verified: boolean(),
          error: String.t() | nil,
          chat_reply: String.t() | nil,
          chat_steps: [String.t()],
          request: map(),
          symbol: map(),
          proof: map(),
          graph: map(),
          timings: map()
        }

  @spec new(SolveRequest.t(), Result.t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def new(%SolveRequest{} = request, %Result{} = result) do
    attrs = %{
      request_id: result.query && result.query.id,
      mode: to_string(result.mode),
      status: to_string(result.status),
      adapter: to_string(result.adapter),
      verified: result.is_verified,
      error: format_error(result.error),
      chat_reply: result.chat_reply,
      chat_steps: result.chat_steps,
      request: %{
        query: request.query,
        effective_query: SolveRequest.effective_query(request),
        has_image: SolveRequest.has_vision?(request),
        image:
          case request.vision do
            nil ->
              nil

            vision ->
              %{
                filename: vision.filename,
                mime: vision.mime,
                size: vision.size
              }
          end
      },
      symbol:
        if(result.symbol,
          do: %{
            statement:
              if(result.symbol.statement in [nil, ""],
                do: SolveRequest.effective_query(request),
                else: result.symbol.statement
              ),
            expression: result.symbol.expression,
            latex: result.symbol.latex,
            notes: result.symbol.notes
          },
          else: %{}
        ),
      proof:
        if(result.proof,
          do: %{
            verified: result.proof.verified,
            state: result.proof.state,
            summary: result.proof.summary
          },
          else: %{}
        ),
      graph: %{
        desmos: result.graph.desmos,
        geogebra: result.graph.geogebra,
        latex_block: result.graph.latex_block
      },
      timings: result.timings
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = response) do
    %{
      request_id: response.request_id,
      mode: response.mode,
      status: response.status,
      adapter: response.adapter,
      verified: response.verified,
      error: response.error,
      chat_reply: response.chat_reply,
      chat_steps: response.chat_steps,
      request: response.request,
      symbol: response.symbol,
      proof: response.proof,
      graph: response.graph,
      timings: response.timings
    }
  end

  defp changeset(response, attrs) do
    response
    |> cast(attrs, [
      :request_id,
      :mode,
      :status,
      :adapter,
      :verified,
      :error,
      :chat_reply,
      :chat_steps,
      :request,
      :symbol,
      :proof,
      :graph,
      :timings
    ])
    |> validate_required([
      :status,
      :adapter,
      :verified,
      :mode,
      :request,
      :symbol,
      :proof,
      :graph,
      :timings
    ])
  end

  defp format_error(nil), do: nil

  defp format_error(:verification_failed),
    do: "Verification failed, so graph rendering remains gated."

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
