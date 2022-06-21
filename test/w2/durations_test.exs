defmodule W2.DurationsTest do
  use W2.DataCase
  alias W2.Durations

  doctest Durations, import: true

  describe "fetch_dashboard_data/2" do
    test "project switch" do
      insert_heartbeats([
        %{"time" => unix(~U[2022-01-01 12:04:12Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 12:04:13Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 12:04:18Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 12:04:19Z]), "project" => "w2"},
        %{"time" => unix(~U[2022-01-01 12:05:19Z]), "project" => "w2"}
      ])

      from = ~U[2022-01-01 12:04:00Z]
      to = ~U[2022-01-01 12:06:00Z]

      %{total: total, projects: projects, timeline: timeline} =
        Durations.fetch_dashboard_data(from, to)

      assert total == 67
      assert projects == %{"w1" => 7, "w2" => 60}

      assert timeline == [
               ["w1", unix(~U[2022-01-01 12:04:12Z]), unix(~U[2022-01-01 12:04:19Z])],
               ["w2", unix(~U[2022-01-01 12:04:19Z]), unix(~U[2022-01-01 12:05:19Z])]
             ]
    end

    test "hour switch" do
      insert_heartbeats([
        %{"time" => unix(~U[2022-01-01 12:58:12Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 12:59:13Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 13:00:18Z]), "project" => "w1"}
      ])

      from = ~U[2022-01-01 12:50:00Z]
      to = ~U[2022-01-01 13:10:00Z]

      %{total: total, projects: projects, timeline: timeline} =
        Durations.fetch_dashboard_data(from, to)

      assert total == 126
      assert projects == %{"w1" => 126}
      assert timeline == [["w1", unix(~U[2022-01-01 12:58:12Z]), unix(~U[2022-01-01 13:00:18Z])]]
    end

    test "duration break" do
      insert_heartbeats([
        %{"time" => unix(~U[2022-01-01 12:04:12Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 12:05:12Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 13:04:18Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 13:04:19Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 13:05:19Z]), "project" => "w1"}
      ])

      from = ~U[2022-01-01 12:00:00Z]
      to = ~U[2022-01-01 14:00:00Z]

      %{total: total, projects: projects, timeline: timeline} =
        Durations.fetch_dashboard_data(from, to)

      assert total == 121
      assert projects == %{"w1" => 121}

      assert timeline == [
               ["w1", unix(~U[2022-01-01 12:04:12Z]), unix(~U[2022-01-01 12:05:12Z])],
               ["w1", unix(~U[2022-01-01 13:04:18Z]), unix(~U[2022-01-01 13:05:19Z])]
             ]
    end
  end

  describe "day_starts/2" do
    test "returns all 0th hours between two timestamps" do
      assert Durations.day_starts(
               _from = unix(~U[2022-01-01 12:03:12Z]),
               _to = unix(~U[2022-01-12 23:53:12Z])
             ) == [
               unix(~U[2022-01-02 00:00:00Z]),
               unix(~U[2022-01-03 00:00:00Z]),
               unix(~U[2022-01-04 00:00:00Z]),
               unix(~U[2022-01-05 00:00:00Z]),
               unix(~U[2022-01-06 00:00:00Z]),
               unix(~U[2022-01-07 00:00:00Z]),
               unix(~U[2022-01-08 00:00:00Z]),
               unix(~U[2022-01-09 00:00:00Z]),
               unix(~U[2022-01-10 00:00:00Z]),
               unix(~U[2022-01-11 00:00:00Z]),
               unix(~U[2022-01-12 00:00:00Z])
             ]
    end
  end
end
