alias Exqlite.Sqlite3

{:ok, conn} = Sqlite3.open(W2.Repo.config()[:database])
{:ok, stmt} = Sqlite3.prepare(conn, "select time from heartbeats order by time asc")

conn2 =
  case File.cp(W2.Repo.config()[:database], "w2_time_pkey.db") do
    :ok ->
      {:ok, conn2} = Sqlite3.open("w2_time_pkey.db")

      :ok =
        Sqlite3.execute(
          conn2,
          ~s[CREATE TABLE IF NOT EXISTS "heartbeats2" ("time" REAL primary key NOT NULL, "entity" TEXT NOT NULL, "type" TEXT NOT NULL, "category" TEXT, "project" TEXT, "branch" TEXT, "language" TEXT, "dependencies" TEXT, "lines" INTEGER, "lineno" INTEGER, "cursorpos" INTEGER, "is_write" INTEGER DEFAULT false NOT NULL, "editor" TEXT, "operating_system" TEXT) strict, without rowid]
        )

      :ok = Sqlite3.execute(conn2, "INSERT or ignore INTO heartbeats2 SELECT * FROM heartbeats")
      :ok = Sqlite3.execute(conn2, "drop table heartbeats")
      :ok = Sqlite3.execute(conn2, "ALTER TABLE heartbeats2 RENAME TO heartbeats")
      conn2

    {:error, _} ->
      {:ok, conn2} = Sqlite3.open("w2_time_pkey.db")
      conn2
  end

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

count = W2.Repo.aggregate("heartbeats", :count)
IO.puts("heartbeats count=#{count}\n")

:ok = Sqlite3.enable_load_extension(conn, true)
path = Path.join(:code.priv_dir(:w2), "timeline.sqlite3ext")
:ok = Sqlite3.execute(conn, "select load_extension('#{path}')")
:ok = Sqlite3.enable_load_extension(conn, false)

:ok = Sqlite3.enable_load_extension(conn2, true)
:ok = Sqlite3.execute(conn2, "select load_extension('#{path}')")
:ok = Sqlite3.enable_load_extension(conn2, false)

{:ok, timeline_stmt1} =
  Sqlite3.prepare(
    conn,
    "select timeline_csv(time, project) from heartbeats where project is not null order by time"
  )

{:ok, timeline_stmt2} =
  Sqlite3.prepare(
    conn,
    "select timeline_csv(time, project) from heartbeats where project is not null"
  )

{:ok, timeline_stmt3} =
  Sqlite3.prepare(
    conn,
    "select timeline_csv(time, project) from heartbeats where time > 0 and project is not null"
  )

{:ok, timeline_stmt4} =
  Sqlite3.prepare(
    conn2,
    "select timeline_csv(time, project) from heartbeats where project is not null order by time"
  )

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
    "prepared time pkey" => fn ->
      {:row, _row} = Sqlite3.step(conn2, timeline_stmt4)
      :done = Sqlite3.step(conn2, timeline_stmt4)
    end,
    "prepared" => fn ->
      {:row, _row} = Sqlite3.step(conn, timeline_stmt2)
      :done = Sqlite3.step(conn, timeline_stmt2)
    end,
    "prepared (where)" => fn ->
      {:row, _row} = Sqlite3.step(conn, timeline_stmt3)
      :done = Sqlite3.step(conn, timeline_stmt3)
    end,
    "prepared (order)" => fn ->
      {:row, _row} = Sqlite3.step(conn, timeline_stmt1)
      :done = Sqlite3.step(conn, timeline_stmt1)
    end,
    "prepared (order), csv" => fn ->
      {:row, [csv]} = Sqlite3.step(conn, timeline_stmt1)
      :done = Sqlite3.step(conn, timeline_stmt1)

      csv
      |> String.split("\n", trim: true)
      |> Enum.map(fn row ->
        [project, from, to] = String.split(row, ",")
        [project, String.to_integer(from), String.to_integer(to)]
      end)
    end,
    "extension" => fn ->
      W2.Durations.fetch_timeline(~D[0000-01-01], ~D[2025-01-01])
    end
  },
  memory_time: 2
)
