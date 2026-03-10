defmodule MathViz.Contracts.SymPyRequest do
  @moduledoc "JSON request sent to the Python SymPy runner."

  @derive Jason.Encoder
  @enforce_keys [:request_id, :sympy_executable]
  defstruct [:request_id, :sympy_executable]

  @type t :: %__MODULE__{
          request_id: String.t(),
          sympy_executable: String.t()
        }
end
