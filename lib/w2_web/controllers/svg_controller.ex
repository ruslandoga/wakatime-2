defmodule W2Web.SVGController do
  use W2Web, :controller
  alias W2.Durations

  @days 7

  # TODO use params
  def barchart(conn, params) do
    # TODO div
    to = DateTime.from_naive!(NaiveDateTime.utc_now(), "Etc/UTC")
    from = DateTime.from_naive!(add_days(to, -@days), "Etc/UTC")
    buckets = Durations.bucket_data(from, to)
    to = DateTime.to_unix(to)
    from = DateTime.to_unix(from)
    from_div = div(from, 3600)
    interval = Durations.interval(from, to)
    bars = W2Web.DashboardView.prepare_chart_for_svg(from, interval, buckets)

    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> render(:barchart,
      bars: bars,
      from_div: from_div,
      interval: interval,
      day_starts: Durations.day_starts(from, to),
      width: params["width"] || 500,
      height: params["height"] || 250,
      background: params["background"] || "#0000"
    )
  end

  @spec add_days(NaiveDateTime.t(), integer) :: NaiveDateTime.t()
  defp add_days(naive, days) do
    time = Time.new!(naive.hour, naive.minute, naive.second)

    Date.new!(naive.year, naive.month, naive.day)
    |> Date.add(days)
    |> NaiveDateTime.new!(time)
  end
end
