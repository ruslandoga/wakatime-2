.PHONY: bench
bench:
	@MIX_ENV=bench mix do ecto.reset, run bench/heartbeats_insert.exs, run bench/timeline.exs

ifeq ($(CPU),)
 	CPU=native
endif

.PHONY: timeline
timeline:
	zig build-lib -O ReleaseSafe -fPIC -Isqlite_ext -dynamic sqlite_ext/timeline.zig -mcpu $(CPU) -femit-bin=priv/timeline.sqlite3ext
