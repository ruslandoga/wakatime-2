defmodule W2.Durations do
  alias W2.Repo
  # alias W2.Ingester.Heartbeat

  import Ecto.Query

  defmodule UnixTime do
    use Ecto.Type

    @impl true
    def type, do: :any

    @impl true
    def cast(value) do
      {:ok, value}
    end

    @impl true
    def dump(value) when is_number(value) do
      {:ok, value}
    end

    @impl true
    def load(value) when is_float(value) do
      DateTime.from_unix(round(value))
    end
  end

  defmodule Duration do
    use Ecto.Schema

    schema "durations" do
      field :time, UnixTime
      field :project, :string
    end
  end

  defmacro durations_q(from, to) do
    quote do
      fragment(
        """
        select sum(dchange) over (order by time) id, * from (
          select case when time - lag(time, 1) over (order by time) > 300 then 1 else 0 end dchange, *
          from heartbeats
          where time > ? and time < ?
        )
        """,
        unquote(from),
        unquote(to)
      )
    end
  end

  def by_project_q(from, to) do
    {"durations", Duration}
    |> with_cte("durations", as: durations_q(^time(from), ^time(to)))
    |> group_by([d], [d.project, d.id])
  end

  @doc """
  Lists durations by project.

  Example:

      list_by_project(_from = ~U[2022-05-30 13:20:00Z], _to = ~U[2022-05-30 15:41:45Z])
      [
        %{from: ~U[2022-05-30 13:20:33Z], project: "w2", to: ~U[2022-05-30 14:22:03Z]},
        %{from: ~U[2022-05-30 14:27:31Z], project: "w2", to: ~U[2022-05-30 14:27:31Z]},
        %{from: ~U[2022-05-30 14:36:07Z], project: "w2", to: ~U[2022-05-30 14:36:08Z]},
        %{from: ~U[2022-05-30 14:58:31Z], project: "w2", to: ~U[2022-05-30 15:41:11Z]}
      ]

  """
  def list_by_project(from, to) do
    durations =
      by_project_q(from, to)
      |> select([d], %{
        project: d.project,
        from: type(fragment("min(?)", d.time), UnixTime),
        to: type(fragment("max(?)", d.time), UnixTime)
      })
      |> Repo.all()

    seconds =
      Enum.reduce(durations, 0, fn %{from: from, to: to}, acc ->
        DateTime.diff(to, from) + acc
      end)

    {hours, rem} = {div(seconds, 3600), rem(seconds, 3600)}
    {minutes, rem} = {div(rem, 60), rem(rem, 60)}

    {durations, seconds, {hours, minutes, rem}}
  end

  defp time(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp time(unix) when is_integer(unix) or is_float(unix), do: unix
  defp time(%Date{} = date), do: time(DateTime.new!(date, Time.new!(0, 0, 0)))
end
