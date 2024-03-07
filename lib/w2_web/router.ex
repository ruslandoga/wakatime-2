defmodule W2Web.Router do
  use W2Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_root_layout, html: {W2Web.Layouts, :root}
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug :wakatime_auth
  end

  scope "/", W2Web do
    pipe_through :browser
    live "/", DashboardLive.Index, :index
    get "/barchart.svg", SVGController, :barchart
    get "/bucket-timeline.svg", SVGController, :bucket_timeline
    get "/test.svg", SVGController, :test_svg
    get "/svg-test", SVGController, :test
  end

  scope "/", W2Web do
    pipe_through [:api, :auth]

    post "/heartbeats", HeartbeatController, :create
    post "/heartbeats/v1/users/current/heartbeats.bulk", HeartbeatController, :create
    post "/users/current/heartbeats.bulk", HeartbeatController, :create
    post "/plugins/errors", HeartbeatController, :ignore
  end

  # TODO /api?
  scope "/api", W2Web do
    pipe_through :api
    get "/timeline", APIController, :timeline
    get "/projects", APIController, :timeline
    # /branches
    # /files
  end

  @doc false
  def wakatime_auth(conn, _opts) do
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
end
