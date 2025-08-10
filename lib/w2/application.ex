defmodule W2.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    _repo_config = Application.fetch_env!(:w2, W2.Repo)
    duck_config = Application.fetch_env!(:w2, :duck)

    children = [
      W2.Repo,
      %{
        id: :duck,
        start: {__MODULE__, :init_duck, [duck_config]},
        type: :worker
      },
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

  @doc false
  def init_duck(config) do
    :persistent_term.put(:duck, DuxDB.connect(DuxDB.open(":memory:", config)))
    :ignore
  end
end
