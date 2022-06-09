const std = @import("std");
const c = @cImport(@cInclude("sqlite3ext.h"));
var sqlite3_api: *c.sqlite3_api_routines = undefined;

// TODO
// Copied from https://github.com/ameerbrar/zig-generate_series/blob/main/src/generate_series.zig
// Copied from raw_c_allocator.
// Asserts allocations are within `@alignOf(std.c.max_align_t)` and directly calls
// `malloc`/`free`. Does not attempt to utilize `malloc_usable_size`.
// This allocator is safe to use as the backing allocator with
// `ArenaAllocator` for example and is more optimal in such a case
// than `c_allocator`.
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
var sqlite_allocator = &allocator_state;
var allocator_state = Allocator{ .allocFn = alloc, .resizeFn = resize };

fn alloc(self: *Allocator, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) Allocator.Error![]u8 {
    _ = self;
    _ = len_align;
    _ = ret_addr;
    assert(ptr_align <= @alignOf(std.c.max_align_t));
    const ptr = @ptrCast([*]u8, sqlite3_api.*.malloc64.?(len) orelse return error.OutOfMemory);
    return ptr[0..len];
}

fn resize(self: *Allocator, buf: []u8, old_align: u29, new_len: usize, len_align: u29, ret_addr: usize) Allocator.Error!usize {
    _ = self;
    _ = old_align;
    _ = ret_addr;
    if (new_len == 0) {
        sqlite3_api.*.free.?(buf.ptr);
        return 0;
    }
    if (new_len <= buf.len) {
        return std.mem.alignAllocLen(buf.len, new_len, len_align);
    }
    return error.OutOfMemory;
}

const TotalDurationState = struct {
    sum: f64,
    prev: f64,
    pub fn add(self: *TotalDurationState, time: f64) void {
        const diff = time - self.prev;
        if (diff < 300) self.sum += diff;
        self.prev = time;
    }
};

pub fn durationStep(ctx: ?*c.sqlite3_context, argc: c_int, argv: [*c]?*c.sqlite3_value) callconv(.C) void {
    _ = argc;

    const state = @ptrCast(
        ?*TotalDurationState,
        @alignCast(
            @alignOf(TotalDurationState),
            sqlite3_api.aggregate_context.?(ctx, @sizeOf(TotalDurationState)),
        ),
    );

    if (state == null) return sqlite3_api.result_error_nomem.?(ctx);
    const time = sqlite3_api.value_double.?(argv[0]);
    state.?.add(time);
}

pub fn durationFinal(ctx: ?*c.sqlite3_context) callconv(.C) void {
    // TODO
    // Within the xFinal callback, it is customary to set N=0 in calls to sqlite3_aggregate_context(C,N)
    // so that no pointless memory allocations occur.
    const state = @ptrCast(
        ?*TotalDurationState,
        @alignCast(
            @alignOf(TotalDurationState),
            sqlite3_api.aggregate_context.?(ctx, @sizeOf(TotalDurationState)),
        ),
    );

    sqlite3_api.result_double.?(ctx, state.?.sum);
}

pub export fn sqlite3_duration_init(db: ?*c.sqlite3, pzErrMsg: [*c][*c]u8, pApi: [*c]c.sqlite3_api_routines) c_int {
    _ = pzErrMsg;
    sqlite3_api = pApi.?;
    _ = sqlite3_api.create_function.?(db, "duration", 1, c.SQLITE_UTF8, null, null, durationStep, durationFinal);
    return c.SQLITE_OK;
}
