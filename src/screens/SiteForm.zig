const std = @import("std");
const Allocator = std.mem.Allocator;
const dvui = @import("dvui");

const form = @import("form.zig");
const branch = @import("../root.zig");

const SiteForm = @This();

format: []const u8,
fields: form.Fields,

const log = std.log.scoped(.@"branch.SiteForm");

pub fn init(gpa: Allocator, format: []const u8, fields: form.Fields) Allocator.Error!SiteForm {
    return .{
        .format = try gpa.dupe(u8, format),
        .fields = fields,
    };
}
pub fn deinit(sf: *SiteForm, gpa: Allocator) void {
    gpa.free(sf.format);
    sf.fields.deinit(gpa);
}

pub fn drawWindow(sf: *SiteForm, app: *branch.App) !dvui.App.Result {
    const arena = app.frame_arena.allocator();
    var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
    });
    defer vbox.deinit();

    var field_values = try form.Field.allocValues(
        arena,
        sf.fields.entries.len,
    );
    var enter_pressed = false;
    var it = sf.fields.iterator();
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
        const formatted_url = try form.formatFields(arena, sf.format, field_values);
        const site: branch.Site = .{
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
