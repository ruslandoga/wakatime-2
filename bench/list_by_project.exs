Benchee.run(
  %{
    "list_by_project" => fn ->
      W2.Durations.list_by_project(
        _from = ~U[2022-05-30 10:00:00Z],
        _to = ~U[2022-05-31 10:00:00Z]
      )
    end
  },
  memory_time: 2
)
