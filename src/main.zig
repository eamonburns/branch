const std = @import("std");
const dvui = @import("dvui");
const zlua = @import("zlua");

const branch = @import("branch");

const lua_bindings = @import("lua_bindings.zig");

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

    // HACK: This is just a temporary menu so that we can do root_menu.selectItem
    // I think I want to make `selectItem` "owned" by the items themselves, so
    // that you can do `item.select(app)` or maybe `app.select(item)`
    const root_menu = try gpa_singleton.create(branch.Menu);
    root_menu.* = .init;
    defer gpa_singleton.destroy(root_menu);

    const lua: *zlua.Lua = try .init(gpa_singleton);
    lua.openLibs();
    lua_bindings.gpa_singleton = gpa_singleton;
    lua_bindings.register(lua);
    lua.doString(@embedFile("branch.lua")) catch |err| {
        std.log.err("{!s}", .{lua.toString(-1)});
        return err;
    };

    lua.doFile("site.lua") catch |err| {
        std.log.err("{!s}", .{lua.toString(-1)});
        return err;
    };
    const lua_site = lua.toUserdata(branch.Menu.Item, -1) catch {
        return error.NotUserdata;
    };

    app_singleton = .{
        .gpa = gpa_singleton,
        .screen_stack = .empty,
        .lua = lua,
    };
    if (try root_menu.selectItem(&app_singleton, lua_site)) {
        return error.ShouldClose;
    }
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
