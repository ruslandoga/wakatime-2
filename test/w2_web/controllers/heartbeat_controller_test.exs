defmodule W2Web.HeartbeatControllerTest do
  use W2Web.ConnCase

  test "POST /heartbeats", %{conn: conn} do
    conn =
      post(conn, "/heartbeats", %{
        "_json" => [
          %{
            "branch" => "add-ingester",
            "category" => "coding",
            "cursorpos" => 1,
            "dependencies" => nil,
            "entity" => "/Users/q/Developer/copycat/w1/test/endpoint_test.exs",
            "is_write" => nil,
            "language" => "Elixir",
            "lineno" => 1,
            "lines" => 4,
            "project" => "w1",
            "time" => 1_653_576_917.486633,
            "type" => "file",
            "user_agent" =>
              "wakatime/v1.45.3 (darwin-21.4.0-arm64) go1.18.1 vscode/1.68.0-insider vscode-wakatime/18.1.5"
          }
        ]
      })

    assert json_response(conn, 201) == %{"responses" => [[nil, 201]]}
    assert W2.Repo.aggregate("heartbeats", :count) == 1
  end
end
