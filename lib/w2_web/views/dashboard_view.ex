defmodule W2Web.DashboardView do
  use W2Web, :view

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
end
