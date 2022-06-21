.PHONY: bench
bench:
	@MIX_ENV=bench mix do ecto.reset, run bench/heartbeats_insert.exs, run bench/timeline.exs

KERNEL_NAME := $(shell uname -s)

ifeq ($(KERNEL_NAME), Linux)
	EXTENSION = so	
endif

ifeq ($(KERNEL_NAME), Darwin)
	EXTENSION = dylib
endif

.PHONY: timeline
timeline:
	@zig build-lib -O ReleaseFast -fPIC -Isqlite_ext -dynamic sqlite_ext/timeline.zig
	@mv libtimeline.$(EXTENSION) priv/timeline.sqlite3ext
