defmodule MathViz.Core.Symbol do
  @moduledoc "Normalized symbolic state (S)."

  @enforce_keys [:statement, :expression, :latex, :graph_expression]
  defstruct [
    :statement,
    :expression,
    :latex,
    :graph_expression,
    source: :stub,
    raw: %{},
    notes: []
  ]

  @type t :: %__MODULE__{
          statement: String.t(),
          expression: String.t(),
          latex: String.t(),
          graph_expression: String.t(),
          source: atom(),
          raw: map(),
          notes: [String.t()]
        }
end
