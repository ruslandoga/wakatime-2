defmodule W2.HeartbeatsTest do
  use W2.ConnCase

  @payload Jason.encode!(%{
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

  describe "POST /heartbeats" do
    test "without api_key" do
      conn =
        conn(:post, "/heartbeats", @payload)
        |> put_req_header("content-type", "application/json")
        |> dispatch()

      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
      assert get_resp_header(conn, "www-authenticate") == ["Basic"]
      assert W2.Repo.aggregate("heartbeats", :count) == 0
    end

    test "with invalid api_key" do
      conn =
        conn(:post, "/heartbeats", @payload)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Basic #{Base.encode64("password", padding: false)}")
        |> dispatch()

      assert conn.status == 401
      assert conn.resp_body == "Unauthorized"
      assert get_resp_header(conn, "www-authenticate") == ["Basic"]
      assert W2.Repo.aggregate("heartbeats", :count) == 0
    end

    test "with valid api_key" do
      conn =
        conn(:post, "/heartbeats", @payload)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Basic #{Base.encode64(W2.api_key(), padding: false)}")
        |> put_req_header("x-machine-name", "mac3.local")
        |> dispatch()

      assert json_response(conn, 201) == %{"responses" => [[nil, 201]]}
      assert W2.Repo.aggregate("heartbeats", :count) == 1
    end
  end
end
