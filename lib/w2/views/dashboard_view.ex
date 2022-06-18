defmodule W2.DashboardView do
  @moduledoc false

  def prepare_chart_for_svg(from, interval, buckets) do
    from = div(from, interval)

    Enum.flat_map(buckets, fn [time, totals] ->
      x = div(time, interval) - from

      {_, bars} =
        Enum.reduce(totals, {interval, []}, fn {project, total}, {h, acc} ->
          h = h - total
          {h, [%{x: x, y: h, project: project, height: total} | acc]}
        end)

      bars
    end)
  end

  def prepare_chart_for_svg(from, interval, _width, height, buckets) do
    from = div(from, interval)

    Enum.flat_map(buckets, fn [time, totals] ->
      x = div(time, interval) - from

      {_, bars} =
        Enum.reduce(totals, {interval, []}, fn {project, total}, {h, acc} ->
          h = h - total

          {h,
           [
             %{
               x: x,
               y: h / interval * height,
               project: project,
               height: total / interval * height
             }
             | acc
           ]}
        end)

      bars
    end)
  end

  @compile {:inline, bucket: 2}
  defp bucket(time, interval) do
    div(time, interval)
  end

  def bucket_timeline(timeline, interval) do
    bucket_timeline(timeline, interval, [])
  end

  defp bucket_timeline([[project, from, to] = segment | rest], interval, acc) do
    if bucket(from, interval) == bucket(to, interval) do
      bucket_timeline(rest, interval, [segment | acc])
    else
      bucket_timeline(rest, interval, split_segment(project, from, to, interval) ++ acc)
    end
  end

  defp bucket_timeline([], _interval, acc), do: acc

  defp split_segment(project, from, to, interval) do
    bucket_from = bucket(from, interval)

    if bucket_from == bucket(to, interval) do
      [[project, from, to]]
    else
      threshold = (bucket_from + 1) * interval
      [[project, from, threshold] | split_segment(project, threshold, to, interval)]
    end
  end

  def prepare_bucket_timeline_for_svg(timeline, from, interval) do
    begin = div(from, interval)

    Enum.map(timeline, fn [project, from, to] ->
      bucket = div(from, interval)
      %{x: bucket - begin, y: (bucket + 1) * interval - to, project: project, height: to - from}
    end)
  end
end
