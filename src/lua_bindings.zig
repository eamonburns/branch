const std = @import("std");
const dvui = @import("dvui");
const zlua = @import("zlua");
const Lua = zlua.Lua;

const branch = @import("branch");
const Item = branch.Menu.Item;

pub fn register(lua: *Lua) void {
    lua.register("_branch_new_item", new_item);
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
    const activate = lua.ref(zlua.registry_index) catch unreachable;

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
