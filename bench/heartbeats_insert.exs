defmodule Dummy do
  def heartbeat do
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
      "time" => :os.system_time(:nanosecond) / 1_000_000_000,
      "type" => "file",
      "user_agent" =>
        "wakatime/v1.45.3 (darwin-21.4.0-arm64) go1.18.1 vscode/1.68.0-insider vscode-wakatime/18.1.5"
    }
  end

  def heartbeats do
    [heartbeat()]
  end
end

Benchee.run(
  %{
    # "control" => fn -> Dummy.heartbeats() end,
    "insert_heartbeats" => fn ->
      W2.Ingester.insert_heartbeats(Dummy.heartbeats(), _machine_name = "mac3.local")
    end
  },
  memory_time: 2
)
