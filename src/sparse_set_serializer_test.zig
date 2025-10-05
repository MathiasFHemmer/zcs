const std = @import("std");
const Entity = @import("ecs.zig").Entity;
const t = std.testing;
const SparseSet = @import("sparse_set.zig").SparseSet;
const Serializer = @import("serializers/serializer.zig").Serializer;
const SparseSetSerializer = @import("sparse_set_serializer.zig").SparseSetSerializer;

const BufferReader = struct {
    data: []const u8,
    pos: usize,

    pub fn readBytes(self: *BufferReader, len: usize) ![]const u8 {
        if (self.pos + len > self.data.len) {
            return error.OutOfBounds;
        }
        const slice = self.data[self.pos .. self.pos + len];
        self.pos += len;
        return slice;
    }
};

const ComponentA = struct { fieldA: u32 };

const ComponentB = struct {
    fieldA: u32,
    pub fn serialize(self: *const ComponentB, writer: *std.io.Writer) !void {
        try writer.writeInt(u32, self.fieldA, .little);
    }
    pub fn deserialize(reader: *std.io.Reader, allocator: std.mem.Allocator) !ComponentB {
        _ = allocator;
        return ComponentB{
            .fieldA = try reader.takeInt(u32, .little),
        };
    }
};

const ComponentC = struct {
    fieldA: u32,
    pub fn serialize(self: *ComponentC, writer: *std.io.Writer) !void {
        try writer.writeInt(u32, self.fieldA, .little);
    }
};

test "Serializing a struct with 'serializeSingle' method implemented show call it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentB).empty;
    const serializer = SparseSetSerializer(ComponentB);
    defer set.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    try t.expect(set.dense.items.len == 1);
    try t.expectEqual(ComponentB{ .fieldA = 42 }, set.dense.items[0]);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items.len == 1);
    try t.expect(set.entities.items[0] == 1);

    var buffer: [4]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serializeSingle(&set, 1, &fbs);
    const expected: u32 = @bitCast(buffer);
    try t.expect(expected == 42);
}

test "Serializing a struct without 'serializeSingle' should use default serializer implementation" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentA).empty;
    const serializer = SparseSetSerializer(ComponentA);

    defer set.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    try t.expect(set.dense.items.len == 1);
    try t.expectEqual(ComponentA{ .fieldA = 42 }, set.dense.items[0]);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items.len == 1);
    try t.expect(set.entities.items[0] == 1);

    var buffer: [4]u8 = .{ 0, 0, 0, 0 };
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serializeSingle(&set, 1, &fbs);
    const expected: u32 = @bitCast(buffer);
    try t.expect(expected == 42);
}

test "Deserializing a struct with 'deserializeSingle' method implemented show call it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentB).empty;
    var setToDeserialize = SparseSet(ComponentB).empty;
    const serializer = SparseSetSerializer(ComponentB);

    defer set.deinit(alloc);
    defer setToDeserialize.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    try t.expect(set.dense.items.len == 1);
    try t.expectEqual(ComponentB{ .fieldA = 42 }, set.dense.items[0]);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items.len == 1);
    try t.expect(set.entities.items[0] == 1);

    var buffer: [4]u8 = .{ 0, 0, 0, 0 };
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serializeSingle(&set, 1, &fbs);
    const expected: u32 = @bitCast(buffer);
    try t.expect(expected == 42);

    var fbr = std.io.Reader.fixed(buffer[0..]);
    const component = try serializer.deserializeSingle(alloc, &setToDeserialize, 2, &fbr);
    try t.expect(component.fieldA == 42);
}

test "Serializing a struct without 'serialize' method implemented show call it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentA).empty;
    const serializer = SparseSetSerializer(ComponentA);
    defer set.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    try t.expect(set.dense.items.len == 1);
    try t.expectEqual(ComponentA{ .fieldA = 42 }, set.dense.items[0]);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items.len == 1);
    try t.expect(set.entities.items[0] == 1);

    var buffer: [512]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serialize(&set, &fbs);

    var reader = BufferReader{
        .data = &buffer,
        .pos = 0,
    };

    try t.expectEqual(1, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(u64))));
    try t.expectEqual(1, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(42, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
}

test "Serializing multiple struct without 'serialize' method implemented show call it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentA).empty;
    const serializer = SparseSetSerializer(ComponentA);
    defer set.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });
    try set.add(alloc, 2, .{ .fieldA = 512 });
    try set.add(alloc, 3, .{ .fieldA = 69 });

    var buffer: [512]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serialize(&set, &fbs);

    var reader = BufferReader{
        .data = &buffer,
        .pos = 0,
    };

    try t.expectEqual(3, std.mem.bytesToValue(u64, try reader.readBytes(@sizeOf(u64))));
    try t.expectEqual(1, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(42, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
    try t.expectEqual(2, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(512, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
    try t.expectEqual(3, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(69, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
}

test "Serializing multiple struct with 'serialize' method implemented show call it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentB).empty;
    const serializer = SparseSetSerializer(ComponentB);
    defer set.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });
    try set.add(alloc, 2, .{ .fieldA = 512 });
    try set.add(alloc, 3, .{ .fieldA = 69 });

    var buffer: [512]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serialize(&set, &fbs);

    var reader = BufferReader{
        .data = &buffer,
        .pos = 0,
    };

    try t.expectEqual(3, std.mem.bytesToValue(u64, try reader.readBytes(@sizeOf(u64))));
    try t.expectEqual(1, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(42, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
    try t.expectEqual(2, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(512, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
    try t.expectEqual(3, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(69, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
}

test "Deserializing a struct without 'serialize' method implemented show call it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentA).empty;
    var setToDeserialize = SparseSet(ComponentA).empty;
    const serializer = SparseSetSerializer(ComponentA);
    defer set.deinit(alloc);
    defer setToDeserialize.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    try t.expect(set.dense.items.len == 1);
    try t.expectEqual(ComponentA{ .fieldA = 42 }, set.dense.items[0]);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items.len == 1);
    try t.expect(set.entities.items[0] == 1);

    var buffer: [512]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serialize(&set, &fbs);

    var fbr = std.io.Reader.fixed(buffer[0..]);
    try serializer.deserialize(alloc, &setToDeserialize, &fbr);
    try t.expect(setToDeserialize.dense.items.len == 1);
    try t.expect(setToDeserialize.sparse.get(1) == 0);
    try t.expect(setToDeserialize.entities.items.len == 1);
    try t.expect(setToDeserialize.entities.items[0] == 1);
    try t.expectEqual(ComponentA{ .fieldA = 42 }, setToDeserialize.dense.items[0]);
}

test "Deserializing multiple struct without 'serialize' method implemented show call it" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentA).empty;
    var setToDeserialize = SparseSet(ComponentA).empty;
    const serializer = SparseSetSerializer(ComponentA);
    defer set.deinit(alloc);
    defer setToDeserialize.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });
    try set.add(alloc, 2, .{ .fieldA = 43 });
    try set.add(alloc, 3, .{ .fieldA = 44 });

    var buffer: [512]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serialize(&set, &fbs);

    var fbr = std.io.Reader.fixed(buffer[0..]);
    try serializer.deserialize(alloc, &setToDeserialize, &fbr);

    try t.expect(setToDeserialize.dense.items.len == 3);
    try t.expect(setToDeserialize.entities.items.len == 3);

    try t.expectEqual(0, setToDeserialize.sparse.get(1));
    try t.expectEqual(1, setToDeserialize.sparse.get(2));
    try t.expectEqual(2, setToDeserialize.sparse.get(3));

    try t.expect(setToDeserialize.entities.items[0] == 1);
    try t.expect(setToDeserialize.entities.items[1] == 2);
    try t.expect(setToDeserialize.entities.items[2] == 3);

    try t.expectEqual(ComponentA{ .fieldA = 42 }, setToDeserialize.dense.items[0]);
    try t.expectEqual(ComponentA{ .fieldA = 43 }, setToDeserialize.dense.items[1]);
    try t.expectEqual(ComponentA{ .fieldA = 44 }, setToDeserialize.dense.items[2]);
}
