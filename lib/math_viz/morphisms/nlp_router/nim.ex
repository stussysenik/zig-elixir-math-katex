defmodule MathViz.Morphisms.NlpRouter.Nim do
  @moduledoc "NVIDIA NIM-backed OpenAI-compatible router for the N -> S morphism."

  @behaviour MathViz.Morphisms.NlpRouter

  alias MathViz.Contracts
  alias MathViz.Contracts.AIResponse
  alias MathViz.Core.Query

  @system_prompt """
  You translate a natural-language math request into a strict JSON object for a verified-first symbolic pipeline.
  Return JSON only. No markdown. No prose outside the JSON object.
  Rules:
  - If an image is present, transcribe the visible mathematics before choosing the symbolic form.
  - If the image is ambiguous, say so in reasoning_steps and choose the most likely expression conservatively.
  - reasoning_steps: 1-4 short strings that describe the math transformation.
  - raw_latex: KaTeX-ready LaTeX for the intended result.
  - sympy_executable: a single SymPy-safe expression using diff, integrate, simplify, expand, factor, sin, cos, tan, exp, log, sqrt, x, y, or z.
  - desmos_expressions: at least one object with id and latex. Use y=<expression> for graphable results.
  """

  @impl true
  def to_contract(%Query{text: text}, opts) do
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
        temperature: Keyword.get(opts, :temperature, 0.0),
        response_format: %{
          type: "json_schema",
          json_schema: %{
            name: "math_viz_ai_response",
            strict: true,
            schema: Contracts.ai_response_schema()
          }
        },
        messages: [
          %{role: "system", content: @system_prompt},
          %{role: "user", content: user_content(text, Keyword.get(opts, :vision))}
        ]
      }

      case post_completion(request, payload) do
        {:ok, %{status: status, body: body}} when status in 200..299 ->
          response_to_contract(body)

        {:ok, %{status: status, body: body}} ->
          {:error, {:nim_http_error, status, body}}

        {:error, reason} ->
          {:error, {:nim_request_failed, reason}}
      end
    end
  end

  @spec post_completion(Req.Request.t(), map()) :: {:ok, Req.Response.t()} | {:error, term()}
  defp post_completion(request, payload) do
    case Req.post(request, url: "/chat/completions", json: payload) do
      {:ok, %{status: status}} = success when status in 200..299 ->
        success

      {:ok, %{status: status}} when status in 400..499 ->
        fallback_payload = Map.put(payload, :response_format, %{type: "json_object"})
        Req.post(request, url: "/chat/completions", json: fallback_payload)

      other ->
        other
    end
  end

  @spec response_to_contract(map()) :: {:ok, AIResponse.t()} | {:error, term()}
  defp response_to_contract(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    content
    |> extract_content()
    |> extract_json()
    |> Jason.decode()
    |> case do
      {:ok, payload} -> Contracts.parse_ai_response(payload)
      {:error, reason} -> {:error, {:nim_invalid_json, reason}}
    end
  end

  defp response_to_contract(body), do: {:error, {:nim_unexpected_response, body}}

  defp extract_content(content) when is_binary(content), do: content

  defp extract_content(content) when is_list(content) do
    content
    |> Enum.map(fn
      %{"text" => text} -> text
      text when is_binary(text) -> text
      _ -> ""
    end)
    |> Enum.join("\n")
  end

  defp extract_content(_content), do: ""

  defp extract_json(content) when is_binary(content) do
    case Regex.run(~r/\{.*\}/s, content) do
      [json] -> json
      _ -> content
    end
  end

  defp user_content(text, nil), do: String.trim(text)

  defp user_content(text, %{bytes: bytes, mime: mime})
       when is_binary(bytes) and is_binary(mime) do
    [
      %{
        type: "text",
        text: build_vision_prompt(text)
      },
      %{
        type: "image_url",
        image_url: %{
          url: "data:#{mime};base64,#{Base.encode64(bytes)}",
          detail: "auto"
        }
      }
    ]
  end

  defp user_content(text, _vision), do: String.trim(text)

  defp build_vision_prompt(text) do
    trimmed = String.trim(text)

    if trimmed == "" do
      "Use the uploaded image as the primary source. Extract the math problem and return the strict JSON contract."
    else
      """
      Use the text request and the uploaded image together.
      Text request: #{trimmed}
      First transcribe the visible mathematics from the image, then return the strict JSON contract.
      """
      |> String.trim()
    end
  end
end
