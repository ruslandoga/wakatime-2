const c = @cImport(@cInclude("sqlite3ext.h"));
var sqlite3_api: *c.sqlite3_api_routines = undefined;

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
