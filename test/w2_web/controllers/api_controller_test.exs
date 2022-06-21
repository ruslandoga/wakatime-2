defmodule W2Web.APIControllerTest do
  use W2Web.ConnCase

  describe "GET /data" do
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
        |> get("/data?from=2022-01-01T12:04:00&to=2022-01-01T12:06:00")

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
end
