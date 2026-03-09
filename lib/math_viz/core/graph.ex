defmodule MathViz.Core.Graph do
  @moduledoc "Renderable graph state (G)."

  defstruct desmos: %{}, geogebra: %{}, latex_block: nil

  @type t :: %__MODULE__{
          desmos: map(),
          geogebra: map(),
          latex_block: String.t() | nil
        }
end
