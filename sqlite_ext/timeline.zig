const std = @import("std");
const c = @cImport(@cInclude("../deps/exqlite/c_src/sqlite3ext.h"));

var sqlite3: *c.sqlite3_api_routines = undefined; // = SQLITE_EXTENSION_INIT1

const AggState = struct {
    arena: std.heap.ArenaAllocator = undefined,
    timeline: Timeline = Timeline{},

    fn inited(self: *AggState) bool {
        return self.timeline.csv != null;
    }

    fn init(self: *AggState) void {
        self.arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.timeline.csv = std.ArrayList(u8).init(self.arena.allocator());
    }

    fn deinit(self: *AggState) void {
        self.arena.deinit();
    }
};

const AggStateError = error{ NoState, NoProjectValue };

const Timeline = struct {
    prev_project: []const u8 = undefined,
    prev_project_value: ?*c.sqlite3_value = null,
    prev_time: f64 = 0,
    prev_from: f64 = 0,
    csv: ?std.ArrayList(u8) = null,

    fn append(self: *Timeline, time: f64) !void {
        try self.csv.?.writer().print("{s},{d},{d}\n", .{
            self.prev_project,
            @floatToInt(u64, self.prev_from),
            @floatToInt(u64, time),
        });
    }

    fn updateProject(self: *Timeline, project_value: *c.sqlite3_value) !void {
        self.prev_project_value = sqlite3.value_dup.?(project_value);

        if (self.prev_project_value == null and sqlite3.value_type.?(project_value) != c.SQLITE_NULL) {
            return AggStateError.NoProjectValue;
        }

        self.prev_project = std.mem.span(sqlite3.value_text.?(self.prev_project_value.?));
    }

    fn add(self: *Timeline, time: f64, project_value: *c.sqlite3_value) !void {
        if (self.prev_project_value == null) {
            try self.updateProject(project_value);
            self.prev_time = time;
            self.prev_from = time;
            return;
        }

        const diff = time - self.prev_time;
        const project = sqlite3.value_text.?(project_value);
        const project_changed = !std.mem.eql(u8, self.prev_project, std.mem.span(project));

        if (diff < 300) {
            if (project_changed) {
                try self.append(time);
                self.prev_from = time;
            }
        } else {
            try self.append(self.prev_time);
            self.prev_from = time;
        }

        if (project_changed) {
            sqlite3.value_free.?(self.prev_project_value);
            try self.updateProject(project_value);
        }

        self.prev_time = time;
        return;
    }

    fn finish(self: *Timeline) !void {
        if (self.prev_project_value != null) try self.append(self.prev_time);
    }
};

fn getState(ctx: ?*c.sqlite3_context) !*AggState {
    // https://github.com/ruslandoga/sqlite-zig-problem/pull/1
    // TODO find a proper fix
    const size = @sizeOf(AggState);
    const alignment = @alignOf(AggState);
    const unaligned_ptr = sqlite3.aggregate_context.?(ctx, size + alignment);
    const state = @intToPtr(?*AggState, std.mem.alignForward(@ptrToInt(unaligned_ptr), alignment));

    if (state == null) {
        sqlite3.result_error_nomem.?(ctx);
        return AggStateError.NoState;
    }

    if (!state.?.inited()) state.?.init();
    return state.?;
}

fn timelineStep(ctx: ?*c.sqlite3_context, _: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
    const state = getState(ctx) catch return;
    const time: f64 = sqlite3.value_double.?(argv[0]);
    state.timeline.add(time, argv[1].?) catch {
        state.deinit();
        sqlite3.result_error_nomem.?(ctx);
        return;
    };
}

fn timelineFinal(ctx: ?*c.sqlite3_context) callconv(.C) void {
    const state = getState(ctx) catch return;
    defer state.deinit();

    state.timeline.finish() catch {
        sqlite3.result_error_nomem.?(ctx);
        return;
    };

    sqlite3.result_text.?(ctx, state.timeline.csv.?.items.ptr, -1, c.SQLITE_TRANSIENT);
}

pub export fn sqlite3_timeline_init(db: ?*c.sqlite3, _: [*c][*c]u8, pApi: [*c]c.sqlite3_api_routines) c_int {
    sqlite3 = pApi.?; // = SQLITE_EXTENSION_INIT2(pApi);

    //
    // Examples:
    //
    // `select timeline_csv(time, project) from heartbeats where time > ?;`
    // `select timeline_csv(time, project) from heartbeats order by time;`
    //
    // Notes:
    //
    // - need to force sqlite order by time somehow, can be done by time pkey,
    // filtering or ordering by time
    //
    // `select timeline_csv(time, project) from heartbeats;`
    //   would produce invalid results as heartbeats
    //   wouldn't be ordered by time
    //

    return sqlite3.create_function.?(db, "timeline_csv", 2, c.SQLITE_UTF8, null, null, timelineStep, timelineFinal);
}
