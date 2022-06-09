alias Exqlite.Sqlite3

{:ok, conn} = Sqlite3.open(W2.Repo.config()[:database])
{:ok, stmt} = Sqlite3.prepare(conn, "select time from heartbeats order by time asc")

defmodule Durations do
  def step(conn, stmt, start_time, prev_time, durations) do
    case Sqlite3.step(conn, stmt) do
      {:row, [time]} ->
        if start_time do
          if prev_time do
            if time - prev_time > 300 do
              step(conn, stmt, time, nil, [{start_time, prev_time} | durations])
            else
              step(conn, stmt, start_time, time, durations)
            end
          else
            step(conn, stmt, start_time, time, durations)
          end
        else
          step(conn, stmt, time, prev_time, durations)
        end

      :done ->
        durations
    end
  end

  def multi_step(conn, stmt, start_time, prev_time, durations) do
    case Sqlite3.multi_step(conn, stmt, 500) do
      {:rows, rows} -> multi_step_cont(rows, start_time, prev_time, durations, conn, stmt)
      {:done, rows} -> multi_step_end(rows, start_time, prev_time, durations)
    end
  end

  defp multi_step_cont([[time] | rest], start_time, prev_time, durations, conn, stmt) do
    if start_time do
      if prev_time do
        if time - prev_time > 300 do
          multi_step_cont(rest, time, nil, [{start_time, prev_time} | durations], conn, stmt)
        else
          multi_step_cont(rest, start_time, time, durations, conn, stmt)
        end
      else
        multi_step_cont(rest, start_time, time, durations, conn, stmt)
      end
    else
      multi_step_cont(rest, time, prev_time, durations, conn, stmt)
    end
  end

  defp multi_step_cont([], start_time, prev_time, durations, conn, stmt) do
    multi_step(conn, stmt, start_time, prev_time, durations)
  end

  defp multi_step_end([[time] | rest], start_time, prev_time, durations) do
    if start_time do
      if prev_time do
        if time - prev_time > 300 do
          multi_step_end(rest, time, nil, [{start_time, prev_time} | durations])
        else
          multi_step_end(rest, start_time, time, durations)
        end
      else
        multi_step_end(rest, start_time, time, durations)
      end
    else
      multi_step_end(rest, time, prev_time, durations)
    end
  end

  defp multi_step_end([], start_time, prev_time, durations) do
    [{start_time, prev_time} | durations]
  end
end

# TODO
# {:ok, duration_stmt} = Sqlite3.prepare(conn, "select duration(time) from heartbeats")

count = W2.Repo.aggregate("heartbeats", :count)
IO.puts("heartbeats count=#{count}\n")

Benchee.run(
  %{
    "window" => fn ->
      W2.Durations.list_by_project()
    end,
    "step" => fn ->
      Durations.step(conn, stmt, nil, nil, [])
    end,
    "elixir" => fn ->
      W2.Durations.total_data(~D[0000-01-01], ~D[2025-01-01])
    end,
    "multi_step" => fn ->
      Durations.multi_step(conn, stmt, nil, nil, [])
    end,
    "extension" => fn ->
      W2.Repo.query!("select duration(time) from heartbeats", [])
    end
  },
  memory_time: 2
)
