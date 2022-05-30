defmodule W2.Ingester.Heartbeat do
  @doc false
  use Ecto.Schema

  @primary_key false
  schema "heartbeats" do
    # TODO
    field :time, :float
    field :branch, :string
    field :category, :string
    field :cursorpos, :integer
    field :dependencies, {:array, :string}
    field :entity, :string
    field :is_write, :boolean
    field :language, :string
    field :lineno, :integer
    field :lines, :integer
    field :project, :string
    field :type, :string
    field :operating_system, :string
    field :editor, :string
  end
end
