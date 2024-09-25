defmodule W2.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    repo_config = Application.fetch_env!(:w2, W2.Repo)

    children = [
      W2.Repo,
      {W2.Release.Migrator, migrate: repo_config[:migrate]},
      W2Web.Telemetry,
      {Phoenix.PubSub, name: W2.PubSub},
      W2Web.Endpoint
    ]

    opts = [strategy: :one_for_one, name: W2.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    W2Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
