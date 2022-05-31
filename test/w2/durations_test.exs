defmodule W2.DurationsTest do
  use W2.DataCase
  alias W2.Durations
  doctest Durations, import: true

  test "project switch" do
    assert totals([
             {unix(~U[2022-01-01 12:04:12Z]), "w1"},
             {unix(~U[2022-01-01 12:04:13Z]), "w1"},
             {unix(~U[2022-01-01 12:04:18Z]), "w1"},
             {unix(~U[2022-01-01 12:04:19Z]), "w2"},
             {unix(~U[2022-01-01 12:05:19Z]), "w2"}
           ]) == %{
             unix(~U[2022-01-01 12:00:00Z]) => %{
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
             unix(~U[2022-01-01 12:00:00Z]) => %{"w1" => 108},
             unix(~U[2022-01-01 13:00:00Z]) => %{"w1" => 18}
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
             unix(~U[2022-01-01 12:00:00Z]) => %{"w1" => 60},
             unix(~U[2022-01-01 13:00:00Z]) => %{"w1" => 61}
           }
  end

  def totals([{time, project} | heartbeats]) do
    Durations.bucket_totals(heartbeats, time, time, project, %{}, %{}, _hour = 3600)
  end

  def totals([]) do
    %{}
  end

  defp unix(dt) do
    DateTime.to_unix(dt)
  end

  @doc false
  def trace do
    # Rexbug.start("W2.Durations :: return,stack")
    Rexbug.start("W2.Durations", msgs: 10000)
  end
end
