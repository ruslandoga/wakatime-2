defmodule W2.Durations do
  @moduledoc """
  Contains functions to turn discreet heartbeats
  into continuous durations and other aggregations
  """

  alias W2.Repo
  import Ecto.Query

  # TODO from = div(from, 3600), to = div(to, 3600) + 1

  @doc """
  """
  def fetch_dashboard_data(from, to) do
    timeline = fetch_timeline(from, to)
    project_totals = project_totals_from_timeline(timeline)

    %{
      timeline: timeline,
      total: Enum.reduce(project_totals, 0, fn {_project, total}, acc -> acc + total end),
      projects: project_totals
    }
  end

  @doc false
  def project_totals_from_timeline(timeline) do
    project_totals_from_timeline(timeline, %{})
  end

  defp project_totals_from_timeline([[project, from, to] | rest], acc) do
    acc = Map.update(acc, project, to - from, fn prev -> prev + to - from end)
    project_totals_from_timeline(rest, acc)
  end

  defp project_totals_from_timeline([], acc), do: acc

  @doc """
  """
  def fetch_timeline(from, to) do
    csv =
      "heartbeats"
      |> select([_], fragment("timeline_csv(time, project)"))
      |> where([h], h.time > ^time(from))
      |> where([h], h.time < ^time(to))
      # TODO
      |> where([h], not is_nil(h.project))
      |> Repo.one!()

    csv
    |> String.split("\n", trim: true)
    |> Enum.map(fn row ->
      [project, from, to] = String.split(row, ",")
      [project, String.to_integer(from), String.to_integer(to)]
    end)
  end

  @h24 24 * 60 * 60

  @doc """
  """
  def day_starts(from, to) do
    start = div(from, @h24) * @h24 + @h24
    _day_starts(start, to)
  end

  defp _day_starts(date, to) when date < to, do: [date | _day_starts(date + @h24, to)]
  defp _day_starts(_date, _to), do: []

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

  @doc """
  """
  def fetch_bucket_data(from, to) do
    timeline = fetch_timeline(from, to)
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
          if inner_acc, do: [[bucket * interval, inner_acc] | outer_acc], else: outer_acc

        inner_acc = %{project => to - from}
        bucket_totals2(rest, bucket, interval, inner_acc, outer_acc)

      true ->
        bucket = bucket(from, interval)
        clamped_to = (bucket + 1) * interval

        outer_acc =
          if inner_acc, do: [[bucket * interval, inner_acc] | outer_acc], else: outer_acc

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
