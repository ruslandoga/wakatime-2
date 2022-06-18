defmodule W2.DashboardTest do
  use W2.ConnCase

  describe "GET /" do
    test "with range filter" do
      insert_heartbeats([
        %{time: unix(~U[2022-01-01 12:04:12Z]), project: "w1"},
        %{time: unix(~U[2022-01-01 12:04:13Z]), project: "w1"},
        %{time: unix(~U[2022-01-01 12:04:18Z]), project: "w1"},
        %{time: unix(~U[2022-01-01 12:04:19Z]), project: "w2"},
        %{time: unix(~U[2022-01-01 12:05:19Z]), project: "w2"}
      ])

      conn =
        conn(:get, "/?from=2022-01-01&to=2022-01-01")
        # TODO
        |> put_req_header("accept", "text/html")
        |> dispatch()

      assert conn.state == :sent
      assert conn.status == 200
      assert ["text/html"] = Plug.Conn.get_resp_header(conn, "content-type")
      assert conn.resp_body =~ "<title>00:01:07</title>"
      assert conn.resp_body =~ "<span>Total 00:01:07</span>"
    end
  end

  defp unix(dt) do
    DateTime.to_unix(dt)
  end

  @default_heartbeat %{
    branch: "add-ingester",
    category: "coding",
    cursorpos: 1,
    dependencies: nil,
    editor: "vscode/1.68.0-insider",
    entity: "/Users/q/Developer/copycat/w1/lib/w1/endpoint.ex",
    is_write: 1,
    language: "Elixir",
    lineno: 31,
    lines: 64,
    operating_system: "darwin-21.4.0-arm64",
    project: "w1",
    # TODO
    time: 1_653_576_798.5958169,
    type: "file"
  }

  defp insert_heartbeats(heartbeats) do
    heartbeats =
      Enum.map(heartbeats, fn heartbeat ->
        Map.merge(@default_heartbeat, heartbeat)
      end)

    W2.Repo.insert_all("heartbeats", heartbeats)
  end
end
