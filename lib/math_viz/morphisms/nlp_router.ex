defmodule MathViz.Morphisms.NlpRouter do
  @moduledoc "Behaviour for the N -> S morphism."

  alias MathViz.Core.{Query, Symbol}

  @callback to_symbol(Query.t(), keyword()) :: {:ok, Symbol.t()} | {:error, term()}
end
