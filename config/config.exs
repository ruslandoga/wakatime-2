# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :w2,
  ecto_repos: [W2.Repo]

# Configures the endpoint
config :w2, W2Web.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: W2Web.ErrorHTML, json: W2Web.ErrorJSON],
    layout: false
  ],
  pubsub_server: W2.PubSub,
  live_view: [signing_salt: "yePNywHX"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix,
  json_library: Jason,
  static_compressors: [
    PhoenixBakery.Gzip,
    PhoenixBakery.Brotli,
    PhoenixBakery.Zstd
  ]

config :sentry,
  client: W2.Sentry.FinchHTTPClient,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

config :elixir, :time_zone_database, W2.TimeZoneDatabase

# TODO don't hardcode, but read from env vars
config :w2,
  relocations: [
    {~D[0000-01-01], "Europe/Moscow"},
    {~D[2022-08-28], "Asia/Tbilisi"},
    {~D[2022-10-08], "Asia/Bangkok"},
    {~D[2022-11-04], "Asia/Kuala_Lumpur"},
    {~D[2022-11-30], "Asia/Bangkok"},
    {~D[2022-12-17], "Asia/Taipei"},
    {~D[2022-12-28], "Asia/Hong_Kong"},
    {~D[2023-01-06], "Asia/Hanoi"},
    {~D[2023-02-03], "Asia/Bangkok"},
    {~D[2023-03-18], "Asia/Ho_Chi_Minh"},
    {~D[2023-03-30], "Asia/Bangkok"},
    {~D[2023-05-13], "Asia/Kuala_Lumpur"},
    {~D[2023-07-01], "Asia/Chiang_Mai"},
    {~D[2023-09-28], "Asia/Kuala_Lumpur"},
    {~D[2023-10-27], "Asia/Busan"},
    {~D[2023-11-30], "Asia/Taipei"},
    {~D[2023-12-18], "Asia/Penang"},
    {~D[2023-12-31], "Asia/Tokyo"},
    {~D[2024-01-30], "Asia/Busan"},
    {~D[2024-02-03], "Europe/Moscow"},
    {~D[2024-02-13], "Asia/Kuala_Lumpur"},
    {~D[2024-04-30], "Asia/Chiang_Mai"}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
