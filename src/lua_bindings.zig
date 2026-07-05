const std = @import("std");
const dvui = @import("dvui");
const zlua = @import("zlua");
const Lua = zlua.Lua;

const branch = @import("branch");
const Item = branch.Menu.Item;

// HACK: How can I do this properly?
pub var gpa_singleton: std.mem.Allocator = undefined;

pub fn register(lua: *Lua) void {
    lua.register("_branch_new_item", new_item);
    lua.register("_branch_new_menu", new_menu);
    lua.register("_branch_new_none", new_none);
}

fn new_item(l: ?*zlua.LuaState) callconv(.c) c_int {
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

fn new_menu(l: ?*zlua.LuaState) callconv(.c) c_int {
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
fn new_none(l: ?*zlua.LuaState) callconv(.c) c_int {
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
