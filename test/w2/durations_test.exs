defmodule W2.DurationsTest do
  use W2.DataCase
  alias W2.Durations

  test "project switch" do
    assert totals([
             {unix(~U[2022-01-01 12:04:12Z]), "w1"},
             {unix(~U[2022-01-01 12:04:13Z]), "w1"},
             {unix(~U[2022-01-01 12:04:18Z]), "w1"},
             {unix(~U[2022-01-01 12:04:19Z]), "w2"},
             {unix(~U[2022-01-01 12:05:19Z]), "w2"}
           ]) == %{
             hour(~U[2022-01-01 12:00:00Z]) => %{
               "w1" => 7,
               "w2" => 60
             }
           }
  end

  test "hour switch" do
    assert totals([
             {unix(~U[2022-01-01 12:58:12Z]), "w1"},
             {unix(~U[2022-01-01 12:59:13Z]), "w1"},
             {unix(~U[2022-01-01 13:00:18Z]), "w1"}
           ]) == %{
             hour(~U[2022-01-01 12:00:00Z]) => %{"w1" => 108},
             hour(~U[2022-01-01 13:00:00Z]) => %{"w1" => 18}
           }
  end

  test "duration break" do
    assert totals([
             {unix(~U[2022-01-01 12:04:12Z]), "w1"},
             {unix(~U[2022-01-01 12:05:12Z]), "w1"},
             {unix(~U[2022-01-01 13:04:18Z]), "w1"},
             {unix(~U[2022-01-01 13:04:19Z]), "w1"},
             {unix(~U[2022-01-01 13:05:19Z]), "w1"}
           ]) == %{
             hour(~U[2022-01-01 12:00:00Z]) => %{"w1" => 60},
             hour(~U[2022-01-01 13:00:00Z]) => %{"w1" => 61}
           }
  end

  def totals([{time, project} | heartbeats]) do
    Durations.hourly_totals(heartbeats, time, time, project, %{}, %{})
  end

  def totals([]) do
    %{}
  end

  defp unix(dt) do
    DateTime.to_unix(dt)
  end

  defp hour(dt) do
    round(unix(dt) / 3600)
  end
end
