defmodule MathViz.Morphisms.NlpRouter.Nim do
  @moduledoc "NVIDIA NIM-backed OpenAI-compatible router for the N -> S morphism."

  @behaviour MathViz.Morphisms.NlpRouter

  alias MathViz.Core.{Query, Symbol}

  @system_prompt """
  You translate a natural-language math request into JSON for a symbolic visualizer.
  Return JSON only with keys:
  statement, expression, latex, graph_expression, notes.
  Rules:
  - expression: concise symbolic output, for example cos(x) or x^2 + 1
  - latex: valid KaTeX-ready LaTeX string for the main result
  - graph_expression: a Desmos-ready relation, usually y=<expression>
  - notes: array of short strings
  """

  @impl true
  def to_symbol(%Query{text: text}, opts) do
    nim_config = Application.fetch_env!(:math_viz, :nvidia_nim)
    api_key = nim_config[:api_key]

    if is_nil(api_key) or api_key == "" do
      {:error, :missing_nvidia_nim_api_key}
    else
      request =
        Req.new(
          base_url: nim_config[:base_url],
          auth: {:bearer, api_key},
          receive_timeout: nim_config[:timeout_ms],
          headers: [{"content-type", "application/json"}]
        )

      payload = %{
        model: nim_config[:model],
        temperature: Keyword.get(opts, :temperature, 0.2),
        response_format: %{type: "json_object"},
        messages: [
          %{role: "system", content: @system_prompt},
          %{role: "user", content: text}
        ]
      }

      case Req.post(request, url: "/chat/completions", json: payload) do
        {:ok, %{status: status, body: body}} when status in 200..299 ->
          with {:ok, symbol} <- response_to_symbol(body) do
            {:ok, %{symbol | source: :nim}}
          end

        {:ok, %{status: status, body: body}} ->
          {:error, {:nim_http_error, status, body}}

        {:error, reason} ->
          {:error, {:nim_request_failed, reason}}
      end
    end
  end

  defp response_to_symbol(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    content
    |> extract_json()
    |> Jason.decode()
    |> case do
      {:ok, payload} -> normalize_symbol(payload)
      {:error, reason} -> {:error, {:nim_invalid_json, reason}}
    end
  end

  defp response_to_symbol(body), do: {:error, {:nim_unexpected_response, body}}

  defp normalize_symbol(payload) do
    statement = Map.get(payload, "statement") || "NIM result"
    expression = Map.get(payload, "expression")
    latex = Map.get(payload, "latex")
    graph_expression = Map.get(payload, "graph_expression") || expression
    notes = List.wrap(Map.get(payload, "notes"))

    cond do
      blank?(expression) -> {:error, :nim_missing_expression}
      blank?(latex) -> {:error, :nim_missing_latex}
      blank?(graph_expression) -> {:error, :nim_missing_graph_expression}
      true ->
        {:ok,
         %Symbol{
           statement: statement,
           expression: expression,
           latex: latex,
           graph_expression: graph_expression,
           raw: payload,
           notes: Enum.map(notes, &to_string/1)
         }}
    end
  end

  defp extract_json(content) when is_binary(content) do
    case Regex.run(~r/\{.*\}/s, content) do
      [json] -> json
      _ -> content
    end
  end

  defp blank?(value), do: is_nil(value) or String.trim(to_string(value)) == ""
end
