defmodule MathViz.Morphisms.GraphBuilder.Default do
  @moduledoc "Default graph builder for Desmos and GeoGebra payloads."

  @behaviour MathViz.Morphisms.GraphBuilder

  alias MathViz.Core.{Graph, Proof, Symbol}

  @impl true
  def build(%Symbol{} = symbol, %Proof{verified: true}, _opts) do
    desmos_expression = normalize_relation(symbol.graph_expression)
    geogebra_command = geogebra_command(desmos_expression)

    {:ok,
     %Graph{
       latex_block: symbol.latex,
       desmos: %{
         expression: desmos_expression,
         viewport: %{xmin: -10, xmax: 10, ymin: -10, ymax: 10}
       },
       geogebra: %{
         command: geogebra_command,
         expression: desmos_expression
       }
     }}
  end

  def build(_symbol, %Proof{verified: false}, _opts), do: {:error, :not_verified}

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
