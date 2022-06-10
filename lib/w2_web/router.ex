defmodule W2Web.Router do
  use W2Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_root_layout, {W2Web.LayoutView, :root}
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug W2Web.Plugs.Auth
  end

  scope "/", W2Web do
    pipe_through :browser

    live "/", DashboardLive.Index, :index
    get "/barchart.svg", SVGController, :barchart
    get "/test.svg", SVGController, :test_svg
    get "/svg-test", SVGController, :test
  end

  scope "/", W2Web do
    pipe_through :api

    post "/heartbeats", HeartbeatController, :create
    post "/heartbeats/v1/users/current/heartbeats.bulk", HeartbeatController, :create
    post "/users/current/heartbeats.bulk", HeartbeatController, :create
    post "/plugins/errors", HeartbeatController, :ignore
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: W2Web.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
