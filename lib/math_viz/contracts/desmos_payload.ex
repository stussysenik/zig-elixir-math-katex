defmodule MathViz.Contracts.DesmosPayload do
  @moduledoc "Graph payload pushed from LiveView to the Desmos hook."

  @derive Jason.Encoder
  defstruct expressions: [], viewport: %{xmin: -10, xmax: 10, ymin: -10, ymax: 10}

  @type t :: %__MODULE__{
          expressions: [MathViz.Contracts.DesmosExpression.t()],
          viewport: map()
        }
end
