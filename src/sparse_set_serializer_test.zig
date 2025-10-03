const std = @import("std");
const t = std.testing;
const SparseSet = @import("sparse_set.zig").SparseSet;
const SparseSetSerializer = @import("sparse_set_serializer.zig").SparseSetSerializer;

const ComponentA = struct { fieldA: u32 };

const ComponentB = struct {
    fieldA: u32,
    pub fn serialize(self: *ComponentB, writer: *std.io.Writer) !void {
        try writer.writeInt(u32, self.fieldA, .little);
    }
    pub fn deserialize(self: *ComponentB, reader: *std.io.Reader) !void {
        self.fieldA = try reader.takeInt(u32, .little);
    }
};

const ComponentC = struct {
    fieldA: u32,
    pub fn serialize(self: *ComponentC, writer: *std.io.Writer) !void {
        try writer.writeInt(u32, self.fieldA, .little);
    }
};

test "Serializing a struct with 'serialize' method implemented show call it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentB).empty;
    const serializer = SparseSetSerializer(SparseSet(ComponentB));
    defer set.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    try t.expect(set.dense.items.len == 1);
    try t.expectEqual(ComponentB{ .fieldA = 42 }, set.dense.items[0]);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items.len == 1);
    try t.expect(set.entities.items[0] == 1);

    var buffer: [4]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serialize(1, &fbs);
    const expected: u32 = @bitCast(buffer);
    try t.expect(expected == 42);
}

test "Serializing a struct without 'serialize' method implemented show skip it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentA).init(alloc);
    defer set.deinit();

    try set.add(1, .{ .fieldA = 42 });

    try t.expect(set.dense.items.len == 1);
    try t.expectEqual(ComponentA{ .fieldA = 42 }, set.dense.items[0]);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items.len == 1);
    try t.expect(set.entities.items[0] == 1);

    var buffer: [4]u8 = .{ 0, 0, 0, 0 };
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try set.serialize(1, &fbs);
    const expected: u32 = @bitCast(buffer);
    try t.expect(expected == 0);
}

test "Deserializing a struct with 'deserialize' method implemented show call it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentB).init(alloc);
    defer set.deinit();

    try set.add(1, .{ .fieldA = 42 });

    try t.expect(set.dense.items.len == 1);
    try t.expectEqual(ComponentB{ .fieldA = 42 }, set.dense.items[0]);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items.len == 1);
    try t.expect(set.entities.items[0] == 1);

    var buffer: [4]u8 = .{ 0, 0, 0, 0 };
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try set.serialize(1, &fbs);
    const expected: u32 = @bitCast(buffer);
    try t.expect(expected == 42);

    var fbr = std.io.Reader.fixed(buffer[0..]);
    const component = try set.deserialize(2, &fbr);
    try t.expect(component.fieldA == 42);
}
