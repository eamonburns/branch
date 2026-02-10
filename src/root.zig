const std = @import("std");
const Allocator = std.mem.Allocator;
const dvui = @import("dvui");

pub const App = struct {
    gpa: Allocator,
    frame_arena: std.heap.ArenaAllocator,
    screen_stack: std.ArrayList(Screen),

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

pub const Screen = union(enum) {
    menu: *Menu,
    site_form: *SiteForm,
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
        key: ?dvui.enums.Key,
        name: []const u8,
        value: union(enum) {
            menu: *Menu,
            site: *Site,
            site_form: *SiteForm,
            none, // NOTE: Placeholder
        },
    };

    pub fn deinit(menu: *Menu, gpa: Allocator) void {
        for (menu.items.items) |item| switch (item.value) {
            .menu => |m| {
                defer gpa.destroy(m);
                m.deinit(gpa);
            },
            .site_form => |sf| {
                defer gpa.destroy(sf);
                sf.deinit(gpa);
            },
            .site => |s| {
                defer gpa.destroy(s);
                s.deinit(gpa);
            },
            .none => {},
        };
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

            try item_widgets.append(app.frame_arena.allocator(), .{
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

                            log.debug("clicked menu item {d}: {t}\n", .{ item_widget.index, item_widget.item.value });
                            if (try menu.selectItem(app, item_widget.item)) {
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
                        log.debug("widget {d} rect: {any}\n", .{ item_widget.index, item_widget.widget_rect });
                        if (!dvui.eventMatch(e, .{
                            .id = item_widget.widget_id,
                            .r = item_widget.widget_rect,
                        })) continue;

                        log.debug("clicked menu item {d}: {t}\n", .{ item_widget.index, item_widget.item.value });
                        if (try menu.selectItem(app, item_widget.item)) {
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

    /// Returns true if the app should close
    pub fn selectItem(menu: *Menu, app: *App, item: *Item) !bool {
        switch (item.value) {
            .menu => |next_menu| {
                menu._state = .init;
                try app.screen_stack.append(app.gpa, .{ .menu = next_menu });
            },
            .site_form => |next_site_form| {
                menu._state = .init;
                try app.screen_stack.append(app.gpa, .{ .site_form = next_site_form });
            },
            .site => |site| if (site.run()) {
                return true;
            } else {
                return error.OpenSiteFailure;
            },
            .none => {},
        }
        return false;
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

/// Asserts that `format` is valid and contains only placeholders contained in `values`.
/// Caller owns returned memory
fn formatFields(gpa: Allocator, format: []const u8, values: FormField.Values) ![]const u8 {
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

pub const SiteForm = struct {
    format: []const u8,
    fields: FormFields,

    const log = std.log.scoped(.@"branch.SiteForm");

    pub fn init(gpa: Allocator, format: []const u8, fields: FormFields) Allocator.Error!SiteForm {
        return .{
            .format = try gpa.dupe(u8, format),
            .fields = fields,
        };
    }
    pub fn deinit(form: *SiteForm, gpa: Allocator) void {
        gpa.free(form.format);
        form.fields.deinit(gpa);
    }

    pub fn drawWindow(form: *SiteForm, app: *App) !dvui.App.Result {
        const arena = app.frame_arena.allocator();
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
            const formatted_url = try formatFields(arena, form.format, field_values);
            const site: Site = .{
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
