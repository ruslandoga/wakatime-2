defmodule W2Web.APIController do
  use W2Web, :controller
  alias W2.Durations

  # curl -H 'accept:application/json' 'http://localhost:4000/timeline?from=2022-06-01T00:00:00&to=2022-06-10T00:00:00'
  def timeline(conn, params) do
    to = parse_date_time(params["to"]) || NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    from = parse_date_time(params["from"]) || add_days(to, -7)
    project = params["project"]
    timeline = Durations.fetch_timeline(project: project, from: from, to: to)
    json(conn, timeline)
  end

  def projects(conn, params) do
    to = parse_date_time(params["to"]) || NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    from = parse_date_time(params["from"]) || add_days(to, -7)
    projects = Durations.fetch_projects(from: from, to: to)
    json(conn, projects)
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
