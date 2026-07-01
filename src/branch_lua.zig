const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const dvui = @import("dvui");

const MenuDesc = struct {
    title: []const u8,
    key: dvui.enums.Key,

    items: []ItemDesc,
};
const SiteDesc = struct {};

fn newMenu(lua: *Lua) i32 {
    const opts_idx = 1; // Index of `opts` table

    _ = lua.pushString("title");
    const title = switch (lua.getTable(opts_idx)) {
        .string => lua.toString(-1) catch unreachable,
        else => return lua.raiseError("invalid type for 'Menu.title'"),
    };
    _ = lua.pushString("key");
    const key = switch (lua.getTable(opts_idx)) {
        .string => blk: {
            const key_str = lua.toString(-1) catch unreachable;
            break :blk std.meta.stringToEnum(dvui.enums.Key, key_str) orelse {
                return lua.raiseError("invalid key for 'Menu.key'");
            };
        },
        else => return lua.raiseError("invalid type for 'Menu.title'"),
    };

    return 1;
}

pub fn openLib(lua: *Lua) void {
    lua.registerFns("branch", branch_functions);
}

const branch_functions: []const zlua.FnReg = &.{
    .{ .name = "Menu", .func = newMenu },
};
