defmodule MathViz.Morphisms.GraphBuilder.Default do
  @moduledoc "Default graph builder for Desmos and GeoGebra payloads."

  @behaviour MathViz.Morphisms.GraphBuilder

  alias MathViz.Contracts
  alias MathViz.Contracts.DesmosExpression
  alias MathViz.Core.{Graph, Proof, Symbol}

  @impl true
  def build(%Symbol{} = symbol, %Proof{verified: true}, _opts) do
    expressions = verified_desmos_expressions(symbol)
    desmos_payload = Contracts.to_desmos_payload(expressions)

    geogebra_expression =
      expressions |> List.first() |> Map.get(:latex, normalize_relation(symbol.graph_expression))

    geogebra_command = geogebra_command(geogebra_expression)

    {:ok,
     %Graph{
       latex_block: symbol.latex,
       desmos: desmos_payload,
       geogebra: %{
         command: geogebra_command,
         expression: geogebra_expression
       }
     }}
  end

  def build(_symbol, %Proof{verified: false}, _opts), do: {:error, :not_verified}

  defp verified_desmos_expressions(%Symbol{} = symbol) do
    symbol.raw
    |> Map.get(:verified_desmos_expressions, [])
    |> case do
      expressions when is_list(expressions) and expressions != [] ->
        Enum.map(expressions, &to_desmos_expression/1)

      _ ->
        [%DesmosExpression{id: "graph1", latex: normalize_relation(symbol.graph_expression)}]
    end
  end

  defp to_desmos_expression(%DesmosExpression{} = expression), do: expression

  defp to_desmos_expression(%{id: id, latex: latex}) when is_binary(id) and is_binary(latex) do
    %DesmosExpression{id: id, latex: latex}
  end

  defp normalize_relation(expression) do
    expression =
      expression
      |> String.trim()
      |> String.replace("**", "^")

    if String.contains?(expression, "="), do: expression, else: "y=#{expression}"
  end

  defp geogebra_command(expression) do
    expression
    |> String.trim_leading("y=")
    |> then(&"f(x)=#{&1}")
  end
end
