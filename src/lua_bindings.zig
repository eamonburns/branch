const std = @import("std");
const dvui = @import("dvui");
const zlua = @import("zlua");
const Lua = zlua.Lua;

const branch = @import("root.zig");
const Item = branch.Menu.Item;

/// Singltons, initialized when `register` is called
const static = struct {
    pub var io: std.Io = .failing;
    pub var gpa: std.mem.Allocator = .failing;
};

pub fn register(io: std.Io, gpa: std.mem.Allocator, lua: *Lua) void {
    static.io = io;
    static.gpa = gpa;

    inline for (@typeInfo(@This()).@"struct".decls) |decl| {
        const d = @field(@This(), decl.name);
        if (@TypeOf(&d) != zlua.CFn) continue;

        lua.register("_branch_" ++ decl.name, d);
    }
}

// ===== Userdata Creation Functions ===== //

///@param name string
///@param key? string
///@param activate fun()
///@return branch.Item
pub fn new_item(l: ?*zlua.LuaState) callconv(.c) c_int {
    const lua: *Lua = if (l) |lua| @ptrCast(lua) else return 0;

    if (lua.getTop() != 3) {
        return lua.raiseErrorStr("expected 3 arguments, but found %d", .{lua.getTop()});
    }
    const name = static.gpa.dupe(u8, lua.checkString(1)) catch oom(lua);
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
    const name = static.gpa.dupe(u8, lua.checkString(1)) catch oom(lua);
    const key = if (lua.optString(2)) |key_str| blk: {
        break :blk std.meta.stringToEnum(dvui.enums.Key, key_str) orelse {
            return lua.argError(2, "invalid key name");
        };
    } else null;

    const items = static.gpa.alloc(Item, @intCast(lua.getTop() - 2)) catch oom(lua);

    for (0..@intCast(lua.getTop() - 2)) |i| {
        const idx: i32 = @intCast(i + 3);

        const item = lua.toUserdata(Item, idx) catch {
            return lua.raiseErrorStr("argument %d is not a userdata", .{idx});
        };
        items[i] = item.*;
    }

    const menu = static.gpa.create(branch.Menu) catch oom(lua);
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
///@param id string # Identifier (unique within the form)
///@param type "number"|"string"|"boolean"
///@param validate? fun(string): boolean, string?
///@param modify? fun(any): any
pub fn new_field(l: ?*zlua.LuaState) callconv(.c) c_int {
    const lua: *Lua = if (l) |lua| @ptrCast(lua) else return 0;

    if (lua.getTop() != 5) {
        return lua.raiseErrorStr("expected 5 arguments, but found %d", .{lua.getTop()});
    }
    const name = static.gpa.dupe(u8, lua.checkString(1)) catch oom(lua);
    const id = static.gpa.dupeSentinel(u8, lua.checkString(2), 0) catch oom(lua);
    const type_ = lua.checkOption(branch.Form.Field.Type, 3, null);
    if (!lua.isNoneOrNil(4)) {
        lua.argCheck(lua.isFunction(4), 4, "expected function"); // validate
    }
    if (!lua.isNoneOrNil(5)) {
        lua.argCheck(lua.isFunction(5), 5, "expected function"); // modify
    }

    const modifyFn = lua.ref(zlua.registry_index);
    const validateFn = lua.ref(zlua.registry_index);
    lua.pop(3);

    const field: *branch.Form.Field = lua.newUserdata(branch.Form.Field);
    field.* = .{
        .name = name,
        .id = id,
        .type = type_,
        .validateFn = validateFn,
        .modifyFn = modifyFn,
    };
    return 1;
}

///@param name string # Display name
///@param key? string # Key to activate item
///@param callback fun(fields: table<string, any>): branch.Item
///@param ... branch.Field # List of items in the menu
pub fn new_form(l: ?*zlua.LuaState) callconv(.c) c_int {
    const lua: *Lua = if (l) |lua| @ptrCast(lua) else return 0;

    if (lua.getTop() < 4) {
        return lua.raiseErrorStr("expected at least 4 arguments, but found %d", .{lua.getTop()});
    }
    const name = static.gpa.dupe(u8, lua.checkString(1)) catch oom(lua);
    const key = if (lua.optString(2)) |key_str| blk: {
        break :blk std.meta.stringToEnum(dvui.enums.Key, key_str) orelse {
            return lua.argError(2, "invalid key name");
        };
    } else null;
    lua.argCheck(lua.isFunction(3), 3, "expected function");

    const field_count: usize = @intCast(lua.getTop() - 3);
    const fields = static.gpa.alloc(branch.Form.Field, field_count) catch oom(lua);

    for (0..field_count) |i| {
        const idx: i32 = @intCast(i + 4);

        const item = lua.toUserdata(branch.Form.Field, idx) catch {
            return lua.raiseErrorStr("argument %d is not a userdata", .{idx});
        };
        fields[i] = item.*;
    }
    lua.pop(@intCast(field_count));
    const callback = lua.ref(zlua.registry_index);

    const form = static.gpa.create(branch.Form) catch oom(lua);
    form.* = .{
        .fields = fields,
        .callback = callback,
    };
    const item = lua.newUserdata(Item);
    item.* = .{
        .name = name,
        .key = key,
        .value = .{ .form = form },
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
    const name = static.gpa.dupe(u8, lua.checkString(1)) catch oom(lua);
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

// ===== Helper Functions ===== //

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

///@param command string # Command to run
///@param ... string # Arguments to pass to command
pub fn exec(l: ?*zlua.LuaState) callconv(.c) c_int {
    const lua: *Lua = if (l) |lua| @ptrCast(lua) else return 0;

    const command = lua.checkString(1);
    const nargs: usize = @intCast(lua.getTop());
    const argv = static.gpa.alloc([]const u8, nargs) catch oom(lua);
    defer static.gpa.free(argv);
    argv[0] = command;
    for (argv[1..], 2..) |*arg, i| {
        arg.* = lua.checkString(@intCast(i));
    }

    const child = std.process.spawn(static.io, .{
        .argv = argv,
    }) catch |err| {
        return lua.raiseErrorStr("unable to start process: %s", .{@errorName(err).ptr});
    };
    _ = child; // TODO: Should I do something with the child process?
    return 0;
}

fn oom(lua: *Lua) noreturn {
    lua.raiseErrorStr("OOM", .{});
}
