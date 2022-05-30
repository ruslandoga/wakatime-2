defmodule W2.Ingester do
  alias W2.Repo
  alias __MODULE__.Heartbeat

  def insert_heartbeats(heartbeats) do
    Repo.insert_all(Heartbeat, cast_heartbeats(heartbeats))
  end

  @doc false
  def cast_heartbeats(heartbeats) do
    Enum.map(heartbeats, fn %{"user_agent" => user_agent} = heartbeat ->
      ["wakatime/" <> _wakatime_version, os, _python_or_go_version, editor, _extension] =
        String.split(user_agent, " ")

      os = String.replace(os, ["(", ")"], "")

      heartbeat
      |> Map.delete("user_agent")
      |> Map.put("editor", editor)
      |> Map.put("operating_system", os)
      |> Map.update("is_write", nil, fn is_write -> !!is_write end)
      |> cast_heartbeat()
      |> Map.take(Heartbeat.__schema__(:fields))
    end)
  end

  defp cast_heartbeat(data) do
    import Ecto.Changeset

    %Heartbeat{}
    |> cast(data, Heartbeat.__schema__(:fields))
    |> apply_action!(:insert)
  end
end
