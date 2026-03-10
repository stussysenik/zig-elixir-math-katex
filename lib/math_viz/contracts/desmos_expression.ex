defmodule MathViz.Contracts.DesmosExpression do
  @moduledoc "Single Desmos expression payload."

  @derive Jason.Encoder
  @enforce_keys [:id, :latex]
  defstruct [:id, :latex]

  @type t :: %__MODULE__{
          id: String.t(),
          latex: String.t()
        }
end
