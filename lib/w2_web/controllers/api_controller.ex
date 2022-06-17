defmodule W2Web.APIController do
  use W2Web, :controller
  alias W2.Durations

  # curl -H 'accept:application/json' 'http://localhost:4000/data?from=2022-06-01T00:00:00&to=2022-06-10T00:00:00'
  def data(conn, params) do
    to = parse_date_time(params["to"]) || NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    from = parse_date_time(params["from"]) || add_days(to, -7)

    data =
      Durations.fetch_dashboard_data(from, to)
      |> Map.put("from", NaiveDateTime.to_iso8601(from))
      |> Map.put("to", NaiveDateTime.to_iso8601(to))

    json(conn, data)
  end

  defp parse_date_time(value) do
    if value do
      case NaiveDateTime.from_iso8601(value) do
        {:ok, dt} -> dt
        _ -> nil
      end
    end
  end

  defp add_days(naive, days) do
    time = Time.new!(naive.hour, naive.minute, naive.second)

    Date.new!(naive.year, naive.month, naive.day)
    |> Date.add(days)
    |> NaiveDateTime.new!(time)
  end
end
