import Config

project_root = Path.expand("..", __DIR__)

load_env_file = fn relative_path ->
  path = Path.join(project_root, relative_path)

  if File.exists?(path) do
    path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.each(fn line ->
      case String.split(line, "=", parts: 2) do
        [raw_key, raw_value] ->
          key =
            raw_key
            |> String.trim()
            |> String.trim_leading("export ")

          value =
            raw_value
            |> String.trim()
            |> String.trim_leading("\"")
            |> String.trim_trailing("\"")
            |> String.trim_leading("'")
            |> String.trim_trailing("'")

          if System.get_env(key) == nil do
            System.put_env(key, value)
          end

        _ ->
          :ok
      end
    end)
  end
end

Enum.each([".env.local", ".env"], load_env_file)

nlp_mode =
  case System.get_env("MATH_VIZ_NLP_MODE") do
    "nim" -> :nim
    "dual" -> :dual
    "stub" -> :stub
    nil -> if(System.get_env("NVIDIA_NIM_API_KEY"), do: :dual, else: :stub)
    _ -> :stub
  end

config :math_viz, :nlp_mode, nlp_mode

config :math_viz, :nvidia_nim,
  api_key: System.get_env("NVIDIA_NIM_API_KEY"),
  base_url: System.get_env("NVIDIA_NIM_BASE_URL", "https://integrate.api.nvidia.com/v1"),
  model: System.get_env("NVIDIA_NIM_MODEL", "moonshotai/kimi-k2-5"),
  timeout_ms: String.to_integer(System.get_env("NVIDIA_NIM_TIMEOUT_MS", "15000"))

config :math_viz,
       :desmos_api_key,
       System.get_env("DESMOS_API_KEY", Application.get_env(:math_viz, :desmos_api_key))

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/math_viz start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
default_port =
  case config_env() do
    :test -> 4012
    :prod -> String.to_integer(System.get_env("PORT", "4000"))
    _ -> 4000
  end

if System.get_env("PHX_SERVER") do
  config :math_viz, MathVizWeb.Endpoint, server: true
end

config :math_viz, MathVizWeb.Endpoint, http: [ip: {127, 0, 0, 1}, port: default_port]

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :math_viz, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :math_viz, MathVizWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :math_viz, MathVizWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :math_viz, MathVizWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :math_viz, MathViz.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
