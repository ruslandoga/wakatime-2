defmodule W2.TimeZoneDatabase do
  @moduledoc false
  @behaviour Calendar.TimeZoneDatabase

  tzs = %{
    "Etc/UTC" => %{std_offset: 0, utc_offset: 0, zone_abbr: "UTC"},
    "Europe/Moscow" => %{std_offset: 0, utc_offset: 10800, zone_abbr: "MSK"}
  }

  @impl true
  def time_zone_period_from_utc_iso_days(iso_days, time_zone)

  for {tz, info} <- tzs do
    def time_zone_period_from_utc_iso_days(_iso_days, unquote(tz)) do
      {:ok, unquote(Macro.escape(info))}
    end
  end

  def time_zone_period_from_utc_iso_days(_iso_days, _time_zone) do
    {:error, :time_zone_not_found}
  end

  @impl true
  def time_zone_periods_from_wall_datetime(naive_datetime, time_zone)

  for {tz, info} <- tzs do
    def time_zone_periods_from_wall_datetime(_naive_datetime, unquote(tz)) do
      {:ok, unquote(Macro.escape(info))}
    end
  end

  def time_zone_periods_from_wall_datetime(_naive_datetime, _time_zone) do
    {:error, :time_zone_not_found}
  end
end
