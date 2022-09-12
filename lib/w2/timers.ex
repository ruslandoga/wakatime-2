defmodule W2.Timers do
  @moduledoc """
  Timers can be named, started, and finished.
  Timers show up as backdrop on durations dashboard.
  """

  alias W2.Repo
  import Ecto.{Query, Changeset}

  defmodule Timer do
    use Ecto.Schema

    @type t :: %__MODULE__{
            started_at: DateTime.t(),
            task: String.t(),
            finished_at: DateTime.t() | nil
          }

    schema "timers" do
      field :started_at, :utc_datetime
      field :task, :string
      field :finished_at, :utc_datetime
    end
  end

  def timer_changeset(timer \\ %Timer{}, attrs) do
    timer
    |> cast(attrs, [:task])
    |> validate_required([:task])
  end

  defp utc_now do
    DateTime.truncate(DateTime.utc_now(), :second)
  end

  @spec create_timer(map(), DateTime.t()) :: {:ok, Timer.t()} | {:error, Ecto.Changeset.t()}
  def create_timer(params, now \\ utc_now()) do
    %Timer{started_at: now}
    |> timer_changeset(params)
    |> Repo.insert()
  end

  @spec finish_timer(pos_integer(), DateTime.t()) :: :ok
  def finish_timer(timer_or_timer_id, now \\ utc_now())

  def finish_timer(timer_id, finished_at) when is_integer(timer_id) do
    {1, nil} =
      Timer
      |> where(id: ^timer_id)
      |> Repo.update_all(set: [finished_at: finished_at])

    :ok
  end

  def finish_timer(%Timer{id: timer_id}, finished_at) do
    finish_timer(timer_id, finished_at)
  end

  @spec list_active_timers(DateTime.t()) :: [Timer.t()]
  def list_active_timers(now \\ utc_now()) do
    Timer
    |> where([t], t.started_at <= ^now)
    |> where([t], is_nil(t.finished_at))
    |> order_by([t], asc: t.started_at)
    |> Repo.all()
  end
end
