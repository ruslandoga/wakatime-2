defmodule W2.Repo.Migrations.AddDurations do
  use Ecto.Migration

  def change do
    interval = W2.interval()
    duration_table = W2.Durations.duration_table(interval)

    create_if_not_exists table(duration_table, primary_key: false, options: "STRICT") do
      add :id, :integer, null: false
      add :start, :real, null: false
      add :length, :real, null: false
      add :project, :text
      add :branch, :text
      add :entity, :text, null: false
    end

    create_if_not_exists index(duration_table, [:start])
  end
end
