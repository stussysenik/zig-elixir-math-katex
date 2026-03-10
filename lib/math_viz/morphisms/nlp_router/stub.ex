defmodule MathViz.Morphisms.NlpRouter.Stub do
  @moduledoc "Deterministic offline router for the first N -> S morphism."

  @behaviour MathViz.Morphisms.NlpRouter

  alias MathViz.Contracts.{AIResponse, DesmosExpression}
  alias MathViz.Core.Query

  @impl true
  def to_contract(%Query{text: text}, opts) do
    normalized = String.downcase(String.trim(text))
    vision? = match?(%{bytes: bytes} when is_binary(bytes), Keyword.get(opts, :vision))

    contract =
      cond do
        normalized == "" and vision? ->
          image_contract()

        normalized == "" ->
          default_contract()

        String.contains?(normalized, "derivative of sin") ->
          calculus_contract(
            "differentiate sine",
            "\\cos(x)",
            "diff(sin(x), x)",
            "y=\\cos(x)"
          )

        String.contains?(normalized, "derivative of cos") ->
          calculus_contract(
            "differentiate cosine",
            "-\\sin(x)",
            "diff(cos(x), x)",
            "y=-\\sin(x)"
          )

        String.contains?(normalized, "derivative of x^2") ->
          calculus_contract(
            "differentiate x squared",
            "2 x",
            "diff(x^2, x)",
            "y=2*x"
          )

        String.contains?(normalized, "integral of x^2") ->
          calculus_contract(
            "integrate x squared",
            "\\frac{x^3}{3}",
            "integrate(x^2, x)",
            "y=x^3/3"
          )

        theory_prompt?(normalized) ->
          theory_contract(normalized, text)

        explicit_expression?(text) ->
          build_expression_contract(text)

        true ->
          unsupported_prompt_contract(text)
      end

    {:ok, maybe_annotate_vision(contract, vision?)}
  end

  defp explicit_expression?(text) do
    String.contains?(text, "=") or
      Regex.match?(~r/\b(sin|cos|tan|exp|log)\b/i, text) or
      Regex.match?(~r/x\^?\d?/i, text)
  end

  defp build_expression_contract(text) do
    expression =
      text
      |> String.trim()
      |> String.trim_leading("plot ")
      |> String.trim_leading("graph ")
      |> String.trim()

    graph_expression = relation_from_expression(expression)
    sympy_executable = expression_for_sympy(expression)

    %AIResponse{
      mode: :computation,
      reasoning_steps: [
        "Parse the prompt directly into a local symbolic expression.",
        "Execute the expression through the SymPy boundary."
      ],
      raw_latex: graph_expression_to_latex(graph_expression),
      sympy_executable: sympy_executable,
      desmos_expressions: [
        %DesmosExpression{id: "graph1", latex: graph_expression_to_latex(graph_expression)}
      ]
    }
  end

  defp graph_expression_to_latex(expression) do
    expression
    |> String.replace("**", "^")
    |> String.replace("*", " ")
  end

  defp relation_from_expression(expression) do
    if String.contains?(expression, "="), do: expression, else: "y=#{expression}"
  end

  defp expression_for_sympy(expression) do
    if String.contains?(expression, "=") do
      expression
      |> String.split("=", parts: 2)
      |> List.last()
      |> String.trim()
    else
      expression
    end
  end

  defp calculus_contract(step, raw_latex, sympy_executable, graph_latex) do
    %AIResponse{
      mode: :computation,
      reasoning_steps: [
        "Interpret the request as a calculus transformation.",
        "Use SymPy to #{step}.",
        "Return the verified expression to the graph layer."
      ],
      raw_latex: raw_latex,
      sympy_executable: sympy_executable,
      desmos_expressions: [%DesmosExpression{id: "graph1", latex: graph_latex}]
    }
  end

  defp default_contract(text \\ "Plot a parabola") do
    %AIResponse{
      mode: :computation,
      reasoning_steps: [
        "Fall back to the built-in demo function.",
        "Render the verified parabola after execution."
      ],
      raw_latex: "x^2",
      sympy_executable: "x^2",
      desmos_expressions: [%DesmosExpression{id: "graph1", latex: "y=x^2"}]
    }
    |> maybe_annotate_default(text)
  end

  defp image_contract do
    %AIResponse{
      mode: :computation,
      reasoning_steps: [
        "Vision input received in stub mode, so use a deterministic fallback.",
        "Render a verified parabola to keep the upload loop testable offline."
      ],
      raw_latex: "x^2",
      sympy_executable: "x^2",
      desmos_expressions: [%DesmosExpression{id: "graph1", latex: "y=x^2"}]
    }
  end

  defp maybe_annotate_default(%AIResponse{} = contract, ""), do: contract

  defp maybe_annotate_default(%AIResponse{} = contract, text) do
    %{contract | reasoning_steps: ["Prompt: #{String.trim(text)}" | contract.reasoning_steps]}
  end

  defp theory_prompt?(normalized) do
    concept_keywords = ["integral", "derivative", "limit", "matrix", "vector", "theorem"]

    Enum.any?(concept_keywords, &String.contains?(normalized, &1)) and
      (String.ends_with?(normalized, "?") or
         String.starts_with?(normalized, "what is") or
         String.starts_with?(normalized, "what's") or
         String.starts_with?(normalized, "explain") or
         String.starts_with?(normalized, "define") or
         String.starts_with?(normalized, "why"))
  end

  defp theory_contract(normalized, text) do
    {steps, reply} =
      cond do
        String.contains?(normalized, "integral") ->
          {["Recognize the prompt as a conceptual calculus question."], integral_reply()}

        String.contains?(normalized, "derivative") ->
          {["Recognize the prompt as a conceptual calculus question."], derivative_reply()}

        true ->
          {["Recognize the prompt as a conceptual math question."], generic_reply(text)}
      end

    %AIResponse{
      mode: :chat,
      reasoning_steps: steps,
      chat_reply: reply
    }
  end

  defp unsupported_prompt_contract(text) do
    trimmed = String.trim(text)

    %AIResponse{
      mode: :chat,
      reasoning_steps: [
        "The offline stub could not map the prompt to a safe symbolic expression."
      ],
      chat_reply:
        "I could not safely turn #{inspect(trimmed)} into a verified symbolic computation in stub mode. Rephrase it as an explicit expression, or enable the NIM router for broader natural-language coverage."
    }
  end

  defp integral_reply do
    "An integral accumulates quantity over a range. You can read it as adding infinitely small pieces together. In calculus, a definite integral gives total accumulated value, such as area under a curve, while an indefinite integral gives a family of antiderivatives."
  end

  defp derivative_reply do
    "A derivative measures how fast a quantity changes with respect to another quantity. Geometrically, it is the slope of the tangent line to a curve at a point. In applications, it captures rates of change like velocity, growth, or sensitivity."
  end

  defp generic_reply(text) do
    "I read #{inspect(String.trim(text))} as a theory question, so I am answering directly instead of forcing it through the symbolic pipeline."
  end

  defp maybe_annotate_vision(%AIResponse{} = contract, false), do: contract

  defp maybe_annotate_vision(%AIResponse{} = contract, true) do
    %{contract | reasoning_steps: ["Vision input attached." | contract.reasoning_steps]}
  end
end
