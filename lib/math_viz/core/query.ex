defmodule MathViz.Core.Query do
  @moduledoc "Natural-language query state (N)."

  @enforce_keys [:text]
  defstruct [:text, :id, metadata: %{}]

  @type t :: %__MODULE__{
          text: String.t(),
          id: String.t(),
          metadata: map()
        }

  @spec new(String.t(), map()) :: t()
  def new(text, metadata \\ %{}) when is_binary(text) do
    %__MODULE__{
      text: String.trim(text),
      id: Integer.to_string(System.unique_integer([:positive])),
      metadata: metadata
    }
  end
end
