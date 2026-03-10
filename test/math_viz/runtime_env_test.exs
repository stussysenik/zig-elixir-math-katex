defmodule MathViz.RuntimeEnvTest do
  use ExUnit.Case, async: true

  alias MathViz.RuntimeEnv

  test "prefers NVIDIA_NIM_API_KEY over the legacy alias" do
    env = fn
      "NVIDIA_NIM_API_KEY" -> "preferred-key"
      "NIM_API_KEY" -> "legacy-key"
      _ -> nil
    end

    assert RuntimeEnv.nvidia_nim_api_key(env) == "preferred-key"
    assert RuntimeEnv.nlp_mode(env) == :dual
  end

  test "uses the legacy NIM_API_KEY when the preferred key is absent" do
    env = fn
      "NIM_API_KEY" -> "legacy-key"
      _ -> nil
    end

    assert RuntimeEnv.nvidia_nim_api_key(env) == "legacy-key"
    assert RuntimeEnv.nlp_mode(env) == :dual
  end
end
