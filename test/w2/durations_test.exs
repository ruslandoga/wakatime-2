defmodule W2.DurationsTest do
  use W2.DataCase
  alias W2.Durations
  doctest Durations, import: true

  describe "bucket_totals/2" do
    test "project switch" do
      assert Durations.bucket_totals(
               [
                 {unix(~U[2022-01-01 12:04:12Z]), "w1"},
                 {unix(~U[2022-01-01 12:04:13Z]), "w1"},
                 {unix(~U[2022-01-01 12:04:18Z]), "w1"},
                 {unix(~U[2022-01-01 12:04:19Z]), "w2"},
                 {unix(~U[2022-01-01 12:05:19Z]), "w2"}
               ],
               _interval = 3600
             ) == [
               [unix(~U[2022-01-01 12:00:00Z]), %{"w1" => 7, "w2" => 60}]
             ]
    end

    test "hour switch" do
      assert Durations.bucket_totals(
               [
                 {unix(~U[2022-01-01 12:58:12Z]), "w1"},
                 {unix(~U[2022-01-01 12:59:13Z]), "w1"},
                 {unix(~U[2022-01-01 13:00:18Z]), "w1"}
               ],
               _interval = 3600
             ) == [
               [unix(~U[2022-01-01 12:00:00Z]), %{"w1" => 108}],
               [unix(~U[2022-01-01 13:00:00Z]), %{"w1" => 18}]
             ]
    end

    test "duration break" do
      assert Durations.bucket_totals(
               [
                 {unix(~U[2022-01-01 12:04:12Z]), "w1"},
                 {unix(~U[2022-01-01 12:05:12Z]), "w1"},
                 {unix(~U[2022-01-01 13:04:18Z]), "w1"},
                 {unix(~U[2022-01-01 13:04:19Z]), "w1"},
                 {unix(~U[2022-01-01 13:05:19Z]), "w1"}
               ],
               _interval = 3600
             ) == [
               [unix(~U[2022-01-01 12:00:00Z]), %{"w1" => 60}],
               [unix(~U[2022-01-01 13:00:00Z]), %{"w1" => 61}]
             ]
    end
  end

  describe "total/1" do
    test "project switch" do
      assert Durations.total([
               unix(~U[2022-01-01 12:04:12Z]),
               unix(~U[2022-01-01 12:04:13Z]),
               unix(~U[2022-01-01 12:04:18Z]),
               unix(~U[2022-01-01 12:04:19Z]),
               unix(~U[2022-01-01 12:05:19Z])
             ]) == 67
    end

    test "hour switch" do
      assert Durations.total([
               unix(~U[2022-01-01 12:58:12Z]),
               unix(~U[2022-01-01 12:59:13Z]),
               unix(~U[2022-01-01 13:00:18Z])
             ]) == 126
    end

    test "duration break" do
      assert Durations.total([
               unix(~U[2022-01-01 12:04:12Z]),
               unix(~U[2022-01-01 12:05:12Z]),
               unix(~U[2022-01-01 13:04:18Z]),
               unix(~U[2022-01-01 13:04:19Z]),
               unix(~U[2022-01-01 13:05:19Z])
             ]) == 121
    end
  end

  describe "project_totals/1" do
    test "project switch" do
      assert Durations.project_totals([
               {unix(~U[2022-01-01 12:04:12Z]), "w1"},
               {unix(~U[2022-01-01 12:04:13Z]), "w1"},
               {unix(~U[2022-01-01 12:04:18Z]), "w1"},
               {unix(~U[2022-01-01 12:04:19Z]), "w2"},
               {unix(~U[2022-01-01 12:05:19Z]), "w2"}
             ]) == %{"w1" => 7, "w2" => 60}
    end

    test "hour switch" do
      assert Durations.project_totals([
               {unix(~U[2022-01-01 12:58:12Z]), "w1"},
               {unix(~U[2022-01-01 12:59:13Z]), "w1"},
               {unix(~U[2022-01-01 13:00:18Z]), "w1"}
             ]) == %{"w1" => 126}
    end

    test "duration break" do
      assert Durations.project_totals([
               {unix(~U[2022-01-01 12:04:12Z]), "w1"},
               {unix(~U[2022-01-01 12:05:12Z]), "w1"},
               {unix(~U[2022-01-01 13:04:18Z]), "w1"},
               {unix(~U[2022-01-01 13:04:19Z]), "w1"},
               {unix(~U[2022-01-01 13:05:19Z]), "w1"}
             ]) == %{"w1" => 121}
    end
  end

  describe "timeline/1" do
    test "project switch" do
      assert Durations.timeline([
               {unix(~U[2022-01-01 12:04:12Z]), "w1"},
               {unix(~U[2022-01-01 12:04:13Z]), "w1"},
               {unix(~U[2022-01-01 12:04:18Z]), "w1"},
               {unix(~U[2022-01-01 12:04:19Z]), "w2"},
               {unix(~U[2022-01-01 12:05:19Z]), "w2"}
             ]) == [
               ["w1", unix(~U[2022-01-01 12:04:12Z]), unix(~U[2022-01-01 12:04:19Z])],
               ["w2", unix(~U[2022-01-01 12:04:19Z]), unix(~U[2022-01-01 12:05:19Z])]
             ]
    end

    test "hour switch" do
      assert Durations.timeline([
               {unix(~U[2022-01-01 12:58:12Z]), "w1"},
               {unix(~U[2022-01-01 12:59:13Z]), "w1"},
               {unix(~U[2022-01-01 13:00:18Z]), "w1"}
             ]) == [["w1", unix(~U[2022-01-01 12:58:12Z]), unix(~U[2022-01-01 13:00:18Z])]]
    end

    test "duration break" do
      assert Durations.timeline([
               {unix(~U[2022-01-01 12:04:12Z]), "w1"},
               {unix(~U[2022-01-01 12:05:12Z]), "w1"},
               {unix(~U[2022-01-01 13:04:18Z]), "w1"},
               {unix(~U[2022-01-01 13:04:19Z]), "w1"},
               {unix(~U[2022-01-01 13:05:19Z]), "w1"}
             ]) == [
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

  defp unix(dt) do
    DateTime.to_unix(dt)
  end
end
