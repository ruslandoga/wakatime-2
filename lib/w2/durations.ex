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
  Translates naive datetime to MSK.

      iex> msk(~N[2022-07-08 14:05:20.134483])
      #DateTime<2022-07-08 17:05:20.134483+03:00 MSK Europe/Moscow>

  """
  def msk(naive \\ NaiveDateTime.utc_now()) do
    naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.shift_zone!("Europe/Moscow")
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
  Returns unix timstampts for MSK midnights within the date range.
  """
  def midnights(from, to, utc_offset) do
    start = div(from, @h24) * @h24 + @h24 - utc_offset
    _midnights(start, to)
  end

  defp _midnights(date, to) when date < to, do: [date | _midnights(date + @h24, to)]
  defp _midnights(_date, _to), do: []

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
