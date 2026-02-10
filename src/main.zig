const std = @import("std");
const dvui = @import("dvui");

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

    {
        const sub_menu = try gpa_singleton.create(branch.Menu);
        sub_menu.* = .init;
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
    }

    const fourth_site = try gpa_singleton.create(branch.Site);
    fourth_site.* = try .init(gpa_singleton, "https://google.com");
    try root_menu.items.append(gpa_singleton, .{
        .key = .g,
        .name = "fourth",
        .value = .{ .site = fourth_site },
    });

    const site_form = try gpa_singleton.create(branch.SiteForm);
    site_form.* = try .init(
        gpa_singleton,
        "https://search.brave.com/search?q=${query}",
        try .init(gpa_singleton, &.{
            "query",
        }, &.{.{
            .label = "Search query",
            .t = .string,
            .modify = null,
        }}),
    );
    try root_menu.items.append(gpa_singleton, .{
        .key = .b,
        .name = "brave",
        .value = .{ .site_form = site_form },
    });

    var screen_stack: std.ArrayList(branch.Screen) = .empty;
    try screen_stack.append(gpa_singleton, .{
        .menu = root_menu,
    });

    app_singleton = .{
        .gpa = gpa_singleton,
        .frame_arena = .init(gpa_singleton),
        .screen_stack = screen_stack,
    };
}

fn appDeinit() void {
    app_singleton.deinit();
    _ = debug_allocator.deinit();
}

fn appFrame() !dvui.App.Result {
    _ = app_singleton.frame_arena.reset(.retain_capacity);
    return frame(&app_singleton);
}

fn frame(app: *branch.App) !dvui.App.Result {
    const current_screen = app.screen_stack.getLast();

    switch (current_screen) {
        .menu => |m| return m.drawWindow(app),
        .site_form => |sf| return sf.drawWindow(app),
    }
}
