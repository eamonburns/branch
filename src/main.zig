const std = @import("std");
const dvui = @import("dvui");
const zlua = @import("zlua");

const branch = @import("branch");

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .title = "Branch",
            .size = .{ .w = 800.0, .h = 600.0 },
            .min_size = .{ .w = 250.0, .h = 350.0 },
        },
    },
    .initFn = appInit,
    .deinitFn = appDeinit,
    .frameFn = appFrame,
};
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};

var app_singleton: branch.App = .{
    .io = .failing,
    .gpa = .failing,
    .screen_stack = .empty,
    .lua = undefined,
    .should_close = true,
};

fn appInit(_: *dvui.Window) !void {
    const init = dvui.App.main_init orelse unreachable;
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    _ = args.skip();

    app_singleton = try .init(
        init.io,
        init.gpa,
        args.next() orelse return error.ExpectedScriptFile,
    );
}

fn appDeinit() void {
    app_singleton.deinit();
}

fn appFrame() !dvui.App.Result {
    return app_singleton.frame();
}
