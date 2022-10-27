defmodule W2.Durations do
  @moduledoc """
  Contains functions to aggregate durations
  """

  alias W2.Repo
  import Ecto.Query

  def duration_table(interval \\ W2.interval()) do
    "durations_#{interval}"
  end

  @doc """
  Translates naive datetime to local timezone depending on the date and relocations.

      iex> relocations = [{~D[2002-01-01], "Europe/Moscow"}, {~D[2022-08-28], "Asia/Tbilisi"}]
      iex> to_local(~N[2022-07-08 14:05:20.134483], relocations)
      #DateTime<2022-07-08 17:05:20.134483+03:00 MSK Europe/Moscow>

      iex> relocations = [{~D[2002-01-01], "Europe/Moscow"}, {~D[2022-08-28], "Asia/Tbilisi"}, {~D[2022-10-08], "Asia/Bangkok"}]
      iex> to_local(~N[2022-08-29 14:05:20.134483], relocations)
      #DateTime<2022-08-29 18:05:20.134483+04:00 GET Asia/Tbilisi>

      iex> relocations = [{~D[2022-08-28], "Asia/Tbilisi"}, {~D[2022-10-08], "Asia/Bangkok"}]
      iex> to_local(~N[2022-10-09 14:05:20.134483], relocations)
      #DateTime<2022-10-09 21:05:20.134483+07:00 ICT Asia/Bangkok>

  """
  def to_local(
        naive \\ NaiveDateTime.utc_now(),
        relocations \\ Application.fetch_env!(:w2, :relocations)
      ) do
    naive_date = NaiveDateTime.to_date(naive)
    tz = local_tz(naive_date, relocations)
    naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.shift_zone!(tz)
  end

  def local_tz(date, relocations \\ Application.fetch_env!(:w2, :relocations))

  def local_tz(date, [{d1, tz} | [{d2, _} | _] = rest]) do
    fits? = Date.compare(date, d1) in [:gt, :eq] and Date.compare(date, d2) in [:lt, :eq]
    if fits?, do: tz, else: local_tz(date, rest)
  end

  def local_tz(date, [{d, tz}]) do
    fits? = Date.compare(date, d) in [:gt, :eq]
    if fits?, do: tz, else: raise("Couldn't find local tz for #{inspect(date)}")
  end

  # TODO from = div(from, 3600), to = div(to, 3600) + 1

  @doc """
  Aggregates durations into a project timeline.
  """
  def fetch_timeline(opts \\ []) do
    query =
      duration_table()
      |> date_range(opts)
      |> project(opts)
      |> branch(opts)
      |> file(opts)
      # TODO
      |> where([d], not is_nil(d.project))

    query =
      case opts[:group] do
        :branch ->
          query
          |> select([d], [
            d.project,
            d.branch,
            type(min(d.start), :integer),
            type(min(d.start) + sum(d.length), :integer)
          ])
          |> group_by([d], [d.id, d.project, d.branch])

        :file ->
          query
          |> select([d], [
            d.project,
            d.branch,
            d.entity,
            type(d.start, :integer),
            type(d.start + d.length, :integer)
          ])
          |> group_by([d], [d.id, d.project, d.branch, d.entity])

        _default_is_project ->
          query
          |> select([d], [
            d.project,
            type(min(d.start), :integer),
            type(min(d.start) + sum(d.length), :integer)
          ])
          |> group_by([d], [d.id, d.project])
      end

    Repo.all(query)
  end

  @doc """
  Aggregates durations into time spent per project.
  """
  def fetch_projects(opts \\ []) do
    duration_table()
    |> select([d], [d.project, sum(d.length)])
    |> date_range(opts)
    |> group_by([d], d.project)
    |> order_by([d], desc: sum(d.length))
    # TODO
    |> where([d], not is_nil(d.project))
    |> Repo.all()
  end

  defp date_range(query, opts) do
    # TODO where(query, [d], d.start - d.length > ^time(from))
    query = if from = opts[:from], do: where(query, [d], d.start > ^time(from)), else: query
    if to = opts[:to], do: where(query, [d], d.start < ^time(to)), else: query
  end

  defp project(query, opts) do
    if project = opts[:project], do: where(query, project: ^project), else: query
  end

  defp branch(query, opts) do
    if branch = opts[:branch], do: where(query, branch: ^branch), else: query
  end

  defp file(query, opts) do
    if file = opts[:file] do
      pattern = "%" <> file
      where(query, [d], like(d.entity, ^pattern))
    else
      query
    end
  end

  @doc """
  Aggregates durations into time spent per branch.
  """
  def fetch_branches(opts \\ []) do
    duration_table()
    |> date_range(opts)
    |> project(opts)
    |> order_by([d], desc: sum(d.length))
    |> group_by([d], [d.project, d.branch])
    |> select([d], [d.project, d.branch, sum(d.length)])
    # TODO
    |> where([d], not is_nil(d.branch))
    |> where([d], not is_nil(d.project))
    |> limit(50)
    |> Repo.all()
  end

  @doc """
  Aggregates durations into time spent per file.
  """
  def fetch_files(opts \\ []) do
    duration_table()
    |> date_range(opts)
    |> project(opts)
    |> branch(opts)
    |> order_by([d], desc: sum(d.length))
    |> group_by([d], [d.project, d.entity])
    # TODO
    |> where([d], not is_nil(d.entity))
    |> where([d], not is_nil(d.project))
    |> select([d], [d.project, d.entity, sum(d.length)])
    |> limit(50)
    |> Repo.all()
  end

  @h24 24 * 60 * 60

  @doc """
  Returns unix timstampts for midnights within the date range.
  """
  def midnights(from, to, relocations \\ Application.fetch_env!(:w2, :relocations)) do
    utc_offsets =
      Enum.map(relocations, fn {date, tz} ->
        dt = DateTime.new!(date, ~T[00:00:00], tz)
        {DateTime.to_unix(dt), dt.utc_offset}
      end)

    [{_unix, initial_utc_offset} | _] = utc_offsets = filter_utc_offsets(from, utc_offsets)
    start = div(from, @h24) * @h24 + @h24 - initial_utc_offset
    _midnights(start, to, utc_offsets)
  end

  defp filter_utc_offsets(ts, [{t1, _} | [{t2, _} | _] = rest] = all) do
    fits? = ts >= t1 and ts <= t2
    if fits?, do: all, else: filter_utc_offsets(ts, rest)
  end

  defp filter_utc_offsets(ts, [{t, _tz}] = all) do
    fits? = ts >= t
    if fits?, do: all, else: raise("Couldn't filter utc offsets for #{inspect(ts)}")
  end

  defp _midnights(date, to, [{_, _}, {dt, _} | _] = utc_offsets) when date < to and date < dt do
    [date | _midnights(date + @h24, to, utc_offsets)]
  end

  defp _midnights(date, to, [{dt, _}] = utc_offsets) when date < to and date > dt do
    [date | _midnights(date + @h24, to, utc_offsets)]
  end

  defp _midnights(date, to, [{_, o1} | [{_, o2} | _] = next_utc_offsets]) when date < to do
    [date | _midnights(date + @h24 + (o1 - o2), to, next_utc_offsets)]
  end

  defp _midnights(_date, _to, _utc_offsets), do: []

  @hour_in_seconds 3600
  # @day_in_seconds 24 * @hour_in_seconds

  @doc """
  Computes appropriate interval for aggregations from datetime range.

      iex> interval(~U[2022-01-01 00:00:00Z], ~U[2022-01-08 00:00:00Z])
      3600

      iex> interval(~U[2022-01-01 00:00:00Z], ~U[2022-01-07 00:00:00Z])
      3600

      iex> interval(~U[2022-01-01 00:00:00Z], ~U[2022-01-05 00:00:00Z])
      3600

      iex> interval(~U[2022-01-01 00:00:00Z], ~U[2022-01-01 23:00:00Z])
      3600

      iex> interval(~U[2022-01-01 00:00:00Z], ~U[2022-01-01 04:00:00Z])
      3600

  """
  def interval(_from, _to) do
    # diff = time(to) - time(from)

    # cond do
    #   # TODO years, months, weeks
    #   diff > 7 * @day_in_seconds -> @day_in_seconds
    #   diff > @day_in_seconds -> @hour_in_seconds
    #   diff > 12 * @hour_in_seconds -> 30 * 60
    #   diff > 6 * @hour_in_seconds -> 15 * 60
    #   diff > 3 * @hour_in_seconds -> 10 * 60
    #   diff > 1800 -> 60
    #   true -> 15
    # end
    @hour_in_seconds
  end

  @compile {:inline, bucket: 2}
  def bucket(time, interval) do
    div(time, interval)
  end

  @doc "Aggregates durations into 1-hour buckets"
  def fetch_bucket_data(from, to) do
    timeline = fetch_timeline(from: from, to: to)
    interval = interval(from, to)

    timeline
    |> bucket_totals2(nil, interval, nil, [])
    |> :lists.reverse()
  end

  # TODO
  @doc false
  def bucket_totals2([[project, from, to] | rest], prev_bucket, interval, inner_acc, outer_acc) do
    cond do
      prev_bucket == bucket(from, interval) and prev_bucket == bucket(to, interval) ->
        inner_acc = Map.update(inner_acc, project, to - from, fn prev -> prev + to - from end)
        bucket_totals2(rest, prev_bucket, interval, inner_acc, outer_acc)

      prev_bucket == bucket(from, interval) ->
        clamped_to = (prev_bucket + 1) * interval

        inner_acc =
          Map.update(inner_acc, project, clamped_to - from, fn prev ->
            prev + clamped_to - from
          end)

        bucket_totals2(
          [[project, clamped_to, to] | rest],
          prev_bucket,
          interval,
          inner_acc,
          outer_acc
        )

      bucket(from, interval) == bucket(to, interval) ->
        bucket = bucket(from, interval)

        outer_acc =
          if inner_acc,
            do: [[prev_bucket * interval, inner_acc] | outer_acc],
            else: outer_acc

        inner_acc = %{project => to - from}
        bucket_totals2(rest, bucket, interval, inner_acc, outer_acc)

      true ->
        bucket = bucket(from, interval)
        clamped_to = (bucket + 1) * interval

        outer_acc =
          if inner_acc,
            do: [[prev_bucket * interval, inner_acc] | outer_acc],
            else: outer_acc

        inner_acc = %{project => clamped_to - from}
        bucket_totals2([[project, clamped_to, to] | rest], bucket, interval, inner_acc, outer_acc)
    end
  end

  def bucket_totals2([], prev_bucket, interval, inner_acc, outer_acc) do
    [[prev_bucket * interval, inner_acc] | outer_acc]
  end

  defp time(%DateTime{} = dt), do: DateTime.to_unix(dt)

  defp time(%NaiveDateTime{} = dt),
    do: dt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

  defp time(unix) when is_integer(unix) or is_float(unix), do: unix
  defp time(%Date{} = date), do: time(DateTime.new!(date, Time.new!(0, 0, 0)))
end
