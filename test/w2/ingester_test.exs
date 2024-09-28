defmodule W2.IngesterTest do
  use W2.DataCase
  alias W2.{Ingester, Durations}
  alias W2.Ingester.Heartbeat

  test "insert and read back" do
    heartbeats = [
      %{
        "branch" => "add-ingester",
        "category" => "coding",
        "cursorpos" => 1,
        "dependencies" => nil,
        "entity" => "/Users/q/Developer/copycat/w1/lib/w1/endpoint.ex",
        "is_write" => true,
        "language" => "Elixir",
        "lineno" => 31,
        "lines" => 64,
        "project" => "w1",
        "time" => 1_653_576_798.5958169,
        "type" => "file",
        # TODO
        "rubbish" => "is not saved",
        "user_agent" =>
          "wakatime/v1.45.3 (darwin-21.4.0-arm64) go1.18.1 vscode/1.68.0-insider vscode-wakatime/18.1.5"
      }
    ]

    machine_name = "mac3.local"
    :ok = Ingester.insert_heartbeats(heartbeats, machine_name)

    assert all(Heartbeat) ==
             [
               %{
                 branch: "add-ingester",
                 category: "coding",
                 cursorpos: 1,
                 dependencies: nil,
                 editor: "vscode/1.68.0-insider",
                 entity: "/Users/q/Developer/copycat/w1/lib/w1/endpoint.ex",
                 is_write: true,
                 language: "Elixir",
                 lineno: 31,
                 lines: 64,
                 operating_system: "darwin-21.4.0-arm64",
                 project: "w1",
                 # TODO
                 time: 1_653_576_798.5958169,
                 type: "file",
                 machine_name: "mac3.local"
               }
             ]

    assert Durations.fetch_timeline() == [{"w1", 1_653_576_798, 1_653_576_798}]

    assert Durations.fetch_projects() == [
             %{project: "w1", duration: 0, category: "coding", type: "file"}
           ]
  end

  test "project switch" do
    insert_heartbeats([
      %{"time" => unix(~U[2022-01-01 12:04:12Z]), "project" => "w1"},
      %{"time" => unix(~U[2022-01-01 12:04:13Z]), "project" => "w1"},
      %{"time" => unix(~U[2022-01-01 12:04:18Z]), "project" => "w1"},
      %{"time" => unix(~U[2022-01-01 12:04:19Z]), "project" => "w2"},
      %{"time" => unix(~U[2022-01-01 12:05:19Z]), "project" => "w2"}
    ])

    assert Durations.fetch_timeline() == [
             {"w1", unix(~U[2022-01-01 12:04:12Z]), unix(~U[2022-01-01 12:04:19Z])},
             {"w2", unix(~U[2022-01-01 12:04:19Z]), unix(~U[2022-01-01 12:05:19Z])}
           ]

    assert Durations.fetch_projects() == [
             %{project: "w2", duration: 60.0, category: "coding", type: "file"},
             %{project: "w1", duration: 7.0, category: "coding", type: "file"}
           ]
  end

  test "hour switch" do
    insert_heartbeats([
      %{"time" => unix(~U[2022-01-01 12:58:12Z]), "project" => "w1"},
      %{"time" => unix(~U[2022-01-01 12:59:13Z]), "project" => "w1"},
      %{"time" => unix(~U[2022-01-01 13:00:18Z]), "project" => "w1"}
    ])

    assert Durations.fetch_timeline() == [
             {"w1", unix(~U[2022-01-01 12:58:12Z]), unix(~U[2022-01-01 13:00:18Z])}
           ]

    assert Durations.fetch_projects() == [
             %{project: "w1", duration: 126.0, category: "coding", type: "file"}
           ]
  end

  test "duration break" do
    insert_heartbeats([
      %{"time" => unix(~U[2022-01-01 12:04:12Z]), "project" => "w1"},
      %{"time" => unix(~U[2022-01-01 12:05:12Z]), "project" => "w1"},
      %{"time" => unix(~U[2022-01-01 13:04:18Z]), "project" => "w1"},
      %{"time" => unix(~U[2022-01-01 13:04:19Z]), "project" => "w1"},
      %{"time" => unix(~U[2022-01-01 13:05:19Z]), "project" => "w1"}
    ])

    assert Durations.fetch_timeline() == [
             {"w1", unix(~U[2022-01-01 12:04:12Z]), unix(~U[2022-01-01 12:05:12Z])},
             {"w1", unix(~U[2022-01-01 13:04:18Z]), unix(~U[2022-01-01 13:05:19Z])}
           ]

    assert Durations.fetch_projects() == [
             %{project: "w1", duration: 60 + 61, category: "coding", type: "file"}
           ]
  end
end
