defmodule W2.IngesterTest do
  use W2.DataCase
  alias W2.Ingester
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

    assert {1, nil} == Ingester.insert_heartbeats(heartbeats)

    assert fields(Repo.all(Heartbeat)) ==
             fields([
               %Heartbeat{
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
                 type: "file"
               }
             ])
  end

  defp fields(heartbeats) when is_list(heartbeats) do
    Enum.map(heartbeats, &fields/1)
  end

  defp fields(%Heartbeat{} = heartbeat) do
    Map.take(heartbeat, Heartbeat.__schema__(:fields))
  end
end
