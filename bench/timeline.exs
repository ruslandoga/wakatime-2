alias Exqlite.Sqlite3

{:ok, conn} = Sqlite3.open(W2.Repo.config()[:database])
{:ok, stmt} = Sqlite3.prepare(conn, "select time from heartbeats order by time asc")

# TODO update to compute timelines, not totals
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

IO.inspect(heartbeats_count: W2.Repo.aggregate("heartbeats", :count))

Benchee.run(
  %{
    # "window" => fn ->
    #   W2.Durations.list_by_project()
    # end,
    # "step" => fn ->
    #   Durations.step(conn, stmt, nil, nil, [])
    # end,
    # "elixir" => fn ->
    #   # TODO
    # end,
    # "multi_step" => fn ->
    #   Durations.multi_step(conn, stmt, nil, nil, [])
    # end,
    "prepared" => fn ->
      W2.Durations.fetch_timeline(from: ~D[0000-01-01], to: ~D[2025-01-01])
    end
  },
  memory_time: 2
)

# [heartbeats_count: 232662]
# Operating System: macOS
# CPU Information: Apple M2
# Number of Available Cores: 8
# Available memory: 8 GB
# Elixir 1.18.1
# Erlang 27.2
# JIT enabled: true

# Benchmark suite executing with the following configuration:
# warmup: 2 s
# time: 5 s
# memory time: 2 s
# reduction time: 0 ns
# parallel: 1
# inputs: none specified
# Estimated total run time: 9 s

# Benchmarking prepared ...
# Calculating statistics...
# Formatting results...

# Name               ips        average  deviation         median         99th %
# prepared          6.04      165.53 ms    ±12.90%      167.83 ms      216.51 ms

# Memory usage statistics:

# Name        Memory usage
# prepared        92.61 MB

# **All measurements for memory usage were the same**
