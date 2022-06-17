defmodule W2.Release do
  require Logger
  @app :w2

  defmodule Migrator do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      if opts[:migrate], do: W2.Release.migrate()
      :ignore
    end
  end

  def migrate do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end
end
