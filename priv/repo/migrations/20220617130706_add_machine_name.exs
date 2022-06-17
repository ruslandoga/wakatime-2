defmodule W2.Repo.Migrations.AddMachineName do
  use Ecto.Migration

  def change do
    alter table(:heartbeats) do
      add :machine_name, :text
    end
  end
end
