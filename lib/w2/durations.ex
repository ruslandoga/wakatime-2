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

    hourly_totals(
      heartbeats,
      _start_time = nil,
      _prev_time = nil,
      _project = nil,
      _inner_acc = %{},
      _outer_acc = %{}
    )
  end

  # project switch

  _in = [
    {~U[2022-01-01 12:04:12Z], "w1"},
    {~U[2022-01-01 12:04:13Z], "w1"},
    {~U[2022-01-01 12:04:18Z], "w1"},
    {~U[2022-01-01 12:04:19Z], "w2"},
    {~U[2022-01-01 12:05:19Z], "w2"}
  ]

  _out = %{
    ~U[2022-01-01 12:00:00Z] => %{
      "w1" => 7,
      "w2" => 60
    }
  }

  # hour switch

  @compile {:inline, hour: 1}
  def hour(time) do
    div(time, 3600)
  end

  def hour_switch(
        [{time, project} | heartbeats],
        start_time,
        prev_time,
        prev_project,
        inner_acc,
        outer_acc
      ) do
    same_project? = project == prev_project
    same_duration? = time - prev_time < 300

    if hour(start_time) == hour(time) do
      if same_project? do
        if same_duration? do
          # same hour, same project, same duration -> continue
          hour_switch(heartbeats, start_time, _prev_time = time, project, inner_acc, outer_acc)
        else
          # took a break (>5min) from project, restarted on the same project after sime time
          # same hour, same project, different duration -> start new duration without filling
          add = prev_time - start_time
          inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)

          hour_switch(
            heartbeats,
            _start_time = time,
            _prev_time = nil,
            project,
            inner_acc,
            outer_acc
          )
        end
      else
        if same_duration? do
          # project switch while still working
          # same hour, different project, same duration -> start new duration with filling prev project
          add = time - start_time
          inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)

          hour_switch(
            heartbeats,
            _start_time = time,
            _prev_time = nil,
            project,
            inner_acc,
            outer_acc
          )
        else
          # took a break (>5 min) from project, restarted on a different project after some time
          # same hour, different project, different duration -> start new duration without filling
          add = prev_time - start_time
          inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)

          hour_switch(
            heartbeats,
            _start_time = time,
            _prev_time = nil,
            project,
            inner_acc,
            outer_acc
          )
        end
      end
    else
      if same_project? do
        if same_duration? do
          # different hour, same project, same duration -> split w/o gap (= with filling)
          add = hour(time) * 3600 - start_time
          inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)
          outer_acc = Map.put(outer_acc, hour(start_time), inner_acc)

          hour_switch(
            heartbeats,
            _start_time = hour(time) * 3600,
            _prev_time = nil,
            project,
            _inner_acc = %{},
            outer_acc
          )
        else
          # different hour, same project, different duration -> split w/ gap (= without filling)
          add = prev_time - start_time
          inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)
          outer_acc = Map.put(outer_acc, hour(start_time), inner_acc)

          hour_switch(
            heartbeats,
            _start_time = time,
            _prev_time = nil,
            project,
            _inner_acc = %{},
            outer_acc
          )
        end
      else
        if same_duration? do
          # different hour, different project, same duration -> split with filling
          add = hour(time) * 3600 - start_time
          inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)
          outer_acc = Map.put(outer_acc, hour(start_time), inner_acc)

          hour_switch(
            heartbeats,
            _start_time = hour(time) * 3600,
            _prev_time = nil,
            project,
            _inner_acc = %{},
            outer_acc
          )
        else
          # different hour, different project, differemt duration -> split without filling
          add = prev_time - start_time
          inner_acc = Map.update(inner_acc, prev_project, add, fn prev -> prev + add end)
          outer_acc = Map.put(outer_acc, hour(start_time), inner_acc)

          hour_switch(
            heartbeats,
            _start_time = time,
            _prev_time = nil,
            project,
            _inner_acc = %{},
            outer_acc
          )
        end
      end
    end
  end

  _in = [
    {~U[2022-01-01 12:58:12Z], "w1"},
    {~U[2022-01-01 12:59:13Z], "w1"},
    {~U[2022-01-01 13:00:18Z], "w1"}
  ]

  _out = %{
    ~U[2022-01-01 12:00:00Z] => %{"w1" => 108},
    ~U[2022-01-01 13:00:00Z] => %{"w1" => 18}
  }

  # duration break

  _in = [
    {~U[2022-01-01 12:04:12Z], "w1"},
    {~U[2022-01-01 12:05:12Z], "w1"},
    {~U[2022-01-01 13:04:18Z], "w1"},
    {~U[2022-01-01 13:04:19Z], "w1"},
    {~U[2022-01-01 13:05:19Z], "w1"}
  ]

  _out = %{
    ~U[2022-01-01 12:00:00Z] => %{"w1" => 60},
    ~U[2022-01-01 13:00:00Z] => %{"w1" => 61}
  }

  # so need to check
  # - projects are the same as before
  # - hour(time) == hour(start_time)
  #     if so, check for same project, same duration (time - prev_time < 300)
  #     if not, check for same project, same duration (time - prev_time < 300)
  #       if so, need to split the ongoing duration cleanly between hours
  #         start_time = start_of_new_hour
  #         prev_hour = nil
  #         inner_acc = Map.update(inner_acc, prev_project, start_of_new_hour - prev_time, fn prev_total -> prev_total + start_of_new_hour - prev_time end)
  #         outer_acc = Map.put(outer_acc, prev_time_hour, inner_acc)
  #         inner_acc = %{}
  #   if not, move inner_acc into outer_acc, inner_acc = %{}, start_time = nil,
  # - current duration, time - prev_time < 300 (5 min)

  defp hourly_totals(
         [{time, project} | heartbeats],
         start_time,
         prev_time,
         prev_project,
         inner_acc,
         outer_acc
       ) do
    if start_time do
      if prev_time do
        hour = div(time, 3600)
        prev_hour = div(prev_time, 3600)

        if project == prev_project do
          if hour == prev_hour do
          else
          end
        end
      else
        # no prev heartbeat
        # check for same hour
        # check for same project
        # check that within 300 sec of each other
        hourly_totals(heartbeats, start_time, time, prev_project, inner_acc, outer_acc)
      end
    else
      hourly_totals(heartbeats, start_time, _prev_time = nil, project, inner_acc, outer_acc)
    end
  end

  defp time(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp time(unix) when is_integer(unix) or is_float(unix), do: unix
  defp time(%Date{} = date), do: time(DateTime.new!(date, Time.new!(0, 0, 0)))
end
