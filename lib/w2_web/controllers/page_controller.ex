defmodule W2Web.PageController do
  use W2Web, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
