const std = @import("std");
const dvui = @import("dvui");
const zlua = @import("zlua");
const Lua = zlua.Lua;

const branch = @import("root.zig");
const Item = branch.Menu.Item;

// HACK: How can I do this properly?
pub var gpa_singleton: std.mem.Allocator = .failing;

pub fn register(lua: *Lua) void {
    inline for (@typeInfo(@This()).@"struct".decls) |decl| {
        const d = @field(@This(), decl.name);
        if (@TypeOf(&d) != zlua.CFn) continue;

        lua.register("_branch_" ++ decl.name, d);
    }
}

///@param name string
///@param key? string
///@param activate fun()
///@return branch.Item
pub fn new_item(l: ?*zlua.LuaState) callconv(.c) c_int {
    const lua: *Lua = if (l) |lua| @ptrCast(lua) else return 0;

    if (lua.getTop() != 3) {
        return lua.raiseErrorStr("expected 3 arguments, but found %d", .{lua.getTop()});
    }
    const name = lua.checkString(1);
    const key = if (lua.optString(2)) |key_str| blk: {
        break :blk std.meta.stringToEnum(dvui.enums.Key, key_str) orelse {
            return lua.argError(2, "invalid key name");
        };
    } else null;
    lua.argCheck(lua.isFunction(3), 3, "expected function");
    const activate = lua.ref(zlua.registry_index);

    const item = lua.newUserdata(Item);
    item.* = .{
        .name = name,
        .key = key,
        .value = .{
            .lua_func = activate,
        },
    };
    return 1;
}

///@param name string
///@param key? string
///@param ... branch.Item
///@return branch.Item
pub fn new_menu(l: ?*zlua.LuaState) callconv(.c) c_int {
    const lua: *Lua = if (l) |lua| @ptrCast(lua) else return 0;

    if (lua.getTop() < 3) {
        return lua.raiseErrorStr("expected at least 3 arguments, but found %d", .{lua.getTop()});
    }
    const name = lua.checkString(1);
    const key = if (lua.optString(2)) |key_str| blk: {
        break :blk std.meta.stringToEnum(dvui.enums.Key, key_str) orelse {
            return lua.argError(2, "invalid key name");
        };
    } else null;

    const items = gpa_singleton.alloc(Item, @intCast(lua.getTop() - 2)) catch {
        return lua.raiseErrorStr("OOM", .{});
    };

    for (0..@intCast(lua.getTop() - 2)) |i| {
        const idx: i32 = @intCast(i + 3);

        const item = lua.toUserdata(Item, idx) catch {
            return lua.raiseErrorStr("argument %d is not a userdata", .{idx});
        };
        items[i] = item.*;
    }

    const menu = gpa_singleton.create(branch.Menu) catch {
        return lua.raiseErrorStr("OOM", .{});
    };
    menu.* = .{
        .items = .fromOwnedSlice(items),
    };
    const item = lua.newUserdata(Item);
    item.* = .{
        .name = name,
        .key = key,
        .value = .{ .menu = menu },
    };
    return 1;
}

///@param name string # Display name
///@param key? string # Key to activate item
///@return branch.Item
pub fn new_none(l: ?*zlua.LuaState) callconv(.c) c_int {
    const lua: *Lua = if (l) |lua| @ptrCast(lua) else return 0;

    if (lua.getTop() != 2) {
        return lua.raiseErrorStr("expected 2 arguments, but found %d", .{lua.getTop()});
    }
    const name = lua.checkString(1);
    const key = if (lua.optString(2)) |key_str| blk: {
        break :blk std.meta.stringToEnum(dvui.enums.Key, key_str) orelse {
            return lua.argError(2, "invalid key name");
        };
    } else null;

    const item = lua.newUserdata(Item);
    item.* = .{
        .name = name,
        .key = key,
        .value = .none,
    };
    return 1;
}

///@param url string # URL to open
pub fn open_url(l: ?*zlua.LuaState) callconv(.c) c_int {
    const lua: *Lua = if (l) |lua| @ptrCast(lua) else return 0;

    const url = lua.checkString(1);
    lua.pop(1);

    if (!dvui.openURL(.{
        .url = url,
        .new_window = false,
    })) {
        return lua.raiseErrorStr("unable to open URL: %s", .{
            url.ptr, // Pass null-terminated string to C
        });
    }

    return 0;
}
