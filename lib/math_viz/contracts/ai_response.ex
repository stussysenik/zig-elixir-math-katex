defmodule MathViz.Contracts.AIResponse do
  @moduledoc "Validated AI boundary payload."

  @derive Jason.Encoder
  @enforce_keys [:mode, :reasoning_steps]
  defstruct mode: :computation,
            reasoning_steps: [],
            raw_latex: nil,
            sympy_executable: nil,
            desmos_expressions: [],
            chat_reply: nil

  @type mode :: :computation | :chat

  @type t :: %__MODULE__{
          mode: mode(),
          reasoning_steps: [String.t()],
          raw_latex: String.t() | nil,
          sympy_executable: String.t() | nil,
          desmos_expressions: [MathViz.Contracts.DesmosExpression.t()],
          chat_reply: String.t() | nil
        }
end
