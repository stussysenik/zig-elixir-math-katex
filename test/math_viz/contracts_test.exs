defmodule MathViz.ContractsTest do
  use ExUnit.Case, async: true

  alias MathViz.Contracts
  alias MathViz.Contracts.{AIResponse, DesmosExpression, SymPyResponse}

  test "parses a valid AI response payload" do
    payload = %{
      "mode" => "computation",
      "reasoning_steps" => ["Differentiate x squared.", "Graph the verified result."],
      "raw_latex" => "2 x",
      "sympy_executable" => "diff(x^2, x)",
      "desmos_expressions" => [%{"id" => "graph1", "latex" => "y=2*x"}]
    }

    assert {:ok,
            %AIResponse{
              mode: :computation,
              raw_latex: "2 x",
              sympy_executable: "diff(x^2, x)",
              desmos_expressions: [%DesmosExpression{id: "graph1", latex: "y=2*x"}]
            }} = Contracts.parse_ai_response(payload)
  end

  test "parses a valid chat AI response payload" do
    payload = %{
      "mode" => "chat",
      "reasoning_steps" => ["Recognize the prompt as a conceptual calculus question."],
      "chat_reply" => "An integral accumulates quantity over a range."
    }

    assert {:ok,
            %AIResponse{
              mode: :chat,
              chat_reply: "An integral accumulates quantity over a range."
            }} = Contracts.parse_ai_response(payload)
  end

  test "rejects malformed AI response payloads" do
    payload = %{
      "mode" => "computation",
      "reasoning_steps" => "not-a-list",
      "raw_latex" => "2 x",
      "sympy_executable" => "diff(x^2, x)",
      "desmos_expressions" => []
    }

    assert {:error, {:invalid_string_list_field, "reasoning_steps"}} =
             Contracts.parse_ai_response(payload)
  end

  test "parses a valid SymPy response payload" do
    payload = %{
      "request_id" => "123",
      "ok" => true,
      "result_string" => "2*x",
      "result_latex" => "2 x",
      "normalized_expression" => "2*x",
      "error" => nil
    }

    assert {:ok,
            %SymPyResponse{
              request_id: "123",
              ok: true,
              result_string: "2*x",
              result_latex: "2 x"
            }} = Contracts.parse_sympy_response(payload)
  end
end
