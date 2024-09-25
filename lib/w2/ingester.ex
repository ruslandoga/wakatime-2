defmodule W2.Ingester do
  @moduledoc """
  Contains functions to ingests WakaTime heartbeats.
  """
  alias W2.{Repo, Ingester.Heartbeat}

  # TODO
  # - very naive insert for now, will be optimised later.
  def insert_heartbeats(heartbeats, machine_name) when is_list(heartbeats) do
    heartbeats = cast_heartbeats(heartbeats, machine_name)
    Repo.insert_all(Heartbeat, heartbeats)
    Phoenix.PubSub.broadcast!(W2.PubSub, "heartbeats", {W2.Ingester, :heartbeat})
    :ok
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
