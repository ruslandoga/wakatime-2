defmodule W2.Repo.Migrations.AddHeartbeats do
  use Ecto.Migration

  def change do
    create table(:heartbeats, primary_key: false, options: "STRICT") do
      add :time, :real, null: false
      add :entity, :text, null: false
      add :type, :text, null: false
      add :category, :text
      add :project, :text
      add :branch, :text
      add :language, :text
      add :dependencies, :text
      add :lines, :integer
      add :lineno, :integer
      add :cursorpos, :integer
      add :is_write, :integer, null: false, default: false
      add :editor, :text
      add :operating_system, :text
      add :machine_name, :text
    end

    create index(:heartbeats, [:time])
  end
end
