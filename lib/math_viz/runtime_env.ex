defmodule MathViz.RuntimeEnv do
  @moduledoc false

  @default_nim_base_url "https://integrate.api.nvidia.com/v1"
  @default_nim_model "moonshotai/kimi-k2-5"
  @default_nim_timeout_ms 15_000

  @type env_reader :: (String.t() -> String.t() | nil)

  @spec nlp_mode(env_reader()) :: :stub | :nim | :dual
  def nlp_mode(env_reader \\ &System.get_env/1) do
    case env_reader.("MATH_VIZ_NLP_MODE") do
      "nim" -> :nim
      "dual" -> :dual
      "stub" -> :stub
      nil -> if(nvidia_nim_api_key(env_reader), do: :dual, else: :stub)
      _ -> :stub
    end
  end

  @spec nvidia_nim_config(env_reader()) :: keyword()
  def nvidia_nim_config(env_reader \\ &System.get_env/1) do
    [
      api_key: nvidia_nim_api_key(env_reader),
      base_url: env_reader.("NVIDIA_NIM_BASE_URL") || @default_nim_base_url,
      model: env_reader.("NVIDIA_NIM_MODEL") || @default_nim_model,
      timeout_ms: parse_timeout_ms(env_reader.("NVIDIA_NIM_TIMEOUT_MS"))
    ]
  end

  @spec nvidia_nim_api_key(env_reader()) :: String.t() | nil
  def nvidia_nim_api_key(env_reader \\ &System.get_env/1) do
    env_reader.("NVIDIA_NIM_API_KEY") || env_reader.("NIM_API_KEY")
  end

  defp parse_timeout_ms(nil), do: @default_nim_timeout_ms

  defp parse_timeout_ms(value) when is_binary(value) do
    case Integer.parse(value) do
      {timeout_ms, ""} -> timeout_ms
      _ -> @default_nim_timeout_ms
    end
  end
end
