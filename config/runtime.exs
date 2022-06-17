import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :sentry,
  environment_name: config_env(),
  included_environments: []

if dns = System.get_env("SENTRY_DSN") do
  config :logger, backends: [:console, Sentry.LoggerBackend]
  config :sentry, dsn: dns, included_environments: [:prod]
end

config :w2, W2.Repo, after_connect: fn _conn -> W2.Release.load_timeline_extension() end

api_key =
  if config_env() == :prod do
    System.fetch_env!("API_KEY")
  else
    "406fe41f-6d69-4183-a4cc-121e0c524c2b"
  end

config :w2, api_key: api_key

if System.get_env("PHX_SERVER") do
  config :w2, W2.Endpoint, server: true
end

if config_env() == :prod do
  config :logger, level: :info

  config :w2, W2.Repo,
    database: System.fetch_env!("DATABASE_PATH"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    # https://litestream.io/tips/#disable-autocheckpoints-for-high-write-load-servers
    wal_auto_check_point: 0,
    # https://litestream.io/tips/#busy-timeout
    busy_timeout: 5000,
    cache_size: -2000,
    migrate: true

  host = System.fetch_env!("PHX_HOST")
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :w2, W2.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ]
end

if config_env() == :dev do
  config :logger, level: :debug

  config :w2, W2.Repo,
    database: Path.expand("../w2_dev.db", Path.dirname(__ENV__.file)),
    pool_size: 5,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true

  config :w2, W2.Endpoint,
    # Binding to loopback ipv4 address prevents access from other machines.
    # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
    http: [ip: {127, 0, 0, 1}, port: 4000],
    check_origin: false,
    code_reloader: true,
    watchers: [
      npm: ["run", "watch:js", cd: Path.expand("../assets", __DIR__)],
      npm: ["run", "watch:css", cd: Path.expand("../assets", __DIR__)]
    ],
    live_reload: [
      patterns: [
        ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
        ~r"lib/w2/views/.*(ex)$",
        ~r"lib/w2/templates/.*(eex)$"
      ]
    ]
end

if config_env() == :test do
  config :w2, W2.Repo,
    database: Path.expand("../w2_test.db", Path.dirname(__ENV__.file)),
    pool_size: 5,
    pool: Ecto.Adapters.SQL.Sandbox

  config :w2, W2.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4002],
    server: false

  config :logger, level: :warn
end

if config_env() == :bench do
  db = System.get_env("DATABASE") || "w2_bench.db"

  config :w2, W2.Repo,
    database: Path.expand("../" <> db, Path.dirname(__ENV__.file)),
    cache_size: -2000,
    pool_size: 20

  config :w2, W2.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4003],
    server: false

  config :logger, level: :warn
end
