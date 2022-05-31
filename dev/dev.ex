defmodule Dev do
  alias W2.Repo
  import Ecto.Query
  alias Exqlite.Sqlite3

  # Repo.transaction(fn ->
  #   "heartbeats"
  #   |> select([h], h.time)
  #   |> limit(10)
  #   |> Repo.stream()
  #   |> Stream.transform({nil, nil}, fn time, {start_time, prev_time} = acc ->
  #     if start_time do
  #       if prev_time do
  #         if time - prev_time > 300 do
  #           {[{start_time, prev_time}], {time, nil}}
  #         else
  #           {[], put_elem(acc, 1, time)}
  #         end
  #       else
  #         {[], put_elem(acc, 1, time)}
  #       end
  #     else
  #       {[], put_elem(acc, 0, time)}
  #     end
  #   end)
  #   |> Enum.into([])
  # end)

  def run do
    {:ok, conn} = Sqlite3.open("w2_bench.db")
    {:ok, stmt} = Sqlite3.prepare(conn, "select time from heartbeats order by time asc")
    _durations = durations(conn, stmt, _start_time = nil, _prev_time = nil, _durations = [])
  end

  def prepare do
    {:ok, conn} = Sqlite3.open("w2_bench.db")
    {:ok, stmt} = Sqlite3.prepare(conn, "select time from heartbeats order by time asc")
    {conn, stmt}
  end

  def control(conn, stmt) do
    _control(conn, stmt)
  end

  def _control(conn, stmt) do
    case Sqlite3.step(conn, stmt) do
      {:row, _} -> _control(conn, stmt)
      :done -> []
    end
  end

  def durations(conn, stmt) do
    durations(conn, stmt, _start_time = nil, _prev_time = nil, _durations = [])
  end

  def durations(conn, stmt, start_time, prev_time, durations) do
    case Sqlite3.step(conn, stmt) do
      {:row, [time]} ->
        if start_time do
          if prev_time do
            if time - prev_time > 300 do
              durations(conn, stmt, time, nil, [{start_time, prev_time} | durations])
            else
              durations(conn, stmt, start_time, time, durations)
            end
          else
            durations(conn, stmt, start_time, time, durations)
          end
        else
          durations(conn, stmt, time, prev_time, durations)
        end

      :done ->
        case durations do
          [] -> [{start_time, prev_time}]
          _other -> durations
        end
    end
  end
end
