defmodule MathViz.Contracts.AIResponse do
  @moduledoc "Validated AI boundary payload."

  @derive Jason.Encoder
  @enforce_keys [:reasoning_steps, :raw_latex, :sympy_executable, :desmos_expressions]
  defstruct [:reasoning_steps, :raw_latex, :sympy_executable, :desmos_expressions]

  @type t :: %__MODULE__{
          reasoning_steps: [String.t()],
          raw_latex: String.t(),
          sympy_executable: String.t(),
          desmos_expressions: [MathViz.Contracts.DesmosExpression.t()]
        }
end
