defmodule MathViz.Contracts do
  @moduledoc "Boundary contracts for AI responses, SymPy I/O, and JS graph payloads."

  alias MathViz.Contracts.{
    AIResponse,
    DesmosExpression,
    DesmosPayload,
    SymPyRequest,
    SymPyResponse
  }

  alias MathViz.Core.{Query, Symbol}

  @default_viewport %{xmin: -10, xmax: 10, ymin: -10, ymax: 10}

  @ai_schema %{
    type: "object",
    properties: %{
      mode: %{type: "string", enum: ["computation", "chat"]},
      reasoning_steps: %{type: "array", items: %{type: "string"}},
      raw_latex: %{type: "string"},
      sympy_executable: %{type: "string"},
      chat_reply: %{type: "string"},
      desmos_expressions: %{
        type: "array",
        items: %{
          type: "object",
          properties: %{
            id: %{type: "string"},
            latex: %{type: "string"}
          },
          required: ["id", "latex"],
          additionalProperties: false
        }
      }
    },
    required: ["mode", "reasoning_steps"],
    oneOf: [
      %{
        properties: %{mode: %{enum: ["computation"]}},
        required: ["raw_latex", "sympy_executable", "desmos_expressions"]
      },
      %{
        properties: %{mode: %{enum: ["chat"]}},
        required: ["chat_reply"]
      }
    ],
    additionalProperties: false
  }

  @spec ai_response_schema() :: map()
  def ai_response_schema, do: @ai_schema

  @spec parse_ai_response(map()) :: {:ok, AIResponse.t()} | {:error, term()}
  def parse_ai_response(payload) when is_map(payload) do
    with {:ok, mode} <- fetch_ai_response_mode(payload),
         {:ok, reasoning_steps} <- fetch_string_list(payload, "reasoning_steps") do
      case mode do
        :computation ->
          with {:ok, raw_latex} <- fetch_string(payload, "raw_latex"),
               {:ok, sympy_executable} <- fetch_string(payload, "sympy_executable"),
               {:ok, desmos_expressions} <- fetch_desmos_expressions(payload) do
            {:ok,
             %AIResponse{
               mode: :computation,
               reasoning_steps: reasoning_steps,
               raw_latex: raw_latex,
               sympy_executable: sympy_executable,
               desmos_expressions: desmos_expressions
             }}
          end

        :chat ->
          with {:ok, chat_reply} <- fetch_string(payload, "chat_reply") do
            {:ok,
             %AIResponse{
               mode: :chat,
               reasoning_steps: reasoning_steps,
               chat_reply: chat_reply
             }}
          end
      end
    end
  end

  def parse_ai_response(_payload), do: {:error, :invalid_ai_response}

  @spec new_sympy_request(String.t(), String.t()) :: SymPyRequest.t()
  def new_sympy_request(request_id, sympy_executable) do
    %SymPyRequest{request_id: request_id, sympy_executable: sympy_executable}
  end

  @spec parse_sympy_response(map()) :: {:ok, SymPyResponse.t()} | {:error, term()}
  def parse_sympy_response(payload) when is_map(payload) do
    with {:ok, request_id} <- fetch_string(payload, "request_id"),
         {:ok, ok?} <- fetch_boolean(payload, "ok"),
         {:ok, result_string} <- fetch_optional_string(payload, "result_string"),
         {:ok, result_latex} <- fetch_optional_string(payload, "result_latex"),
         {:ok, normalized_expression} <- fetch_optional_string(payload, "normalized_expression"),
         {:ok, error} <- fetch_optional_string(payload, "error") do
      {:ok,
       %SymPyResponse{
         request_id: request_id,
         ok: ok?,
         result_string: result_string,
         result_latex: result_latex,
         normalized_expression: normalized_expression,
         error: error
       }}
    end
  end

  def parse_sympy_response(_payload), do: {:error, :invalid_sympy_response}

  @spec to_symbol(Query.t(), AIResponse.t(), SymPyResponse.t()) ::
          {:ok, Symbol.t()} | {:error, term()}
  def to_symbol(
        %Query{} = query,
        %AIResponse{mode: :computation} = ai_response,
        %SymPyResponse{ok: true} = sympy_response
      ) do
    normalized_expression =
      sympy_response.normalized_expression || sympy_response.result_string ||
        ai_response.sympy_executable

    verified_expressions =
      verified_desmos_expressions(ai_response.desmos_expressions, normalized_expression)

    graph_expression =
      verified_expressions
      |> List.first()
      |> Map.get(:latex, relation_from_expression(normalized_expression))

    {:ok,
     %Symbol{
       statement: query.text,
       expression: sympy_response.result_string || normalized_expression,
       latex: sympy_response.result_latex || ai_response.raw_latex,
       graph_expression: graph_expression,
       source: :contract,
       raw: %{
         query_text: query.text,
         ai_response: serialize_ai_response(ai_response),
         sympy_response: serialize_sympy_response(sympy_response),
         desmos_expressions:
           Enum.map(ai_response.desmos_expressions, &serialize_desmos_expression/1),
         verified_desmos_expressions:
           Enum.map(verified_expressions, &serialize_desmos_expression/1)
       },
       notes: ai_response.reasoning_steps
     }}
  end

  def to_symbol(_query, %AIResponse{mode: :chat}, _sympy_response),
    do: {:error, :chat_response_has_no_symbol}

  def to_symbol(_query, _ai_response, %SymPyResponse{error: error}),
    do: {:error, {:sympy_execution_failed, error}}

  @spec to_desmos_payload([DesmosExpression.t()], map()) :: DesmosPayload.t()
  def to_desmos_payload(expressions, viewport \\ @default_viewport) do
    %DesmosPayload{expressions: expressions, viewport: viewport}
  end

  defp fetch_desmos_expressions(payload) do
    payload
    |> Map.get("desmos_expressions")
    |> case do
      expressions when is_list(expressions) ->
        expressions
        |> Enum.reduce_while({:ok, []}, fn expression, {:ok, acc} ->
          case parse_desmos_expression(expression) do
            {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
        |> case do
          {:ok, expressions} -> {:ok, Enum.reverse(expressions)}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, :missing_desmos_expressions}
    end
  end

  defp parse_desmos_expression(payload) when is_map(payload) do
    with {:ok, id} <- fetch_string(payload, "id"),
         {:ok, latex} <- fetch_string(payload, "latex") do
      {:ok, %DesmosExpression{id: id, latex: latex}}
    end
  end

  defp parse_desmos_expression(_payload), do: {:error, :invalid_desmos_expression}

  defp fetch_ai_response_mode(payload) do
    case Map.get(payload, "mode") do
      "computation" -> {:ok, :computation}
      "chat" -> {:ok, :chat}
      _ -> {:error, {:invalid_mode_field, "mode"}}
    end
  end

  defp fetch_string(payload, key) do
    case Map.get(payload, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:invalid_string_field, key}}
    end
  end

  defp fetch_optional_string(payload, key) do
    case Map.get(payload, key) do
      nil -> {:ok, nil}
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, {:invalid_optional_string_field, key}}
    end
  end

  defp fetch_boolean(payload, key) do
    case Map.get(payload, key) do
      value when is_boolean(value) -> {:ok, value}
      _ -> {:error, {:invalid_boolean_field, key}}
    end
  end

  defp fetch_string_list(payload, key) do
    case Map.get(payload, key) do
      value when is_list(value) ->
        if Enum.all?(value, &is_binary/1),
          do: {:ok, value},
          else: {:error, {:invalid_string_list_field, key}}

      _ ->
        {:error, {:invalid_string_list_field, key}}
    end
  end

  defp verified_desmos_expressions([], normalized_expression) do
    [%DesmosExpression{id: "graph1", latex: relation_from_expression(normalized_expression)}]
  end

  defp verified_desmos_expressions([%DesmosExpression{} = first | rest], normalized_expression) do
    [%{first | latex: relation_from_expression(normalized_expression)} | rest]
  end

  defp relation_from_expression(expression) when is_binary(expression) do
    expression =
      expression
      |> String.trim()
      |> String.replace("**", "^")

    if String.contains?(expression, "="), do: expression, else: "y=#{expression}"
  end

  defp serialize_ai_response(%AIResponse{} = response) do
    %{
      mode: response.mode,
      reasoning_steps: response.reasoning_steps,
      raw_latex: response.raw_latex,
      sympy_executable: response.sympy_executable,
      desmos_expressions: Enum.map(response.desmos_expressions, &serialize_desmos_expression/1),
      chat_reply: response.chat_reply
    }
  end

  defp serialize_sympy_response(%SymPyResponse{} = response) do
    %{
      request_id: response.request_id,
      ok: response.ok,
      result_string: response.result_string,
      result_latex: response.result_latex,
      normalized_expression: response.normalized_expression,
      error: response.error
    }
  end

  defp serialize_desmos_expression(%DesmosExpression{} = expression) do
    %{id: expression.id, latex: expression.latex}
  end
end
