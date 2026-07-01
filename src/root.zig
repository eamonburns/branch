const std = @import("std");
const Allocator = std.mem.Allocator;
const dvui = @import("dvui");
const zlua = @import("zlua");

const screens = @import("screens.zig");
pub const Screen = screens.Screen;
pub const Menu = screens.Menu;
pub const SiteForm = screens.SiteForm;

pub const App = struct {
    gpa: Allocator,
    frame_arena: std.heap.ArenaAllocator,
    screen_stack: std.ArrayList(screens.Screen),

    pub fn deinit(app: *App) void {
        const root_screen = app.screen_stack.items[0];
        switch (root_screen) {
            inline else => |s| {
                s.deinit(app.gpa);
                app.gpa.destroy(s);
            },
        }
        app.screen_stack.deinit(app.gpa);
        app.frame_arena.deinit();
    }
};

pub const Site = struct {
    url: []const u8,

    const log = std.log.scoped(.@"branch.Site");

    pub fn init(gpa: Allocator, url: []const u8) Allocator.Error!Site {
        return .{
            .url = try gpa.dupe(u8, url),
        };
    }
    pub fn deinit(site: Site, gpa: Allocator) void {
        gpa.free(site.url);
    }

    /// Returns true when the site was successfully opened,
    /// false if there was a problem
    pub fn run(site: Site) bool {
        return dvui.openURL(.{
            .new_window = false,
            .url = site.url,
        });
    }
};

pub fn screenFromLuaScript(gpa: Allocator, script: []const u8) !Screen {
    var lua: *zlua.Lua = try .init(gpa);
    defer lua.deinit();

    var stdout_buf: [1024]u8 = undefined;
    var stdout_file = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_file.interface;

    lua.openLibs();
    const script_z = try gpa.dupeZ(u8, script);
    defer gpa.free(script_z);
    lua.loadString(script_z) catch |err| {
        try stdout.print("({t}) {s}\n", .{ err, lua.toString(-1) catch unreachable });
        try stdout.flush();
        lua.pop(1);
        return err;
    };
    lua.protectedCall(.{}) catch |err| {
        try stdout.print("({t}) {s}\n", .{ err, lua.toString(-1) catch unreachable });
        try stdout.flush();
        lua.pop(1);
        return err;
    };

    return undefined;
}
