.PHONY: bench
bench:
	@MIX_ENV=bench mix do ecto.reset, run bench/heartbeats_insert.exs, run bench/timeline.exs

KERNEL_NAME := $(shell uname -s)

CFLAGS  = -std=c99
CFLAGS += -g
CFLAGS += -Wall
CFLAGS += -Wextra
CFLAGS += -pedantic
CFLAGS += -Werror
CFLAGS += -Wmissing-declarations
CFLAGS += -DUNITY_SUPPORT_64 -DUNITY_OUTPUT_COLOR

ifeq ($(KERNEL_NAME), Linux)
	CFLAGS += -fPIC
	LDFLAGS += -shared
endif
ifeq ($(KERNEL_NAME), Darwin)
	CFLAGS += -fPIC
	LDFLAGS += -dynamiclib -undefined dynamic_lookup
endif

timeline: c_src/*.c c_src/*.h
	@$(CC) $(CFLAGS) $(LDFLAGS) -O2 c_src/*.c -o ${MIX_APP_PATH}/priv/timeline.sqlite3ext

.PHONY: clean
clean:
	@rm -f priv/*.sqlite3ext
