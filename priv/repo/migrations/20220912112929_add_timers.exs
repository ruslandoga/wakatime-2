defmodule W2.Repo.Migrations.AddTimers do
  use Ecto.Migration

  def change do
    create table(:timers) do
      add :started_at, :integer, null: false
      add :finished_at, :integer
      add :task, :text, null: false
    end
  end
end
