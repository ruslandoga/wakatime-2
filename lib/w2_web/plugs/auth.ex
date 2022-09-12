defmodule W2Web.Auth do
  @moduledoc """
  Helpers to do web auth.
  """

  import Plug.Conn

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

  def dashboard_auth(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn, W2.dashboard_auth_opts())
  end
end
