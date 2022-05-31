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

  def chart_data(from, to) do
    heartbeats =
      "heartbeats"
      |> select([h], {h.time, h.project})
      |> where([h], h.time > ^time(from))
      |> where([h], h.time < ^time(to))
      |> order_by([h], asc: h.time)
      |> Repo.all()

    case heartbeats do
      [] ->
        %{}

      [{time, project} | heartbeats] ->
        hourly_totals(
          heartbeats,
          time,
          _prev_time = nil,
          project,
          _inner_acc = %{},
          _outer_acc = %{}
        )
    end
  end

  @compile {:inline, hour: 1}
  def hour(time) do
    div(round(time), 3600)
  end

  def hourly_totals(
        [{time, project} | heartbeats],
        start_time,
        prev_time,
        prev_project,
        inner_acc,
        outer_acc
      ) do
    same_project? = project == prev_project
    same_duration? = time - prev_time < 300
    same_hour? = hour(start_time) == hour(time)

    if same_hour? and same_project? and same_duration? do
      hourly_totals(heartbeats, start_time, _prev_time = time, project, inner_acc, outer_acc)
    else
      {end_time, next_start_time} =
        cond do
          same_duration? and same_hour? -> {time, time}
          same_duration? -> {hour(time) * 3600, hour(time) * 3600}
          true -> {prev_time, time}
        end

      add = end_time - start_time
      inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)

      if same_hour? do
        hourly_totals(
          heartbeats,
          next_start_time,
          _prev_time = nil,
          project,
          inner_acc,
          outer_acc
        )
      else
        outer_acc = Map.put(outer_acc, hour(start_time), inner_acc)

        hourly_totals(
          heartbeats,
          next_start_time,
          _prev_time = nil,
          project,
          _inner_acc = %{},
          outer_acc
        )
      end
    end
  end

  # TODO
  def hourly_totals([], start_time, prev_time, prev_project, inner_acc, outer_acc) do
    {start_time, prev_time, prev_project, inner_acc, outer_acc}
  end

  defp time(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp time(unix) when is_integer(unix) or is_float(unix), do: unix
  defp time(%Date{} = date), do: time(DateTime.new!(date, Time.new!(0, 0, 0)))
end
