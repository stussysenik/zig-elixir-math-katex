defmodule MathViz.Morphisms.NlpRouter do
  @moduledoc "Behaviour for the N -> S morphism."

  alias MathViz.Contracts.AIResponse
  alias MathViz.Core.Query

  @callback to_contract(Query.t(), keyword()) :: {:ok, AIResponse.t()} | {:error, term()}
end
