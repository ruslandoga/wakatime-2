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
             ["w2", "a-feature", 121],
             ["w2", "cool-feature", 60]
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
             ["w2", "lib/router.ex", 120],
             ["w2", "lib/api.ex", 61],
             ["w2", "lib/api2.ex", 60],
             ["w2", "lib/app.ex", 0]
           ]
  end

  describe "midnights/3" do
    test "returns all MSK 0th hours between two timestamps" do
      assert Durations.midnights(
               _from = unix(msk(~D[2022-01-01], ~T[12:03:12])),
               _to = unix(msk(~D[2022-01-12], ~T[23:53:12])),
               _utc_offset = Durations.msk().utc_offset
             ) == [
               unix(msk(~D[2022-01-02], ~T[00:00:00])),
               unix(msk(~D[2022-01-03], ~T[00:00:00])),
               unix(msk(~D[2022-01-04], ~T[00:00:00])),
               unix(msk(~D[2022-01-05], ~T[00:00:00])),
               unix(msk(~D[2022-01-06], ~T[00:00:00])),
               unix(msk(~D[2022-01-07], ~T[00:00:00])),
               unix(msk(~D[2022-01-08], ~T[00:00:00])),
               unix(msk(~D[2022-01-09], ~T[00:00:00])),
               unix(msk(~D[2022-01-10], ~T[00:00:00])),
               unix(msk(~D[2022-01-11], ~T[00:00:00])),
               unix(msk(~D[2022-01-12], ~T[00:00:00]))
             ]
    end
  end

  describe "fetch_bucket_data/2" do
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

      assert Durations.fetch_bucket_data(from, to) == [
               [unix(~U[2022-01-01 12:00:00Z]), %{"w1" => 7, "w2" => 60}]
             ]
    end

    test "hour change" do
      insert_heartbeats([
        %{"time" => unix(~U[2022-01-01 12:58:12Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 12:59:13Z]), "project" => "w1"},
        %{"time" => unix(~U[2022-01-01 13:02:14Z]), "project" => "w1"}
      ])

      from = ~U[2022-01-01 12:00:00Z]
      to = ~U[2022-01-01 14:00:00Z]

      assert Durations.fetch_bucket_data(from, to) ==
               [
                 [unix(~U[2022-01-01 12:00:00Z]), %{"w1" => 108}],
                 [unix(~U[2022-01-01 13:00:00Z]), %{"w1" => 134}]
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

      assert Durations.fetch_bucket_data(from, to) ==
               [
                 [unix(~U[2022-01-01 12:00:00Z]), %{"w1" => 60}],
                 [unix(~U[2022-01-01 13:00:00Z]), %{"w1" => 61}]
               ]
    end
  end
end
