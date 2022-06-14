import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

config :sentry,
  environment_name: config_env(),
  included_environments: []

config :w2, W2.Repo,
  after_connect: fn _conn ->
    [db_conn] = Process.get(:"$callers")
    db_connection_state = :sys.get_state(db_conn)
    conn = db_connection_state.mod_state.state
    :ok = Exqlite.Basic.enable_load_extension(conn)
    path = Path.join(:code.priv_dir(:w2), "timeline.sqlite3ext")
    {:ok, _query, _result, _conn} = Exqlite.Basic.load_extension(conn, path)
    :ok = Exqlite.Basic.disable_load_extension(conn)
  end

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/w2 start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :w2, W2Web.Endpoint, server: true
end

if config_env() == :prod do
  config :w2, api_key: System.fetch_env!("API_KEY")

  config :logger, level: :info

  if dns = System.get_env("SENTRY_DSN") do
    config :logger, backends: [:console, Sentry.LoggerBackend]
    config :sentry, dsn: dns, included_environments: [:prod]
  end

  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/w2/w2.db
      """

  config :w2, W2.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    # https://litestream.io/tips/#disable-autocheckpoints-for-high-write-load-servers
    wal_auto_check_point: 0,
    # https://litestream.io/tips/#busy-timeout
    busy_timeout: 5000,
    cache_size: -2000

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

  host = System.fetch_env!("PHX_HOST")
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :w2, W2Web.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end

if config_env() == :dev do
  config :w2, api_key: "406fe41f-6d69-4183-a4cc-121e0c524c2b"
  config :w2, W2.Repo, database: Path.expand("../w2_dev.db", Path.dirname(__ENV__.file))
end

if config_env() == :test do
  config :w2, api_key: "406fe41f-6d69-4183-a4cc-121e0c524c2b"
end

if config_env() == :bench do
  db = System.get_env("DATABASE") || "w2_bench.db"
  config :w2, W2.Repo, database: Path.expand("../" <> db, Path.dirname(__ENV__.file))
end
