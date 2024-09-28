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
               {"w1", unix(~U[2022-01-01 12:04:12Z]), unix(~U[2022-01-01 12:04:19Z])},
               {"w2", unix(~U[2022-01-01 12:04:19Z]), unix(~U[2022-01-01 12:05:19Z])}
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
               {"w1", unix(~U[2022-01-01 12:04:12Z]), unix(~U[2022-01-01 12:05:12Z])},
               {"w1", unix(~U[2022-01-01 13:04:18Z]), unix(~U[2022-01-01 13:05:19Z])}
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

      assert Durations.fetch_projects(from: from, to: to) == [
               %{type: "file", category: "coding", project: "w2", duration: 60.0},
               %{type: "file", category: "coding", project: "w1", duration: 7.0}
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

      assert Durations.fetch_projects(from: from, to: to) == [
               %{type: "file", category: "coding", project: "w1", duration: 121.0}
             ]
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
             %{branch: "a-feature", project: "w2", duration: 121.0},
             %{branch: "cool-feature", project: "w2", duration: 60.0}
           ]
  end

  test "fetch_entities/1" do
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

    assert Durations.fetch_entities(project: "w2", from: from, to: to) == [
             %{
               type: "file",
               category: "coding",
               project: "w2",
               duration: 120.0,
               entity: "lib/router.ex"
             },
             %{
               type: "file",
               category: "coding",
               project: "w2",
               duration: 61.0,
               entity: "lib/api.ex"
             },
             %{
               type: "file",
               category: "coding",
               project: "w2",
               duration: 60.0,
               entity: "lib/api2.ex"
             },
             %{
               type: "file",
               category: "coding",
               project: "w2",
               duration: 0,
               entity: "lib/app.ex"
             }
           ]
  end

  describe "midnights/3" do
    test "returns all 0th hours between two timestamps taking into account relocations" do
      # in msk
      assert Durations.midnights(
               _from = unix(msk(~D[2022-08-20], ~T[12:03:12])),
               _to = unix(msk(~D[2022-08-24], ~T[23:53:12]))
             ) == [
               unix(msk(~D[2022-08-21], ~T[00:00:00])),
               unix(msk(~D[2022-08-22], ~T[00:00:00])),
               unix(msk(~D[2022-08-23], ~T[00:00:00])),
               unix(msk(~D[2022-08-24], ~T[00:00:00]))
             ]

      # msk -> tbs
      assert Durations.midnights(
               _from = unix(msk(~D[2022-08-26], ~T[12:03:12])),
               _to = unix(tbs(~D[2022-08-30], ~T[23:53:12]))
             ) == [
               unix(msk(~D[2022-08-27], ~T[00:00:00])),
               unix(msk(~D[2022-08-28], ~T[00:00:00])),
               unix(tbs(~D[2022-08-29], ~T[00:00:00])),
               unix(tbs(~D[2022-08-30], ~T[00:00:00]))
             ]

      # in tbs
      assert Durations.midnights(
               _from = unix(tbs(~D[2022-09-01], ~T[12:03:12])),
               _to = unix(tbs(~D[2022-09-05], ~T[23:53:12]))
             ) == [
               unix(tbs(~D[2022-09-02], ~T[00:00:00])),
               unix(tbs(~D[2022-09-03], ~T[00:00:00])),
               unix(tbs(~D[2022-09-04], ~T[00:00:00])),
               unix(tbs(~D[2022-09-05], ~T[00:00:00]))
             ]

      # tbs -> bkk
      assert Durations.midnights(
               _from = unix(tbs(~D[2022-10-06], ~T[12:03:12])),
               _to = unix(bkk(~D[2022-10-10], ~T[23:53:12]))
             ) == [
               unix(tbs(~D[2022-10-07], ~T[00:00:00])),
               unix(tbs(~D[2022-10-08], ~T[00:00:00])),
               unix(bkk(~D[2022-10-09], ~T[00:00:00])),
               unix(bkk(~D[2022-10-10], ~T[00:00:00]))
             ]

      # in bkk
      assert Durations.midnights(
               _from = unix(bkk(~D[2022-10-12], ~T[12:03:12])),
               _to = unix(bkk(~D[2022-10-16], ~T[23:53:12]))
             ) == [
               unix(bkk(~D[2022-10-13], ~T[00:00:00])),
               unix(bkk(~D[2022-10-14], ~T[00:00:00])),
               unix(bkk(~D[2022-10-15], ~T[00:00:00])),
               unix(bkk(~D[2022-10-16], ~T[00:00:00]))
             ]

      # TODO test going back in TZ/utc offset
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
               {unix(~U[2022-01-01 12:00:00Z]), %{"w1" => 7, "w2" => 60}}
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
                 {unix(~U[2022-01-01 12:00:00Z]), %{"w1" => 108}},
                 {unix(~U[2022-01-01 13:00:00Z]), %{"w1" => 134}}
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
                 {unix(~U[2022-01-01 12:00:00Z]), %{"w1" => 60}},
                 {unix(~U[2022-01-01 13:00:00Z]), %{"w1" => 61}}
               ]
    end
  end
end
