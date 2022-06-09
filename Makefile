.PHONY: bench compile-ext

bench:
	MIX_ENV=bench mix do ecto.reset, run bench/heartbeats_insert.exs, run bench/list_by_project.exs

# TODO -O ReleaseSafe
compile-ext:
	zig build-lib -O ReleaseFast -fPIC -Iext -dynamic ext/duration.zig
	mv libduration.* priv/
