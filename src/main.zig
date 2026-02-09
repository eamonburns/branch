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

    const root_menu = try gpa_singleton.create(branch.Menu);
    root_menu.* = .init;

    try root_menu.items.append(gpa_singleton, .{
        .key = .f,
        .name = "first",
        .value = .none,
    });
    try root_menu.items.append(gpa_singleton, .{
        .key = .s,
        .name = "second",
        .value = .none,
    });

    var sub_menu: branch.Menu = .init;
    try sub_menu.items.append(gpa_singleton, .{
        .key = .a,
        .name = "alpha",
        .value = .none,
    });
    try sub_menu.items.append(gpa_singleton, .{
        .key = .b,
        .name = "beta",
        .value = .none,
    });

    try root_menu.items.append(gpa_singleton, .{
        .key = .t,
        .name = "third",
        .value = .{ .menu = sub_menu },
    });

    var menu_stack: std.ArrayList(*branch.Menu) = .empty;
    try menu_stack.append(gpa_singleton, root_menu);

    app_singleton = .{
        .gpa = gpa_singleton,
        .frame_arena = .init(gpa_singleton),
        .menu_stack = menu_stack,
    };
}

fn appDeinit() void {
    _ = debug_allocator.deinit();
    app_singleton.frame_arena.deinit();
    const root_menu = app_singleton.menu_stack.items[0];
    root_menu.deinit(gpa_singleton);
}

fn appFrame() !dvui.App.Result {
    _ = app_singleton.frame_arena.reset(.retain_capacity);
    return frame(&app_singleton);
}

fn frame(app: *branch.App) !dvui.App.Result {
    const current_menu = app.menu_stack.getLast();
    try current_menu.drawWindow(app);

    return .ok;
}
