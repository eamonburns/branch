//! Utilities for writing `*Form` screens

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Asserts that `format` is valid and contains only placeholders contained in `values`.
/// Caller owns returned memory
pub fn formatFields(gpa: Allocator, format: []const u8, values: Field.Values) ![]const u8 {
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

pub const Fields = std.StringArrayHashMapUnmanaged(Field);
pub const Field = struct {
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
