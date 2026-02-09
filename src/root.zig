const std = @import("std");
const dvui = @import("dvui");

pub const App = struct {
    gpa: std.mem.Allocator,
    frame_arena: std.heap.ArenaAllocator,
    menu_stack: std.ArrayList(*Menu),
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
            menu: Menu,
            none, // NOTE: Placeholder
        },
    };

    pub fn deinit(menu: *Menu, gpa: std.mem.Allocator) void {
        for (menu.items.items) |item| switch (item.value) {
            .menu => |*m| @constCast(m).deinit(gpa),
            .none => {},
        };
        menu.items.deinit(gpa);
    }

    pub fn drawWindow(menu: *Menu, app: *App) !void {
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
                        } else if (app.menu_stack.items.len > 1) {
                            menu._state = .init;
                            _ = app.menu_stack.pop();
                        },
                        else => |key_code| for (item_widgets.items) |item_widget| {
                            if (key_code != item_widget.item.key) continue;

                            log.debug("clicked menu item {d}: {t}\n", .{ item_widget.index, item_widget.item.value });
                            switch (item_widget.item.value) {
                                .menu => |*next_menu| {
                                    menu._state = .init;
                                    try app.menu_stack.append(app.gpa, next_menu);
                                },
                                .none => {},
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
                            .debug = true,
                        })) continue;

                        log.debug("clicked menu item {d}: {t}\n", .{ item_widget.index, item_widget.item.value });
                        switch (item_widget.item.value) {
                            .menu => |*next_menu| {
                                menu._state = .init;
                                try app.menu_stack.append(app.gpa, next_menu);
                            },
                            .none => {},
                        }

                        break;
                    } else continue;
                },
                else => continue :events,
            }
            e.handle(@src(), wd);
        }
    }
};
