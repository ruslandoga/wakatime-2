.PHONY: bench

bench:
	MIX_ENV=bench mix do ecto.reset, run bench/heartbeats_insert.exs
