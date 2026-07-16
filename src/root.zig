const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const dvui = @import("dvui");
const zlua = @import("zlua");

const lua_bindings = @import("lua_bindings.zig");

pub const App = struct {
    io: Io,
    gpa: Allocator,
    screen_stack: std.ArrayList(Screen),
    lua: *zlua.Lua,

    should_close: bool,

    pub fn init(io: Io, gpa: Allocator, script_file: [:0]const u8) !App {
        // === Initialize Lua === //
        const lua: *zlua.Lua = try .init(gpa);
        errdefer lua.deinit();
        lua.openLibs();

        lua_bindings.register(io, gpa, lua);

        lua.doString(@embedFile("branch.lua")) catch |err| {
            std.log.err("{!s}", .{lua.toString(-1)});
            return err;
        };

        lua.doFile(script_file) catch |err| {
            std.log.err("{!s}", .{lua.toString(-1)});
            return err;
        };
        const lua_site = lua.toUserdata(Menu.Item, -1) catch {
            return error.NotUserdata;
        };

        // === Create app === //
        var app: App = .{
            .io = io,
            .gpa = gpa,
            .screen_stack = .empty,
            .lua = lua,
            .should_close = false,
        };
        errdefer app.deinit();
        defer if (app.should_close) {
            lua_site.deinit(app.gpa);
        } else {
            app.gpa.free(lua_site.name);
        };

        if (try lua_site.activate(&app)) {
            app.should_close = true;
        }

        return app;
    }

    pub fn deinit(app: *App) void {
        if (app.screen_stack.items.len == 0) {
            std.log.warn("App.deinit: empty screen stack?", .{});
            return;
        } else {
            const root_screen = app.screen_stack.items[0];
            switch (root_screen) {
                inline else => |s| {
                    s.deinit(app.gpa);
                    app.gpa.destroy(s);
                },
            }
        }
        app.screen_stack.deinit(app.gpa);
        app.lua.deinit();
    }

    pub fn frame(app: *App) !dvui.App.Result {
        if (app.should_close) return .close;

        const current_screen = app.screen_stack.getLast();

        switch (current_screen) {
            .menu => |m| return m.drawWindow(app),
            .form => |f| return f.drawWindow(app),
        }
    }
};

pub const Screen = union(enum) {
    menu: *Menu,
    form: *Form,
};

pub const Menu = struct {
    items: std.ArrayList(Item) = .empty,

    /// Dynamic GUI state, internal to `Menu`.
    // NOTE: Should be reset back to `.init` when changing
    // to a different menu/screen
    _state: State = .init,

    // State of GUI
    const State = struct {
        show_filter: bool = false,
        should_focus_filter: bool = false,
        pub const init: State = .{};
    };

    const log = std.log.scoped(.@"branch.Menu");

    pub const init: Menu = .{};

    pub const Item = struct {
        name: []const u8,
        key: ?dvui.enums.Key,
        value: union(enum) {
            menu: *Menu,
            lua_func: LuaRef,
            // site: *Site,
            form: *Form,
            none, // NOTE: Placeholder
        },

        pub fn deinit(self: Item, gpa: Allocator) void {
            gpa.free(self.name);
            switch (self.value) {
                .menu => |m| {
                    defer gpa.destroy(m);
                    m.deinit(gpa);
                },
                .form => |f| {
                    defer gpa.destroy(f);
                    f.deinit(gpa);
                },
                .lua_func => {
                    // TODO: Lua.unref
                },
                .none => {},
            }
        }

        /// Returns true if the app should close
        pub fn activate(self: Item, app: *App) !bool {
            switch (self.value) {
                .menu => |next_menu| {
                    if (app.screen_stack.getLastOrNull()) |current_screen| {
                        current_screen.menu._state = .init;
                    }
                    try app.screen_stack.append(app.gpa, .{ .menu = next_menu });
                    return false;
                },
                .form => |next_form| {
                    if (app.screen_stack.getLastOrNull()) |current_screen| {
                        current_screen.menu._state = .init;
                    }
                    try app.screen_stack.append(app.gpa, .{ .form = next_form });
                    return false;
                },
                // .site => |site| if (site.run()) {
                //     return true;
                // } else {
                //     return error.OpenSiteFailure;
                // },
                .lua_func => |f| {
                    if (app.lua.getIndexRaw(zlua.registry_index, f) != .function) {
                        return error.InvalidLuaFunction;
                    }

                    app.lua.protectedCall(.{}) catch {
                        log.err("lua call failed: {!s}", .{app.lua.toString(-1)});
                        return false;
                    };
                    return true;
                },
                .none => return false,
            }
        }
    };

    pub fn deinit(menu: *Menu, gpa: Allocator) void {
        for (menu.items.items) |item| item.deinit(gpa);
        menu.items.deinit(gpa);
    }

    pub fn drawWindow(menu: *Menu, app: *App) !dvui.App.Result {
        var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
        });
        defer vbox.deinit();

        const filter = if (menu._state.show_filter) blk: {
            var filter_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .gravity_x = 1,
                .expand = .horizontal,
            });
            defer filter_box.deinit();

            var input = dvui.textEntry(@src(), .{}, .{
                .expand = .horizontal,
            });
            defer input.deinit();
            if (menu._state.should_focus_filter) dvui.focusWidget(input.data().id, null, null);

            break :blk input.textGet();
        } else "";

        var item_widgets: std.ArrayList(struct {
            item: *Item,
            index: usize,
            widget_id: dvui.Id,
            widget_rect: dvui.Rect.Physical,
        }) = .empty;
        for (menu.items.items, 0..) |*item, i| {
            // TODO: Fuzzy match and sort
            if (filter.len > 0 and !std.mem.containsAtLeast(u8, item.name, 1, filter)) continue;

            var item_box = dvui.box(@src(), .{ .dir = .vertical }, .{
                .id_extra = i,
                .expand = .horizontal,
                .background = true,
                .border = .all(1),
            });
            defer item_box.deinit();

            try item_widgets.append(dvui.currentWindow().arena(), .{
                .index = i,
                .item = item,
                .widget_id = item_box.data().id,
                .widget_rect = item_box.data().borderRectScale().r,
            });

            // TODO: Actually good interface
            dvui.label(@src(), "name: {s}", .{item.name}, .{
                .id_extra = i,
                .expand = .horizontal,
            });
            dvui.label(@src(), "type: {t}", .{item.value}, .{
                .id_extra = i,
                .expand = .horizontal,
            });
            dvui.label(@src(), "key: {?t}", .{item.key}, .{
                .id_extra = i,
                .expand = .horizontal,
            });
        }

        menu._state.should_focus_filter = false;
        const wd = dvui.currentWindow().data();
        events: for (dvui.events()) |*e| {
            switch (e.evt) {
                .key => |key| {
                    if (key.action != .down) continue :events;
                    switch (key.code) {
                        .slash => {
                            menu._state.should_focus_filter = true;
                            menu._state.show_filter = true;
                        },
                        .escape => if (menu._state.show_filter) {
                            menu._state.show_filter = false;
                        } else if (app.screen_stack.items.len > 1) {
                            menu._state = .init;
                            _ = app.screen_stack.pop();
                        },
                        else => |key_code| for (item_widgets.items) |item_widget| {
                            if (key_code != item_widget.item.key) continue;

                            log.debug("clicked menu item {d}: {t}", .{ item_widget.index, item_widget.item.value });
                            if (try item_widget.item.activate(app)) {
                                return .close;
                            }
                            break;
                        } else continue,
                    }
                    log.debug("key event: {t}", .{e.evt.key.code});
                },
                .mouse => |mouse| {
                    if (mouse.button != .left or mouse.action != .press) continue :events;
                    for (item_widgets.items) |item_widget| {
                        log.debug("widget {d} rect: {any}", .{ item_widget.index, item_widget.widget_rect });
                        if (!dvui.eventMatch(e, .{
                            .id = item_widget.widget_id,
                            .r = item_widget.widget_rect,
                        })) continue;

                        log.debug("clicked menu item {d}: {t}", .{ item_widget.index, item_widget.item.value });
                        if (try item_widget.item.activate(app)) {
                            return .close;
                        }
                        break;
                    } else continue;
                },
                else => continue :events,
            }
            e.handle(@src(), wd);
        }
        return .ok;
    }
};

pub const FormFields = std.StringArrayHashMapUnmanaged(FormField);
pub const FormField = struct {
    label: []const u8,
    t: Type,
    modify: ?Modifier,

    pub const Type = enum { string, integer };
    pub const Modifier = *const fn ([]const u8) []const u8;

    pub const Values = []struct {
        id: []const u8,
        value: []const u8,
    };

    pub fn allocValues(gpa: Allocator, n: usize) Allocator.Error!Values {
        return gpa.alloc(@typeInfo(Values).pointer.child, n);
    }
};

pub const _Site = struct {
    url: []const u8,

    const log = std.log.scoped(.@"branch.Site");

    pub fn init(gpa: Allocator, url: []const u8) Allocator.Error!_Site {
        return .{
            .url = try gpa.dupe(u8, url),
        };
    }
    pub fn deinit(site: _Site, gpa: Allocator) void {
        gpa.free(site.url);
    }

    /// Returns true when the site was successfully opened,
    /// false if there was a problem
    pub fn run(site: _Site) bool {
        return dvui.openURL(.{
            .new_window = false,
            .url = site.url,
        });
    }
};

/// Asserts that `format` is valid and contains only placeholders contained in `values`.
/// Caller owns returned memory
fn _formatFields(gpa: Allocator, format: []const u8, values: FormField.Values) ![]const u8 {
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();
    const w = &aw.writer;

    var chunk_start: usize = 0;
    while (std.mem.indexOfPos(u8, format, chunk_start, "${")) |idx| {
        try w.writeAll(format[chunk_start..idx]);
        const id_start = idx + 2;
        const id_end = std.mem.indexOfPos(u8, format, id_start, "}") orelse unreachable; // There must by a matching closing '}'
        const id = format[id_start..id_end];

        for (values) |value| {
            if (std.mem.eql(u8, value.id, id)) {
                try w.writeAll(value.value);
                break;
            }
        } else unreachable; // Format placeholder with the given id was not found

        chunk_start = id_end + 1;
    }
    try w.writeAll(format[chunk_start..]);

    return aw.toOwnedSlice();
}

pub const _SiteForm = struct {
    format: []const u8,
    fields: FormFields,

    const log = std.log.scoped(.@"branch.SiteForm");

    pub fn init(gpa: Allocator, format: []const u8, fields: FormFields) Allocator.Error!_SiteForm {
        return .{
            .format = try gpa.dupe(u8, format),
            .fields = fields,
        };
    }
    pub fn deinit(form: *_SiteForm, gpa: Allocator) void {
        gpa.free(form.format);
        form.fields.deinit(gpa);
    }

    pub fn drawWindow(form: *_SiteForm, app: *App) !dvui.App.Result {
        const arena = dvui.currentWindow().arena();
        var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
        });
        defer vbox.deinit();

        var field_values = try FormField.allocValues(
            arena,
            form.fields.entries.len,
        );
        var enter_pressed = false;
        var it = form.fields.iterator();
        var i: usize = 0;
        while (it.next()) |entry| : (i += 1) {
            dvui.labelNoFmt(@src(), entry.value_ptr.label, .{}, .{});
            const field = dvui.textEntry(@src(), .{}, .{ .id_extra = i });
            defer field.deinit();

            enter_pressed = enter_pressed or field.enter_pressed;
            field_values[i] = .{
                .id = entry.key_ptr.*,
                .value = field.textGet(),
            };
        }

        if (enter_pressed or dvui.button(@src(), "Submit", .{}, .{})) {
            const formatted_url = try _formatFields(arena, form.format, field_values);
            const site: _Site = .{
                .url = formatted_url,
            };
            if (site.run()) {
                return .close;
            } else {
                return error.OpenSiteFailure;
            }
        }

        const wd = dvui.currentWindow().data();
        events: for (dvui.events()) |*e| {
            switch (e.evt) {
                .key => |key| {
                    if (key.action != .down) continue :events;
                    switch (key.code) {
                        .escape => if (app.screen_stack.items.len > 1) {
                            _ = app.screen_stack.pop();
                        },
                        else => continue,
                    }
                    log.debug("key event: {t}", .{e.evt.key.code});
                },
                else => continue :events,
            }
            e.handle(@src(), wd);
        }

        return .ok;
    }
};

pub const Form = struct {
    callback: LuaRef,
    fields: []Field,

    pub const Field = struct {
        name: []const u8,
        id: [:0]const u8,
        type: Type,
        validateFn: LuaRef,
        modifyFn: LuaRef,

        pub const Type = enum { number, string, boolean };

        pub fn deinit(f: Field, gpa: Allocator) void {
            gpa.free(f.name);
            gpa.free(f.id);
            // TODO: lua.unref(f.validateFn)
            // TODO: lua.unref(f.modifyFn)
        }
    };

    pub fn deinit(f: Form, gpa: Allocator) void {
        // TODO: lua.unref(f.callback)
        for (f.fields) |field| {
            field.deinit(gpa);
        }
        gpa.free(f.fields);
    }

    pub fn drawWindow(form: *Form, app: *App) !dvui.App.Result {
        const arena = dvui.currentWindow().arena();
        var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
        });
        defer vbox.deinit();

        const field_values = try arena.alloc(struct {
            id: [:0]const u8,
            value: []const u8,
        }, form.fields.len);

        var enter_pressed = false;
        for (form.fields, 0..) |field, i| {
            dvui.labelNoFmt(@src(), field.name, .{}, .{});
            const field_widget = dvui.textEntry(@src(), .{}, .{ .id_extra = i });
            defer field_widget.deinit();

            enter_pressed = enter_pressed or field_widget.enter_pressed;
            field_values[i] = .{
                .id = field.id,
                .value = field_widget.textGet(),
            };
        }

        if (enter_pressed or dvui.button(@src(), "Submit", .{}, .{})) {
            if (app.lua.getIndexRaw(zlua.registry_index, form.callback) != .function) {
                return error.InvalidLuaFunction;
            }
            // stack: [callback]

            app.lua.newTable();
            // stack: [callback, fields_table]
            const field_table_idx = app.lua.getTop();

            for (field_values) |v| {
                _ = app.lua.pushString(v.value);
                app.lua.setField(field_table_idx, v.id);
            }
            app.lua.protectedCall(.{
                .args = 1,
                .results = 1,
            }) catch {
                std.log.err("form callback failed: {!s}", .{app.lua.toString(-1)});
                return .close;
            };

            const item = app.lua.toUserdata(Menu.Item, -1) catch {
                return error.NotUserdata;
            };

            if (try item.activate(app)) {
                item.deinit(app.gpa);
                return .close;
            } else {
                return .ok;
            }
        }

        const wd = dvui.currentWindow().data();
        events: for (dvui.events()) |*e| {
            switch (e.evt) {
                .key => |key| {
                    if (key.action != .down) continue :events;
                    switch (key.code) {
                        .escape => if (app.screen_stack.items.len > 1) {
                            _ = app.screen_stack.pop();
                        },
                        else => continue,
                    }
                    std.log.debug("key event: {t}", .{e.evt.key.code});
                },
                else => continue :events,
            }
            e.handle(@src(), wd);
        }

        return .ok;
    }
};

const LuaRef = i32; // TODO: Type-safe ref `enum(i32) { _ }`
