defmodule W2Web.SVGController do
  use W2Web, :controller
  alias W2.Durations
  alias W2Web.DashboardView

  @days 7

  # TODO use params
  def barchart(conn, params) do
    # TODO div
    to = :os.system_time(:second)
    from = to - @days * 24 * 3600
    buckets = Durations.bucket_data(from, to)
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    bars = DashboardView.prepare_chart_for_svg(from, interval, buckets)

    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> put_resp_header("content-type", "image/svg+xml")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'unsafe-inline'; sandbox"
    )
    |> render("barchart.svg",
      bars: bars,
      from_div: from_div,
      interval: interval,
      day_starts: Durations.day_starts(from, to),
      background: params["b"]
    )
  end

  def bucket_timeline(conn, params) do
    to = :os.system_time(:second)
    from = to - @days * 24 * 3600
    timeline = Durations.timeline_data(from, to)
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    rects =
      timeline
      |> DashboardView.bucket_timeline(interval)
      |> DashboardView.prepare_bucket_timeline_for_svg(from, interval)

    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> put_resp_header("content-type", "image/svg+xml")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'unsafe-inline'; sandbox"
    )
    |> render("bucket_timeline.svg",
      rects: rects,
      from_div: from_div,
      interval: interval,
      day_starts: Durations.day_starts(from, to),
      background: params["b"]
    )
  end

  def test_svg(conn, _params) do
    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> put_resp_header("content-type", "image/svg+xml")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'unsafe-inline'; sandbox"
    )
    |> render("test.svg")
  end

  def test(conn, _params) do
    render(conn, :test)
  end
end
