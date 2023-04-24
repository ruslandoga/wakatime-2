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
  render_errors: [view: W2Web.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: W2.PubSub,
  live_view: [signing_salt: "yePNywHX"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :sentry, client: W2.Sentry.FinchHTTPClient

config :sentry,
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
    {~D[2023-05-13], "Asia/Kuala_Lumpur"}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
