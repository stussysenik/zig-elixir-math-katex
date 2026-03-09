defmodule MathViz.Morphisms.Verifier do
  @moduledoc "Behaviour for the S -> L morphism."

  alias MathViz.Core.{Proof, Symbol}

  @callback verify(Symbol.t(), keyword()) :: {:ok, Proof.t()} | {:error, term()}
end
