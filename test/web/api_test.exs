defmodule W2.APITest do
  use W2.ConnCase

  describe "GET /data" do
    test "with range filter" do
      insert_heartbeats([
        %{time: unix(~U[2022-01-01 12:04:12Z]), project: "w1"},
        %{time: unix(~U[2022-01-01 12:04:13Z]), project: "w1"},
        %{time: unix(~U[2022-01-01 12:04:18Z]), project: "w1"},
        %{time: unix(~U[2022-01-01 12:04:19Z]), project: "w2"},
        %{time: unix(~U[2022-01-01 12:05:19Z]), project: "w2"}
      ])

      conn =
        conn(:get, "/data?from=2022-01-01T12:04:00&to=2022-01-01T12:06:00")
        # TODO
        |> put_req_header("accept", "application/json")
        |> dispatch()

      assert json_response(conn, 200) == %{
               "from" => "2022-01-01T12:04:00",
               "to" => "2022-01-01T12:06:00",
               "total" => 67,
               "projects" => %{"w1" => 7, "w2" => 60},
               "timeline" => [
                 ["w1", 1_641_038_652, 1_641_038_659],
                 ["w2", 1_641_038_659, 1_641_038_719]
               ]
             }
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
