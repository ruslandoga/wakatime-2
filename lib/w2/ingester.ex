defmodule W2.Ingester do
  @moduledoc """
  Contains functions to ingests wakatime heartbeats, process them into durations.
  """
  alias W2.{Repo, Durations, Ingester.Heartbeat}
  import Ecto.Query

  # TODO
  # - very naive insert for now, will be optimised later.
  # - custom interval will be supported as well.
  # - out of order inserts too.
  def insert_heartbeats(heartbeats, machine_name) when is_list(heartbeats) do
    {:ok, :ok} =
      Repo.transaction(fn ->
        heartbeats = cast_heartbeats(heartbeats, machine_name)
        Repo.insert_all(Heartbeat, heartbeats)
        Enum.each(heartbeats, &maybe_upsert_duration(&1, W2.interval()))
      end)

    Phoenix.PubSub.broadcast!(W2.PubSub, "heartbeats", {W2.Ingester, :heartbeat})
    :ok
  end

  def backfill_durations do
    duration_table = Durations.duration_table(W2.interval())

    time =
      duration_table
      |> order_by(desc: :start)
      |> limit(1)
      |> select([d], d.start + d.length)
      |> Repo.one()

    backfill_durations(time || 0)
  end

  defp backfill_durations(time) do
    "heartbeats"
    |> order_by(asc: :time)
    |> limit(500)
    |> select([h], map(h, [:time, :project, :branch, :entity]))
    |> where([h], h.time > ^time)
    |> Repo.all()
    |> case do
      [] ->
        :ok

      heartbeats ->
        Enum.each(heartbeats, &maybe_upsert_duration(&1, W2.interval()))
        # :erlang.garbage_collect(self())
        backfill_durations(List.last(heartbeats).time)
    end
  end

  defp maybe_upsert_duration(%{time: time} = heartbeat, interval) do
    duration_table = Durations.duration_table(interval)
    prev_duration_id = prev_duration_id(duration_table) || 0
    prev_heartbeat = prev_heartbeat(time)

    within_interval? =
      if prev_heartbeat do
        diff = time - prev_heartbeat.time

        if diff < interval do
          last_duration_rowid =
            duration_table
            |> order_by(desc: :rowid)
            |> limit(1)
            # |> where([d], d.start < ^time)
            |> select([d], d.rowid)

          duration_table
          |> where([d], d.rowid == subquery(last_duration_rowid))
          |> Repo.update_all(inc: [length: diff])
        end
      end

    # TODO ooph
    if within_interval? do
      unless Map.take(heartbeat, [:project, :branch, :entity]) ==
               Map.take(prev_heartbeat || %{}, [:project, :branch, :entity]) do
        new_duration_id = if within_interval?, do: prev_duration_id, else: prev_duration_id + 1

        new_duration = %{
          id: new_duration_id,
          start: time,
          length: 0,
          project: heartbeat.project,
          branch: heartbeat.branch,
          entity: heartbeat.entity
        }

        Repo.insert_all(duration_table, [new_duration])
      end
    else
      new_duration_id = if within_interval?, do: prev_duration_id, else: prev_duration_id + 1

      new_duration = %{
        id: new_duration_id,
        start: time,
        length: 0,
        project: heartbeat.project,
        branch: heartbeat.branch,
        entity: heartbeat.entity
      }

      Repo.insert_all(duration_table, [new_duration])
    end
  end

  defp prev_heartbeat(time) do
    "heartbeats"
    |> limit(1)
    |> order_by(desc: :time)
    |> where([h], h.time < ^time)
    |> select([h], map(h, [:time, :project, :branch, :entity]))
    |> Repo.one()
  end

  defp prev_duration_id(table) do
    table
    |> order_by(desc: :id)
    |> limit(1)
    |> select([d], d.id)
    |> Repo.one()
  end

  @doc false
  def cast_heartbeats(heartbeats, machine_name) do
    Enum.map(heartbeats, &prepare_heartbeat(&1, machine_name))
  end

  defp prepare_heartbeat(%{"user_agent" => user_agent} = heartbeat, machine_name) do
    ["wakatime/" <> _wakatime_version, os, _python_or_go_version, editor, _extension] =
      String.split(user_agent, " ")

    os = String.replace(os, ["(", ")"], "")

    heartbeat
    |> Map.delete("user_agent")
    |> Map.put("editor", editor)
    |> Map.put("operating_system", os)
    |> Map.put("machine_name", machine_name)
    |> Map.update("is_write", false, fn is_write -> !!is_write end)
    |> cast_heartbeat()
    |> Map.take(Heartbeat.__schema__(:fields))
  end

  defp cast_heartbeat(data) do
    import Ecto.Changeset

    %Heartbeat{}
    |> cast(data, Heartbeat.__schema__(:fields))
    |> apply_action!(:insert)
  end
end
