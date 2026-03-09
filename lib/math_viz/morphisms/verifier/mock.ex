defmodule MathViz.Morphisms.Verifier.Mock do
  @moduledoc "Mock Lean-compatible verifier used for v1."

  @behaviour MathViz.Morphisms.Verifier

  alias MathViz.Core.{Proof, Symbol}

  @impl true
  def verify(%Symbol{} = symbol, opts) do
    delay_ms = Keyword.get(opts, :verify_delay_ms, Application.get_env(:math_viz, :verify_delay_ms, 1000))
    Process.sleep(delay_ms)

    verified? =
      symbol.expression
      |> String.downcase()
      |> String.contains?("reject")
      |> Kernel.not()

    proof =
      %Proof{
        verified: verified?,
        state: if(verified?, do: "Proof complete", else: "Verification rejected"),
        summary:
          if(verified?,
            do: "Mock verifier accepted the symbolic claim.",
            else: "Mock verifier rejected the claim, so rendering stays gated."
          ),
        duration_ms: delay_ms
      }

    {:ok, proof}
  end
end
