defmodule W2.TimersTest do
  use W2.DataCase
  alias W2.Timers

  describe "create_timer/1" do
    test "requires task" do
      assert {:error, changeset} = Timers.create_timer(%{task: ""})
      assert errors_on(changeset) == %{task: ["can't be blank"]}
    end

    test "accepts a task" do
      assert {:ok, timer} = Timers.create_timer(%{task: "v1.5 release prep"})
      assert timer.task == "v1.5 release prep"
    end

    test "defaults started_at to now" do
      assert {:ok, timer} = Timers.create_timer(%{task: "v1.5 release prep"})
      assert timer.started_at
      assert_in_delta unix(timer.started_at), unix(DateTime.utc_now()), 1
    end

    test "defaults to unfinished" do
      assert {:ok, timer} = Timers.create_timer(%{task: "v1.5 prep"})
      refute timer.finished_at
    end
  end

  describe "finish_timer/1" do
    setup do
      {:ok, timer} = Timers.create_timer(%{task: "v1.5 prep"})
      {:ok, timer: timer}
    end

    test "sets finished_at to now", %{timer: timer} do
      assert :ok = Timers.finish_timer(timer.id)
      timer = Repo.reload!(timer)
      assert timer.finished_at
      assert_in_delta unix(timer.finished_at), unix(DateTime.utc_now()), 1
    end
  end

  describe "list_active/0" do
    test "lists started but not finished timers" do
      assert {:ok, t1} = Timers.create_timer(%{task: "v1.5 prep"})
      assert {:ok, t2} = Timers.create_timer(%{task: "v1.5 release prep"})
      assert {:ok, t3} = Timers.create_timer(%{task: "clickhouse stuff"})
      assert :ok = Timers.finish_timer(t1)

      assert [a1, a2] = Timers.list_active_timers()
      assert a1.id == t2.id
      assert a2.id == t3.id
    end
  end
end
