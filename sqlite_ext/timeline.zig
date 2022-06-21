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

const Agg4State = struct {
    arena: std.heap.ArenaAllocator = undefined,
    timeline: Timeline4 = Timeline4{},

    fn inited(self: *Agg4State) bool {
        return self.timeline.csv != null;
    }

    fn init(self: *Agg4State) void {
        self.arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.timeline.csv = std.ArrayList(u8).init(self.arena.allocator());
    }

    fn deinit(self: *Agg4State) void {
        self.arena.deinit();
    }
};

const AggStateError = error{ NoState, NoProjectValue };

const Timeline = struct {
    prev_project: []const u8 = undefined,
    prev_project_value: ?*c.sqlite3_value = null,
    prev_time: f64 = 0,
    prev_from: f64 = 0,
    // TODO ArrayListUnmanaged?
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
    }

    fn finish(self: *Timeline) !void {
        if (self.prev_project_value != null) try self.append(self.prev_time);
    }
};

// TODO don't ignore other projects interrupts (means can't use group by)
// TOOD use xxh3 for hashing (project,branch,file) instead of pointwise compare?
const Timeline4 = struct {
    prev_branch: []const u8 = undefined,
    prev_branch_value: ?*c.sqlite3_value = null,
    prev_entity: []const u8 = undefined,
    prev_entity_value: ?*c.sqlite3_value = null,
    prev_time: f64 = 0,
    prev_from: f64 = 0,
    csv: ?std.ArrayList(u8) = null,

    fn append(self: *Timeline4, time: f64) !void {
        try self.csv.?.writer().print("{s},{s},{d},{d}\n", .{
            self.prev_branch,
            self.prev_entity,
            @floatToInt(u64, self.prev_from),
            @floatToInt(u64, time),
        });
    }

    fn updateBranch(self: *Timeline4, value: *c.sqlite3_value) !void {
        self.prev_branch_value = sqlite3.value_dup.?(value);

        if (self.prev_branch_value == null and sqlite3.value_type.?(value) != c.SQLITE_NULL) {
            // TODO
            return AggStateError.NoProjectValue;
        }

        self.prev_branch = std.mem.span(sqlite3.value_text.?(self.prev_branch_value.?));
    }

    fn updateEntity(self: *Timeline4, value: *c.sqlite3_value) !void {
        self.prev_entity_value = sqlite3.value_dup.?(value);

        if (self.prev_entity_value == null and sqlite3.value_type.?(value) != c.SQLITE_NULL) {
            // TODO
            return AggStateError.NoProjectValue;
        }

        self.prev_entity = std.mem.span(sqlite3.value_text.?(self.prev_entity_value.?));
    }

    // TODO handle nulls
    fn add(self: *Timeline4, time: f64, branch_value: *c.sqlite3_value, entity_value: *c.sqlite3_value) !void {
        if (self.prev_branch_value == null) {
            try self.updateBranch(branch_value);
            try self.updateEntity(entity_value);
            self.prev_time = time;
            self.prev_from = time;
            return;
        }

        const diff = time - self.prev_time;
        const branch = sqlite3.value_text.?(branch_value);
        const entity = sqlite3.value_text.?(entity_value);
        const branch_changed = !std.mem.eql(u8, self.prev_branch, std.mem.span(branch));
        const entity_changed = !std.mem.eql(u8, self.prev_entity, std.mem.span(entity));

        if (diff < 300) {
            if (branch_changed or entity_changed) {
                try self.append(time);
                self.prev_from = time;
            }
        } else {
            try self.append(self.prev_time);
            self.prev_from = time;
        }

        if (branch_changed) {
            sqlite3.value_free.?(self.prev_branch_value);
            try self.updateBranch(branch_value);
        }

        if (entity_changed) {
            sqlite3.value_free.?(self.prev_entity_value);
            try self.updateEntity(entity_value);
        }

        self.prev_time = time;
    }

    fn finish(self: *Timeline4) !void {
        if (self.prev_branch_value != null) try self.append(self.prev_time);
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

fn get4State(ctx: ?*c.sqlite3_context) !*Agg4State {
    const size = @sizeOf(Agg4State);
    const alignment = @alignOf(Agg4State);
    const unaligned_ptr = sqlite3.aggregate_context.?(ctx, size + alignment);
    const state = @intToPtr(?*Agg4State, std.mem.alignForward(@ptrToInt(unaligned_ptr), alignment));

    if (state == null) {
        sqlite3.result_error_nomem.?(ctx);
        return AggStateError.NoState;
    }

    if (!state.?.inited()) state.?.init();
    return state.?;
}

fn timelineStep(ctx: ?*c.sqlite3_context, _: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
    const state = getState(ctx) catch return;
    const time = sqlite3.value_double.?(argv[0]);
    state.timeline.add(time, argv[1].?) catch {
        state.deinit();
        sqlite3.result_error_nomem.?(ctx);
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

fn timeline4Step(ctx: ?*c.sqlite3_context, _: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
    const state = get4State(ctx) catch return;
    const time = sqlite3.value_double.?(argv[0]);
    state.timeline.add(time, argv[1].?, argv[2].?) catch {
        state.deinit();
        sqlite3.result_error_nomem.?(ctx);
    };
}

fn timeline4Final(ctx: ?*c.sqlite3_context) callconv(.C) void {
    const state = get4State(ctx) catch return;
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

    var result = sqlite3.create_function.?(db, "timeline_csv", 2, c.SQLITE_UTF8, null, null, timelineStep, timelineFinal);
    if (result != c.SQLITE_OK) return result;

    //
    // Examples:
    //
    // `select timeline_csv(time, branch, entity) from heartbeats where time > ? and project = 'w1';`
    // `select timeline_csv(time, branch, entity) from heartbeats where project = 'w1' order by time;`
    //

    return sqlite3.create_function.?(db, "timeline_csv", 3, c.SQLITE_UTF8, null, null, timeline4Step, timeline4Final);
}
