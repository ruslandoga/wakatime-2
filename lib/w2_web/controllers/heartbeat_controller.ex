defmodule W2Web.HeartbeatController do
  use W2Web, :controller
  require Logger

  def create(conn, params) do
    %{"_json" => heartbeats} = params

    [machine_name] = get_req_header(conn, "x-machine-name")
    _ = W2.Ingester.insert_heartbeats(heartbeats, machine_name)

    conn
    |> put_status(201)
    |> json(ingest_response(heartbeats))
  end

  defp ingest_response(heartbeats) do
    case heartbeats do
      heartbeats when is_list(heartbeats) ->
        %{"responses" => Enum.map(heartbeats, fn _ -> [nil, 201] end)}

      %{} = heartbeat ->
        %{"data" => heartbeat}
    end
  end

  def ignore(conn, params) do
    %{"logs" => logs} = params

    logs
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
    |> Enum.each(fn %{"level" => level} = log -> Logger.log(log_level(level), log) end)

    send_resp(conn, 201, [])
  end

  defp log_level("debug"), do: :debug
  defp log_level("error"), do: :error
end
