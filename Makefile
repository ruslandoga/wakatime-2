.PHONY: bench

bench:
	MIX_ENV=bench mix do ecto.reset, run bench/heartbeats_insert.exs, run bench/list_by_project.exs
