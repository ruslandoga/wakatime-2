defmodule W2Web.SVGController do
  use W2Web, :controller
  alias W2.Durations

  @days 7

  # TODO cache

  # TODO use params
  def barchart(conn, params) do
    # TODO div
    to = :os.system_time(:second)
    from = to - @days * 24 * 3600
    buckets = Durations.fetch_bucket_data(from, to)
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    bars = W2Web.SVGHTML.prepare_chart_for_svg(from, interval, buckets)

    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> put_new_view(svg: W2Web.SVGHTML)
    |> put_resp_header("content-type", "image/svg+xml")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'unsafe-inline'; sandbox"
    )
    |> render("barchart.svg",
      bars: bars,
      from_div: from_div,
      interval: interval,
      day_starts: Durations.midnights(from, to),
      background: params["b"]
    )
  end

  def bucket_timeline(conn, params) do
    to = :os.system_time(:second)
    from = to - @days * 24 * 3600
    timeline = Durations.fetch_timeline(from: from, to: to)
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    rects =
      timeline
      |> W2Web.SVGHTML.bucket_timeline(interval)
      |> W2Web.SVGHTML.prepare_bucket_timeline_for_svg(from, interval)

    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> put_new_view(svg: W2Web.SVGHTML)
    |> put_resp_header("content-type", "image/svg+xml")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'unsafe-inline'; sandbox"
    )
    |> render("bucket_timeline.svg",
      rects: rects,
      from_div: from_div,
      interval: interval,
      day_starts: Durations.midnights(from, to),
      background: params["b"]
    )
  end

  def test(conn, _params) do
    render(conn, :test)
  end
end
