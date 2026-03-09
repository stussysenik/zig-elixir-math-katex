defmodule MathViz.Morphisms.NlpRouter.Stub do
  @moduledoc "Deterministic offline router for the first N -> S morphism."

  @behaviour MathViz.Morphisms.NlpRouter

  alias MathViz.Core.{Query, Symbol}

  @impl true
  def to_symbol(%Query{text: text}, _opts) do
    normalized = String.downcase(String.trim(text))

    symbol =
      cond do
        normalized == "" ->
          default_symbol()

        String.contains?(normalized, "derivative of sin") ->
          %Symbol{
            statement: "Derivative of sin(x)",
            expression: "cos(x)",
            latex: "\\cos(x)",
            graph_expression: "y=\\cos(x)",
            source: :stub,
            raw: %{pattern: "derivative_of_sin"},
            notes: ["Derived locally without external API access."]
          }

        String.contains?(normalized, "derivative of cos") ->
          %Symbol{
            statement: "Derivative of cos(x)",
            expression: "-sin(x)",
            latex: "-\\sin(x)",
            graph_expression: "y=-\\sin(x)",
            source: :stub,
            raw: %{pattern: "derivative_of_cos"},
            notes: ["Derived locally without external API access."]
          }

        String.contains?(normalized, "integral of x^2") ->
          %Symbol{
            statement: "Integral of x^2",
            expression: "x^3 / 3",
            latex: "\\frac{x^3}{3} + C",
            graph_expression: "y=x^3/3",
            source: :stub,
            raw: %{pattern: "integral_of_x_squared"},
            notes: ["Derived locally without external API access."]
          }

        explicit_expression?(text) ->
          build_expression_symbol(text)

        true ->
          default_symbol(text)
      end

    {:ok, symbol}
  end

  defp explicit_expression?(text) do
    String.contains?(text, "=") or
      Regex.match?(~r/\b(sin|cos|tan|exp|log)\b/i, text) or
      Regex.match?(~r/x\^?\d?/i, text)
  end

  defp build_expression_symbol(text) do
    expression =
      text
      |> String.trim()
      |> String.trim_leading("plot ")
      |> String.trim_leading("graph ")
      |> String.trim()

    graph_expression =
      if String.contains?(expression, "=") do
        expression
      else
        "y=#{expression}"
      end

    %Symbol{
      statement: "Parsed expression",
      expression: expression,
      latex: graph_expression_to_latex(graph_expression),
      graph_expression: graph_expression_to_latex(graph_expression),
      source: :stub,
      raw: %{pattern: "expression"},
      notes: ["Parsed directly from the raw query."]
    }
  end

  defp graph_expression_to_latex(expression) do
    expression
    |> String.replace("**", "^")
    |> String.replace("*", " ")
  end

  defp default_symbol(text \\ "Plot a parabola") do
    %Symbol{
      statement: if(text == "", do: "Plot a parabola", else: text),
      expression: "x^2",
      latex: "x^2",
      graph_expression: "y=x^2",
      source: :stub,
      raw: %{pattern: "default"},
      notes: ["Fell back to the built-in demo function y = x^2."]
    }
  end
end
