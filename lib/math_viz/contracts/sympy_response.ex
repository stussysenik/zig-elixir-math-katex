defmodule MathViz.Contracts.SymPyResponse do
  @moduledoc "JSON response returned by the Python SymPy runner."

  @derive Jason.Encoder
  @enforce_keys [:request_id, :ok]
  defstruct [:request_id, :ok, :result_string, :result_latex, :normalized_expression, :error]

  @type t :: %__MODULE__{
          request_id: String.t(),
          ok: boolean(),
          result_string: String.t() | nil,
          result_latex: String.t() | nil,
          normalized_expression: String.t() | nil,
          error: String.t() | nil
        }
end
