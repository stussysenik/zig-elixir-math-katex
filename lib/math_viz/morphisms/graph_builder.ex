defmodule MathViz.Morphisms.GraphBuilder do
  @moduledoc "Behaviour for the S -> G morphism."

  alias MathViz.Core.{Graph, Proof, Symbol}

  @callback build(Symbol.t(), Proof.t(), keyword()) :: {:ok, Graph.t()} | {:error, term()}
end
