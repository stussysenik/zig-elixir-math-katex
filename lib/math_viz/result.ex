defmodule MathViz.Result do
  @moduledoc "Aggregate pipeline result shared by CLI and LiveView."

  alias MathViz.Core.{Graph, Proof, Query, Symbol}

  defstruct query: nil,
            symbol: nil,
            proof: nil,
            graph: %Graph{},
            is_verified: false,
            mode: :computation,
            chat_reply: nil,
            chat_steps: [],
            status: :idle,
            timings: %{},
            adapter: :stub,
            error: nil

  @type t :: %__MODULE__{
          query: Query.t() | nil,
          symbol: Symbol.t() | nil,
          proof: Proof.t() | nil,
          graph: Graph.t(),
          is_verified: boolean(),
          mode: :computation | :chat,
          chat_reply: String.t() | nil,
          chat_steps: [String.t()],
          status: atom(),
          timings: map(),
          adapter: atom(),
          error: term()
        }
end
