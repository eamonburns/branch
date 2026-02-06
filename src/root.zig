const std = @import("std");
const dvui = @import("dvui");

pub const App = struct {
    gpa: std.mem.Allocator,
    frame_arena: std.heap.ArenaAllocator,
    // TODO: This should be a "stack" of pointers to menus, and
    // then there should be a "root" menu that starts out as the
    // first "current menu" at the top of the stack
    current_menu: Menu,
};

pub const Menu = struct {
    show_filter: bool = false,
    items: std.ArrayList(Item) = .empty,
    should_focus_filter: bool = false,

    const log = std.log.scoped(.@"branch/Menu");

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
        _ = app;
        var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
        });
        defer vbox.deinit();

        const filter = if (menu.show_filter) blk: {
            var filter_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .gravity_x = 1,
                .expand = .horizontal,
            });
            defer filter_box.deinit();

            var input = dvui.textEntry(@src(), .{}, .{
                .expand = .horizontal,
            });
            defer input.deinit();
            if (menu.should_focus_filter) dvui.focusWidget(input.data().id, null, null);

            break :blk input.textGet();
        } else "";

        for (menu.items.items, 0..) |item, i| {
            if (filter.len > 0 and !std.mem.containsAtLeast(u8, item.name, 1, filter)) continue;

            var item_box = dvui.box(@src(), .{ .dir = .vertical }, .{
                .id_extra = i,
                .expand = .horizontal,
                .background = true,
                .border = .all(1),
            });
            defer item_box.deinit();

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

        menu.should_focus_filter = false;
        const wd = dvui.currentWindow().data();
        for (dvui.events()) |*e| {
            if (e.evt != .key or e.evt.key.action != .down) continue;
            switch (e.evt.key.code) {
                .slash => {
                    menu.should_focus_filter = true;
                    menu.show_filter = true;
                },
                .escape => {
                    menu.show_filter = false;
                },
                else => continue,
            }
            log.debug("key event: {t}", .{e.evt.key.code});
            e.handle(@src(), wd);
        }
    }
};
