defmodule W2Web.SVGController do
  use W2Web, :controller
  alias W2.Durations

  @days 7

  # TODO use params
  def barchart(conn, _params) do
    # TODO div
    to = :os.system_time(:second)
    from = to - @days * 24 * 3600
    buckets = Durations.bucket_data(from, to) |> IO.inspect()
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    bars = W2Web.DashboardView.prepare_chart_for_svg(from, interval, buckets)

    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> put_resp_header("content-type", "image/svg+xml")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'unsafe-inline'; sandbox"
    )
    |> render(:barchart,
      bars: bars,
      from_div: from_div,
      interval: interval,
      day_starts: Durations.day_starts(from, to)
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

  # defp maybe_int(value) do
  #   if value do
  #     case Integer.parse(value) do
  #       {int, _} -> int
  #       _ -> nil
  #     end
  #   end
  # end
end
