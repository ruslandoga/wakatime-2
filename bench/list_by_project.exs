alias Exqlite.Sqlite3

{:ok, conn} = Sqlite3.open(W2.Repo.config()[:database])
{:ok, stmt} = Sqlite3.prepare(conn, "select time from heartbeats order by time asc")

defmodule Durations do
  def compute(conn, stmt, start_time, prev_time, durations) do
    case Sqlite3.step(conn, stmt) do
      {:row, [time]} ->
        if start_time do
          if prev_time do
            if time - prev_time > 300 do
              compute(conn, stmt, time, nil, [{start_time, prev_time} | durations])
            else
              compute(conn, stmt, start_time, time, durations)
            end
          else
            compute(conn, stmt, start_time, time, durations)
          end
        else
          compute(conn, stmt, time, prev_time, durations)
        end

      :done ->
        durations
    end
  end
end

Benchee.run(
  %{
    "window" => fn ->
      W2.Durations.list_by_project(
        _from = ~U[2022-05-30 10:00:00Z],
        _to = ~U[2022-05-31 10:00:00Z]
      )
    end,
    "elixir" => fn ->
      Durations.compute(conn, stmt, nil, nil, [])
    end
  },
  memory_time: 2
)
