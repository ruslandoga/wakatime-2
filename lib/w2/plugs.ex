defmodule W2.Plugs do
  @moduledoc false
  alias W2.{Durations, DashboardView}
  import Plug.Conn
  require Logger
  require EEx

  @days 7

  EEx.function_from_file(
    :defp,
    :dashboard_html,
    "lib/w2/templates/dashboard.html.eex",
    [:assigns],
    engine: Phoenix.HTML.Engine
  )

  def dashboard(%Plug.Conn{params: %{"from" => from, "to" => to}} = conn) do
    with {:ok, from} <- Date.from_iso8601(from),
         {:ok, to} <- Date.from_iso8601(to) do
      from = NaiveDateTime.new!(from, ~T[00:00:00])
      to = NaiveDateTime.new!(to, ~T[23:59:59])
      assigns = %{} |> set_date_range(from, to) |> fetch_data()
      html = assigns |> dashboard_html() |> Phoenix.HTML.Engine.encode_to_iodata!()

      conn
      |> put_resp_header("content-type", "text/html")
      |> send_resp(200, html)
    else
      _ -> redirect(conn, "/")
    end
  end

  def dashboard(conn) do
    assigns = %{} |> reset_date_range() |> fetch_data()
    html = assigns |> dashboard_html() |> Phoenix.HTML.Engine.encode_to_iodata!()

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, html)
  end

  defp reset_date_range(assigns) do
    to = NaiveDateTime.utc_now()
    from = add_days(to, -@days)
    set_date_range(assigns, from, to)
  end

  defp redirect(conn, url) do
    href = Plug.HTML.html_escape(url)

    # TODO
    body = ["<html><body>You are being <a href=\"", href, "\">redirected</a>.</body></html>"]

    conn
    |> put_resp_header("location", url)
    |> put_resp_header("content-type", "text/html")
    |> send_resp(conn.status || 302, body)
  end

  defp set_date_range(assigns, from, to) do
    Map.merge(assigns, %{from: from, to: to})
  end

  defp fetch_data(assigns) do
    to = DateTime.from_naive!(assigns.to, "Etc/UTC")
    from = DateTime.from_naive!(assigns.from, "Etc/UTC")

    %{total: total, projects: projects, timeline: timeline} =
      Durations.fetch_dashboard_data(from, to)

    # TODO
    projects = Enum.sort_by(projects, fn {_project, time} -> time end, :desc)

    assigns =
      Map.merge(assigns, %{
        total: total,
        projects: projects,
        timeline: timeline,
        page_title: format_time(total)
      })

    to = DateTime.to_unix(to)
    from = DateTime.to_unix(from)
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    rects =
      assigns.timeline
      |> DashboardView.bucket_timeline(interval)
      |> DashboardView.prepare_bucket_timeline_for_svg(from, interval)

    Map.merge(assigns, %{
      interval: interval,
      rects: rects,
      day_starts: Durations.day_starts(from, to),
      from_div: from_div,
      h_count: div(to, interval) - div(from, interval) + 1
    })
  end

  def api_data(%Plug.Conn{params: params} = conn) do
    to = parse_date_time(params["to"]) || NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    from = parse_date_time(params["from"]) || add_days(to, -@days)

    data =
      Durations.fetch_dashboard_data(from, to)
      |> Map.put("from", NaiveDateTime.to_iso8601(from))
      |> Map.put("to", NaiveDateTime.to_iso8601(to))

    json(conn, data)
  end

  def auth(conn) do
    with ["Basic " <> basic] <- get_req_header(conn, "authorization"),
         {:ok, api_key} <- Base.decode64(basic, padding: false),
         true <- Plug.Crypto.secure_compare(api_key, W2.api_key()) do
      conn
    else
      _ ->
        conn
        |> put_resp_header("www-authenticate", "Basic")
        |> resp(401, "Unauthorized")
        |> halt()
    end
  end

  def heartbeats_ingest(%Plug.Conn{params: params, halted: halted} = conn) do
    # TODO
    if halted do
      conn
    else
      %{"_json" => heartbeats} = params

      [machine_name] = get_req_header(conn, "x-machine-name")
      _ = W2.Ingester.insert_heartbeats(heartbeats, machine_name)

      conn
      |> put_status(201)
      |> json(ingest_response(heartbeats))
    end
  end

  def heartbeats_ignore(%Plug.Conn{params: params} = conn) do
    %{"logs" => logs} = params

    logs
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
    |> Enum.each(fn %{"level" => level} = log -> Logger.log(log_level(level), log) end)

    send_resp(conn, 201, [])
  end

  EEx.function_from_file(
    :defp,
    :barchart_svg,
    "lib/w2/templates/barchart.svg.eex",
    [:assigns],
    engine: Phoenix.HTML.Engine
  )

  EEx.function_from_file(
    :defp,
    :bucket_timeline_svg,
    "lib/w2/templates/bucket_timeline.svg.eex",
    [:assigns],
    engine: Phoenix.HTML.Engine
  )

  EEx.function_from_file(
    :defp,
    :test_html,
    "lib/w2/templates/test.html.eex",
    [],
    engine: Phoenix.HTML.Engine
  )

  # TODO use params
  def svg_barchart(%Plug.Conn{params: params} = conn) do
    # TODO div
    to = :os.system_time(:second)
    from = to - @days * 24 * 3600
    buckets = Durations.fetch_bucket_data(from, to)
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    bars = DashboardView.prepare_chart_for_svg(from, interval, buckets)

    conn
    |> put_svg_headers()
    |> send_resp(
      200,
      barchart_svg(%{
        bars: bars,
        from_div: from_div,
        interval: interval,
        day_starts: Durations.day_starts(from, to),
        background: params["b"]
      })
    )
  end

  def svg_bucket_timeline(%Plug.Conn{params: params} = conn) do
    to = :os.system_time(:second)
    from = to - @days * 24 * 3600
    timeline = Durations.fetch_timeline(from, to)
    interval = Durations.interval(from, to)
    from_div = div(from, interval)

    rects =
      timeline
      |> DashboardView.bucket_timeline(interval)
      |> DashboardView.prepare_bucket_timeline_for_svg(from, interval)

    conn
    |> put_svg_headers()
    |> send_resp(
      200,
      bucket_timeline_svg(%{
        rects: rects,
        from_div: from_div,
        interval: interval,
        day_starts: Durations.day_starts(from, to),
        background: params["b"]
      })
    )
  end

  def svg_test(conn) do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, test_html())
  end

  defp log_level("debug"), do: :debug
  defp log_level("error"), do: :error

  defp parse_date_time(value) do
    if value do
      case NaiveDateTime.from_iso8601(value) do
        {:ok, dt} -> dt
        _ -> nil
      end
    end
  end

  defp add_days(naive, days) do
    time = Time.new!(naive.hour, naive.minute, naive.second)

    Date.new!(naive.year, naive.month, naive.day)
    |> Date.add(days)
    |> NaiveDateTime.new!(time)
  end

  defp ingest_response(heartbeats) do
    case heartbeats do
      heartbeats when is_list(heartbeats) ->
        %{"responses" => Enum.map(heartbeats, fn _ -> [nil, 201] end)}

      %{} = heartbeat ->
        %{"data" => heartbeat}
    end
  end

  defp json(conn, data) do
    response = Jason.encode_to_iodata!(data)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, response)
  end

  defp put_svg_headers(conn) do
    conn
    |> put_resp_header("content-type", "image/svg+xml")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'unsafe-inline'; sandbox"
    )
  end

  @colors [
    "#fbbf24",
    "#4ade80",
    "#06b6d4",
    "#f87171",
    "#60a5fa",
    "#facc15",
    "#ec4899",
    "#0284c7",
    "#a3a3a3"
  ]

  @colors_count length(@colors)

  # TODO
  defp color(project) do
    Enum.at(@colors, :erlang.phash2(project, @colors_count))
  end

  defp format_time(seconds) do
    hours = String.pad_leading(to_string(div(seconds, 3600)), 2, "0")
    rem = rem(seconds, 3600)
    minutes = String.pad_leading(to_string(div(rem, 60)), 2, "0")
    seconds = String.pad_leading(to_string(rem(rem, 60)), 2, "0")
    hours <> ":" <> minutes <> ":" <> seconds
  end
end
