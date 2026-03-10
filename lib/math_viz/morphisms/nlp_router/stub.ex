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

        explicit_expression?(text) ->
          build_expression_contract(text)

        true ->
          default_contract(text)
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

  defp maybe_annotate_vision(%AIResponse{} = contract, false), do: contract

  defp maybe_annotate_vision(%AIResponse{} = contract, true) do
    %{contract | reasoning_steps: ["Vision input attached." | contract.reasoning_steps]}
  end
end
