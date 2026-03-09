defmodule MathViz.Core.Proof do
  @moduledoc "Formal proof state (L)."

  @enforce_keys [:verified, :state]
  defstruct [:verified, :state, summary: nil, duration_ms: nil]

  @type t :: %__MODULE__{
          verified: boolean(),
          state: String.t(),
          summary: String.t() | nil,
          duration_ms: non_neg_integer() | nil
        }
end
