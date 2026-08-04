const std = @import("std");

const io = std.Options.debug_io;

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    const prev = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(prev);

    var buf: [64]u8 = undefined;
    const term = output.lock(&buf) catch return;
    defer output.unlock();

    return std.log.defaultLogFileTerminal(level, scope, format, args, term) catch {};
}

const Output = union(enum) {
    stderr,
    file: struct {
        file: std.Io.File,
        file_writer: std.Io.File.Writer,
        mutex: std.Io.Mutex,
    },

    pub fn lock(out: *Output, buf: []u8) !std.Io.Terminal {
        return switch (out.*) {
            .stderr => std.debug.lockStderr(buf).terminal(),
            .file => |*f| {
                f.mutex.lock(io) catch unreachable;
                f.file_writer = f.file.writer(io, buf);
                try f.file_writer.seekTo(try f.file.length(io));
                return .{
                    .writer = &f.file_writer.interface,
                    .mode = .no_color,
                };
            },
        };
    }

    pub fn unlock(out: *Output) void {
        switch (out.*) {
            .stderr => std.debug.unlockStderr(),
            .file => |*f| {
                defer f.mutex.unlock(io);
                f.file_writer.interface.flush() catch std.log.defaultLog(
                    .err,
                    .default,
                    "unable to flush log file: {t}",
                    .{f.file_writer.err.?},
                );
                f.file_writer = undefined;
            },
        }
    }
};

pub fn initFile(log_file_path: []const u8) !void {
    std.debug.print("log.initFile\n", .{});
    output = .{ .file = .{
        .file = try std.Io.Dir.cwd().createFile(io, log_file_path, .{ .truncate = false }),
        .file_writer = undefined,
        .mutex = .init,
    } };
    const length = try output.file.file.length(io);
    if (length != 0) {
        // Speparate previous logs with current log
        try output.file.file.writePositionalAll(io, "\n\n\n", length);
    }
}

pub fn deinit() void {
    switch (output) {
        .stderr => {},
        .file => |f| f.file.close(io),
    }
}

var output: Output = .stderr;
