import Config

# Configure your database
config :w2, W2.Repo,
  database: Path.expand("../w2_bench.db", Path.dirname(__ENV__.file)),
  pool_size: 5

# We don't run a server during bench. If one is required,
# you can enable the server option below.
config :w2, W2Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4003],
  secret_key_base: "GfhL5S5PjM8RncNyv3rC/8ohyBlfyiy9pqxBDG/8XxJlIxNQ88MOZmzDjZOSrpwo",
  server: false

# In bench we don't send emails.
config :w2, W2.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during bench
config :logger, level: :warn
