defmodule W2Web.APIControllerTest do
  use W2Web.ConnCase

  describe "GET /api/timeline" do
    test "with range filter", %{conn: conn} do
      insert_heartbeats([
        %{"time" => unix(~U[2022-01-01 12:04:12Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 12:04:13Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 12:04:18Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 12:04:19Z]), "project" => "w2"},
        %{"time" => unix(~U[2022-01-01 12:05:19Z]), "project" => "w2"}
      ])

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/timeline?from=2022-01-01T12:04:00&to=2022-01-01T12:06:00")

      assert json_response(conn, 200) == [
               ["w1", "add-ingester", 1_641_038_652, 1_641_038_659],
               ["w2", "add-ingester", 1_641_038_659, 1_641_038_719]
             ]
    end
  end
end
