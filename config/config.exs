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
    PhoenixBakery.Brotli
  ]

config :sentry,
  client: W2.Sentry.FinchHTTPClient,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# TODO don't hardcode, but read from env vars
config :w2,
  relocations: [
    {~D[2022-01-01], "Europe/Moscow"},
    {~D[2022-08-28], "Asia/Tbilisi"},
    {~D[2022-10-08], "Asia/Bangkok"},
    {~D[2022-11-04], "Asia/Kuala_Lumpur"},
    {~D[2022-11-30], "Asia/Bangkok"},
    # Taipei -> Taichung -> Kaohsiung -> Checheng -> Taimali -> Taitung -> Taipei
    {~D[2022-12-17], "Asia/Taipei"},
    {~D[2022-12-28], "Asia/Hong_Kong"},
    # Hanoi
    {~D[2023-01-06], "Asia/Ho_Chi_Minh"},
    {~D[2023-02-03], "Asia/Bangkok"},
    {~D[2023-03-18], "Asia/Ho_Chi_Minh"},
    {~D[2023-03-30], "Asia/Bangkok"},
    {~D[2023-05-13], "Asia/Kuala_Lumpur"},
    # Chiang Mai -> Mae Hong Son -> Chiang Mai -> Bangkok
    {~D[2023-07-01], "Asia/Bangkok"},
    {~D[2023-09-28], "Asia/Kuala_Lumpur"},
    # Busan
    {~D[2023-10-27], "Asia/Seoul"},
    # Taipei -> Toucheng -> Luodong -> Hualien -> Taipei
    {~D[2023-11-30], "Asia/Taipei"},
    # Penang
    {~D[2023-12-18], "Asia/Kuala_Lumpur"},
    # Tokyo -> Nagoya -> Kyoto -> Osaka -> Tokyo -> Osaka -> Kyoto -> Fukuoka
    {~D[2023-12-31], "Asia/Tokyo"},
    {~D[2024-01-30], "Asia/Seoul"},
    # Moscow -> Kazan -> Moscow
    {~D[2024-02-03], "Europe/Moscow"},
    # Kuala Lumpur -> Kota Kinabalu
    {~D[2024-02-13], "Asia/Kuala_Lumpur"},
    # Chiang Mai -> Mae Hong Son -> Chiang Mai
    {~D[2024-04-30], "Asia/Bangkok"},
    # Hanoi
    {~D[2024-07-28], "Asia/Ho_Chi_Minh"},
    {~D[2024-08-06], "Asia/Seoul"},
    # Chiang Mai
    {~D[2024-08-13], "Asia/Bangkok"},
    # Hanoi
    {~D[2024-10-11], "Asia/Ho_Chi_Minh"},
    {~D[2024-10-19], "Asia/Hong_Kong"},
    # Chiang Mai
    {~D[2024-10-27], "Asia/Bangkok"},
    {~D[2024-12-26], "Europe/Moscow"},
    # Onomichi -> Omishima -> Imabari (no stay) -> Kobe -> Kyoto -> Nagoya -> Matsumoto -> Tokyo
    {~D[2025-08-13], "Asia/Tokyo"},
    {~D[2025-09-11], "Europe/Moscow"},
    # Hanoi -> Da Nang -> Saigon
    {~D[2024-10-13], "Asia/Ho_Chi_Minh"}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
