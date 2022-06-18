defmodule W2.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias W2.Repo

      import Plug.{Conn, Test}
      import W2.ConnCase
    end
  end

  setup tags do
    W2.DataCase.setup_sandbox(tags)
    :ok
  end

  @endpoint W2.Endpoint
  @opts @endpoint.init([])

  def dispatch(conn) do
    @endpoint.call(conn, @opts)
  end

  def json_response(conn, status) do
    assert conn.state == :sent
    assert conn.status == status
    assert ["application/json; charset=utf-8"] = Plug.Conn.get_resp_header(conn, "content-type")
    Jason.decode!(conn.resp_body)
  end
end
