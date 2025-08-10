defmodule W2.Durations do
  @moduledoc """
  Contains functions to aggregate durations
  """

  @doc """
  Translates naive datetime to local timezone depending on the date and relocations.

      iex> relocations = [{~D[2022-01-01], "Europe/Moscow"}, {~D[2022-08-28], "Asia/Tbilisi"}]
      iex> to_local(~N[2022-07-08 14:05:20.134483], relocations)
      #DateTime<2022-07-08 17:05:20.134483+03:00 MSK Europe/Moscow>

      iex> relocations = [{~D[2022-01-01], "Europe/Moscow"}, {~D[2022-08-28], "Asia/Tbilisi"}, {~D[2022-10-08], "Asia/Bangkok"}]
      iex> to_local(~N[2022-08-29 14:05:20.134483], relocations)
      #DateTime<2022-08-29 18:05:20.134483+04:00 +04 Asia/Tbilisi>

      iex> relocations = [{~D[2022-08-28], "Asia/Tbilisi"}, {~D[2022-10-08], "Asia/Bangkok"}]
      iex> to_local(~N[2022-10-09 14:05:20.134483], relocations)
      #DateTime<2022-10-09 21:05:20.134483+07:00 +07 Asia/Bangkok>

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
  @spec fetch_timeline([
          {:project, String.t()}
          | {:category, String.t()}
          | {:type, String.t()}
          | {:branch, String.t()}
          | {:entity, String.t()}
          | {:from, Date.t()}
          | {:to, Date.t()}
          | {:interval, Duration.t()}
          | {:parquet, Path.t() | [Path.t()]}
        ]) :: [
          {
            project :: String.t(),
            start_time :: pos_integer,
            end_time :: pos_integer
          }
        ]
  def fetch_timeline(opts \\ []) do
    interval = opts[:interval] || W2.interval()
    parquet = opts[:parquet] || W2.parquet()

    {where, params} = duck_where(opts, [:from, :to, :project, :category, :type, :branch, :entity])
    params = Map.merge(params, %{"parquet" => parquet, "interval" => interval})

    sql =
      """
      with base as (
        select coalesce(project, '(none)') AS project, epoch(time)::int64 as time
        from read_parquet($parquet) #{where} order by time
      ), marked as (
        select
          project, time,
          case
            when
              project != lag(project) over w
              or (time - lag(time) over w) >= epoch($interval)::int32
            then 1
            else 0
          end as is_new_group
        from base window w as (order by time)
      ), grouped as (
        select project, time, sum(is_new_group) over (order by time) as group_id from marked
      )
      select project, min(time) as start_time, max(time) as end_time from grouped
      group by project, group_id
      order by start_time
      """

    rows = W2.duck_q(sql, params)

    Enum.map(rows, fn %{"project" => project, "start_time" => start_time, "end_time" => end_time} ->
      {project, start_time, end_time}
    end)
  end

  @doc """
  Aggregates durations into time spent per project.
  """
  @spec fetch_projects([
          {:category, String.t()}
          | {:type, String.t()}
          | {:editor, String.t()}
          | {:from, Date.t()}
          | {:to, Date.t()}
          | {:interval, Duration.t()}
          | {:parquet, Path.t() | [Path.t()]}
        ]) :: [
          %{
            project: String.t(),
            category: String.t(),
            type: String.t(),
            duration: non_neg_integer
          }
        ]
  def fetch_projects(opts \\ []) do
    interval = opts[:interval] || W2.interval()
    parquet = opts[:parquet] || W2.parquet()

    {where1, params1} = duck_where(opts, [:from, :to])
    {where2, params2} = duck_where(opts, [:project, :category, :type])

    params =
      %{"interval" => interval, "parquet" => parquet}
      |> Map.merge(params1)
      |> Map.merge(params2)

    sql =
      """
      select project, category, type, coalesce(sum(duration)::int64, 0) as duration
      from (
        select
          project, category, type, epoch(time) as time,
          lead(time) over (order by time) as next,
          next - time as raw_duration,
          epoch(case
            when raw_duration < $interval
            then raw_duration
            else interval '0 seconds'
          end)::int32 as duration
        from read_parquet($parquet)
        #{where1}
      )
      #{where2}
      group by project, category, type
      order by duration desc
      """

    W2.duck_q(sql, params)
  end

  @doc """
  Aggregates durations into time spent per branch.
  """
  @spec fetch_branches([
          {:project, String.t()}
          | {:from, Date.t()}
          | {:to, Date.t()}
          | {:interval, Duration.t()}
          | {:parquet, Path.t() | [Path.t()]}
        ]) :: [%{project: String.t(), branch: String.t(), duration: non_neg_integer}]
  def fetch_branches(opts \\ []) do
    interval = opts[:interval] || W2.interval()
    parquet = opts[:parquet] || W2.parquet()

    {where1, params1} = duck_where(opts, [:from, :to])
    {where2, params2} = duck_where(opts, [:project])

    params =
      %{"interval" => interval, "parquet" => parquet}
      |> Map.merge(params1)
      |> Map.merge(params2)

    sql = """
    select project, branch, coalesce(sum(duration)::int64, 0) as duration
    from (
      select
        project, branch, epoch(time) as time,
        lead(time) over (order by time) as next,
        next - time as raw_duration,
        epoch(case
          when raw_duration < $interval
          then raw_duration
          else interval '0 seconds'
        end)::int32 as duration
      from read_parquet($parquet)
      #{where1}
    )
    #{where2}
    group by project, branch
    having branch is not null and branch != '<<LAST_BRANCH>>'
    order by duration desc
    limit 50
    """

    W2.duck_q(sql, params)
  end

  @doc """
  Aggregates durations into time spent per file.
  """
  @spec fetch_entities([
          {:project, String.t()}
          | {:category, String.t()}
          | {:type, String.t()}
          | {:branch, String.t()}
          | {:from, Date.t()}
          | {:to, Date.t()}
          | {:interval, Duration.t()}
          | {:parquet, Path.t() | [Path.t()]}
        ]) :: %{
          project: String.t(),
          category: String.t(),
          type: String.t(),
          entity: String.t(),
          duration: non_neg_integer
        }
  def fetch_entities(opts \\ []) do
    interval = opts[:interval] || W2.interval()
    parquet = opts[:parquet] || W2.parquet()

    {where1, params1} = duck_where(opts, [:from, :to])
    {where2, params2} = duck_where(opts, [:project, :category, :type, :branch])

    params =
      %{"interval" => interval, "parquet" => parquet}
      |> Map.merge(params1)
      |> Map.merge(params2)

    sql = """
    select
      coalesce(project, '(none)') as project,
      coalesce(entity, '(none)') as entity,
      category,
      type,
      coalesce(sum(duration)::int64, 0) as duration
    from (
      select
        project, entity, category, type, branch,
        lead(time) over (order by time) as next,
        next - time as raw_duration,
        epoch(case
          when raw_duration < $interval
          then raw_duration
          else interval '0 seconds'
        end)::int32 as duration
      from read_parquet($parquet)
      #{where1}
    )
    #{where2}
    group by project, entity, category, type
    order by duration desc
    limit 50
    """

    W2.duck_q(sql, params)
  end

  defp duck_where(opts, keys) do
    case Keyword.take(opts, keys) do
      [] ->
        {"", %{}}

      filters ->
        filters = Enum.reject(filters, fn {_, v} -> is_nil(v) end)

        if filters == [] do
          {"", %{}}
        else
          conds =
            Enum.map_intersperse(filters, " and ", fn
              {k, "(none)"} -> "#{k} is null"
              {:from, _} -> "time >= $from"
              {:to, _} -> "time <= $to"
              {k, _} when k in [:entity, :editor] -> "#{k} like $#{k}"
              {k, _} -> "#{k} = $#{k}"
            end)

          where = IO.iodata_to_binary(["where " | conds])

          params =
            filters
            |> Enum.reject(fn {_, v} -> v == "(none)" end)
            |> Map.new(fn {k, v} -> {Atom.to_string(k), prepare_param(k, v)} end)

          {where, params}
        end
    end
  end

  defp prepare_param(k, v) when k in [:entity, :editor], do: "%" <> v
  defp prepare_param(_k, v), do: v

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
  def fetch_bucket_data(from, to, parquet \\ "heartbeats.parquet.zst") do
    timeline = fetch_timeline(from: from, to: to, parquet: parquet)
    interval = interval(from, to)

    timeline
    |> bucket_totals2(nil, interval, nil, [])
    |> :lists.reverse()
  end

  # TODO
  @doc false
  def bucket_totals2([{project, from, to} | rest], prev_bucket, interval, inner_acc, outer_acc) do
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
          [{project, clamped_to, to} | rest],
          prev_bucket,
          interval,
          inner_acc,
          outer_acc
        )

      bucket(from, interval) == bucket(to, interval) ->
        bucket = bucket(from, interval)

        outer_acc =
          if inner_acc do
            [{prev_bucket * interval, inner_acc} | outer_acc]
          else
            outer_acc
          end

        inner_acc = %{project => to - from}
        bucket_totals2(rest, bucket, interval, inner_acc, outer_acc)

      true ->
        bucket = bucket(from, interval)
        clamped_to = (bucket + 1) * interval

        outer_acc =
          if inner_acc do
            [{prev_bucket * interval, inner_acc} | outer_acc]
          else
            outer_acc
          end

        inner_acc = %{project => clamped_to - from}
        bucket_totals2([{project, clamped_to, to} | rest], bucket, interval, inner_acc, outer_acc)
    end
  end

  def bucket_totals2([], prev_bucket, interval, inner_acc, outer_acc) do
    [{prev_bucket * interval, inner_acc} | outer_acc]
  end
end
