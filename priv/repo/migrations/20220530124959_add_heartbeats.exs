defmodule W2.Repo.Migrations.AddHeartbeats do
  use Ecto.Migration

  def change do
    create table(:heartbeats, primary_key: false, options: "strict, without rowid") do
      add :time, :real, null: false, primary_key: true
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
    end

    # create index(:heartbeats, [:time])
  end
end
