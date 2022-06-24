defmodule W2.DurationsTest do
  use W2.DataCase
  alias W2.Durations

  doctest Durations, import: true

  describe "fetch_timeline/1" do
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

      assert Durations.fetch_timeline(from: from, to: to) == [
               ["w1", unix(~U[2022-01-01 12:04:12Z]), unix(~U[2022-01-01 12:04:19Z])],
               ["w2", unix(~U[2022-01-01 12:04:19Z]), unix(~U[2022-01-01 12:05:19Z])]
             ]
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

      assert Durations.fetch_timeline(from: from, to: to) == [
               ["w1", unix(~U[2022-01-01 12:04:12Z]), unix(~U[2022-01-01 12:05:12Z])],
               ["w1", unix(~U[2022-01-01 13:04:18Z]), unix(~U[2022-01-01 13:05:19Z])]
             ]
    end
  end

  describe "fetch_projects/1" do
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

      assert Durations.fetch_projects(from: from, to: to) == [["w2", 60.0], ["w1", 7.0]]
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

      assert Durations.fetch_projects(from: from, to: to) == [["w1", 121.0]]
    end
  end

  test "fetch_branches/1" do
    insert_heartbeats([
      %{"time" => unix(~U[2022-01-01 12:04:12Z]), "project" => "w2", "branch" => "cool-feature"},
      %{"time" => unix(~U[2022-01-01 12:05:12Z]), "project" => "w2", "branch" => "cool-feature"},
      %{"time" => unix(~U[2022-01-01 13:04:18Z]), "project" => "w2", "branch" => "a-feature"},
      %{"time" => unix(~U[2022-01-01 13:05:19Z]), "project" => "w2", "branch" => "a-feature"},
      %{"time" => unix(~U[2022-01-01 13:06:19Z]), "project" => "w3", "branch" => "a-feature"},
      %{"time" => unix(~U[2022-01-01 13:07:19Z]), "project" => "w3", "branch" => "a-feature"}
    ])

    from = ~U[2022-01-01 12:00:00Z]
    to = ~U[2022-01-01 14:00:00Z]

    assert Durations.fetch_branches(project: "w2", from: from, to: to) == [
             ["a-feature", 121],
             ["cool-feature", 60]
           ]
  end

  test "fetch_files/1" do
    insert_heartbeats([
      %{"time" => unix(~U[2022-01-01 12:04:12Z]), "project" => "w2", "entity" => "lib/router.ex"},
      %{"time" => unix(~U[2022-01-01 12:05:12Z]), "project" => "w2", "entity" => "lib/api.ex"},
      %{"time" => unix(~U[2022-01-01 13:04:18Z]), "project" => "w2", "entity" => "lib/api.ex"},
      %{"time" => unix(~U[2022-01-01 13:05:19Z]), "project" => "w2", "entity" => "lib/router.ex"},
      %{"time" => unix(~U[2022-01-01 13:06:19Z]), "project" => "w3", "entity" => "lib/api2.ex"},
      %{"time" => unix(~U[2022-01-01 13:07:19Z]), "project" => "w3", "entity" => "lib/app.ex"},
      %{"time" => unix(~U[2022-01-01 13:06:19Z]), "project" => "w2", "entity" => "lib/api2.ex"},
      %{"time" => unix(~U[2022-01-01 13:07:19Z]), "project" => "w2", "entity" => "lib/app.ex"}
    ])

    from = ~U[2022-01-01 12:00:00Z]
    to = ~U[2022-01-01 14:00:00Z]

    assert Durations.fetch_files(project: "w2", from: from, to: to) == [
             ["lib/router.ex", 120],
             ["lib/api.ex", 61],
             ["lib/api2.ex", 60],
             ["lib/app.ex", 0]
           ]
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
