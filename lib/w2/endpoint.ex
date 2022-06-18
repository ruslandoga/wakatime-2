defmodule W2.Endpoint do
  @moduledoc false
  use Plug.Builder

  plug Plug.Static,
    at: "/",
    from: :w2,
    gzip: true,
    # TODO brotli
    only: ~w(assets fonts images favicon.ico robots.txt)

  # TODO
  plug Plug.Head
  plug W2.Router
end
