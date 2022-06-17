defmodule W2.Router do
  @moduledoc false
  use Plug.Router
  # TODO sentry?
  use Plug.ErrorHandler
  import W2.Plugs

  plug Plug.Logger
  plug :match
  # TODO need urlencoded?
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :dispatch

  # TODO
  # plug :put_secure_browser_headers

  get "/", do: dashboard(conn)

  get "/barchart.svg", do: svg_barchart(conn)
  get "/bucket-timeline.svg", do: svg_bucket_timeline(conn)
  get "/svg-test", do: svg_test(conn)

  get "/data", do: api_data(conn)

  post "/heartbeats", do: conn |> auth() |> heartbeats_ingest()
  post "/heartbeats/v1/users/current/heartbeats.bulk", do: conn |> auth() |> heartbeats_ingest()
  post "/users/current/heartbeats.bulk", do: conn |> auth() |> heartbeats_ingest()
  post "/plugins/errors", do: conn |> auth() |> heartbeats_ignore()

  match _, do: send_resp(conn, 404, "Not found")

  defp handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "Something went wrong")
  end
end
