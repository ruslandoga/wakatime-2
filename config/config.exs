import Config

config :w2, ecto_repos: [W2.Repo]

config :sentry,
  client: W2.Sentry.FinchHTTPClient,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]
