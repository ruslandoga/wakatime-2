defmodule W2.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    repo_config = Application.fetch_env!(:w2, W2.Repo)
    endpoint_config = Application.fetch_env!(:w2, W2.Endpoint)
    http_options = Keyword.fetch!(endpoint_config, :http)

    children = [
      W2.Repo,
      {W2.Release.Migrator, migrate: repo_config[:migrate]},
      {Plug.Cowboy, scheme: :http, plug: W2.Endpoint, options: http_options}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: W2.Supervisor)
  end
end
