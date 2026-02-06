const std = @import("std");

const dvui = @import("dvui");

const branch = @import("branch");

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 800.0, .h = 600.0 },
            .min_size = .{ .w = 250.0, .h = 350.0 },
            .title = "Branch",
            // .icon = window_icon_png,
            .window_init_options = .{
                // Could set a default theme here
                // .theme = dvui.Theme.builtin.adwaita_dark,
            },
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

var app_singleton: branch.App = undefined;

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
const gpa_singleton = debug_allocator.allocator();

var orig_content_scale: f32 = 1.0;
var warn_on_quit = false;
var warn_on_quit_closing = false;

fn appInit(win: *dvui.Window) !void {
    orig_content_scale = win.content_scale;

    var menu: branch.Menu = .init;

    try menu.items.append(gpa_singleton, .{
        .key = null,
        .name = "first",
        .value = .none,
    });

    try menu.items.append(gpa_singleton, .{
        .key = null,
        .name = "second",
        .value = .none,
    });

    try menu.items.append(gpa_singleton, .{
        .key = null,
        .name = "third",
        .value = .{ .menu = .init },
    });

    app_singleton = .{
        .gpa = gpa_singleton,
        .frame_arena = .init(gpa_singleton),
        .current_menu = menu,
    };
}

fn appDeinit() void {
    _ = debug_allocator.deinit();
    app_singleton.frame_arena.deinit();
    app_singleton.current_menu.deinit(app_singleton.gpa);
}

fn appFrame() !dvui.App.Result {
    _ = app_singleton.frame_arena.reset(.retain_capacity);
    return frame(&app_singleton);
}

fn frame(app: *branch.App) !dvui.App.Result {
    try app.current_menu.drawWindow(app);

    return .ok;
}
