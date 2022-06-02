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

  def bucket_data(from, to) do
    "heartbeats"
    |> select([h], {h.time, h.project})
    |> where([h], h.time > ^time(from))
    |> where([h], h.time < ^time(to))
    |> order_by([h], asc: h.time)
    |> Repo.all()
    |> bucket_totals(interval(from, to))
  end

  @hour_in_seconds 3600
  @day_in_seconds 24 * @hour_in_seconds

  @doc """

      iex> interval(~U[2022-01-01 00:00:00Z], ~U[2022-01-06 00:00:00Z])
      86400

      iex> interval(~U[2022-01-01 00:00:00Z], ~U[2022-01-05 00:00:00Z])
      3600

      iex> interval(~U[2022-01-01 00:00:00Z], ~U[2022-01-01 23:00:00Z])
      1800

      iex> interval(~U[2022-01-01 00:00:00Z], ~U[2022-01-01 04:00:00Z])
      600

  """
  def interval(from, to) do
    diff = time(to) - time(from)

    cond do
      # TODO years, months, weeks
      diff > 4 * @day_in_seconds -> @day_in_seconds
      diff > @day_in_seconds -> @hour_in_seconds
      diff > 12 * @hour_in_seconds -> 30 * 60
      diff > 6 * @hour_in_seconds -> 15 * 60
      diff > 3 * @hour_in_seconds -> 10 * 60
      diff > 1800 -> 60
      true -> 15
    end
  end

  @compile {:inline, bucket: 2}
  def bucket(time, interval) do
    div(floor(time), interval)
  end

  def bucket_totals([{time, project} | heartbeats], interval) do
    bucket_totals(
      heartbeats,
      time,
      # TODO _prev_time = nil?
      _prev_time = time,
      project,
      _inner_acc = %{},
      _outer_acc = [],
      interval
    )
  end

  def bucket_totals([] = heartbeats, _interval), do: heartbeats

  defp bucket_totals(
         [{time, project} | heartbeats],
         start_time,
         prev_time,
         prev_project,
         inner_acc,
         outer_acc,
         interval
       ) do
    same_project? = project == prev_project
    same_duration? = time - prev_time < 300
    same_bucket? = bucket(start_time, interval) == bucket(time, interval)

    if same_bucket? and same_project? and same_duration? do
      bucket_totals(heartbeats, start_time, time, project, inner_acc, outer_acc, interval)
    else
      {end_time, next_start_time, prev_time} =
        cond do
          same_duration? and same_bucket? ->
            {time, time, time}

          same_duration? ->
            {bucket(time, interval) * interval, bucket(time, interval) * interval, time}

          true ->
            {prev_time, time, time}
        end

      add = end_time - start_time
      inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)

      if same_bucket? do
        bucket_totals(
          heartbeats,
          next_start_time,
          prev_time,
          project,
          inner_acc,
          outer_acc,
          interval
        )
      else
        outer_acc = [[bucket(start_time, interval) * interval, inner_acc] | outer_acc]
        bucket_totals(heartbeats, next_start_time, prev_time, project, %{}, outer_acc, interval)
      end
    end
  end

  defp bucket_totals([], start_time, prev_time, prev_project, inner_acc, outer_acc, interval) do
    add = prev_time - start_time
    inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)
    :lists.reverse([[bucket(start_time, interval) * interval, inner_acc] | outer_acc])
  end

  defp time(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp time(unix) when is_integer(unix) or is_float(unix), do: unix
  defp time(%Date{} = date), do: time(DateTime.new!(date, Time.new!(0, 0, 0)))
end
