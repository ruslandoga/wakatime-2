defmodule W2Web.Plugs.Auth do
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
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
