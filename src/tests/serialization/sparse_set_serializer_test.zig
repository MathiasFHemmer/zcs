const std = @import("std");
const Entity = @import("../../ecs.zig").Entity;
const t = std.testing;
const SparseSet = @import("../../sparse_set.zig").SparseSet;
const Serializer = @import("zerializer").Serializer;
const SparseSetSerializer = @import("../../sparse_set_serializer.zig").SparseSetSerializer;

const Helper = @import("helper.zig");
const ComponentA = Helper.ComponentA;
const ComponentB = Helper.ComponentB;

test "'serializeSingle' should use component's 'serialize' implementation" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentB).empty;
    const serializer = SparseSetSerializer(ComponentB);
    defer set.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    var buffer: [4]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serializeSingle(&set, 1, &fbs);
    const actual: u32 = @bitCast(buffer);
    try t.expectEqual(42, actual);
}
test "'serializeSingle' should use default serializer implementation when no 'serialize' is implemented on component" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentA).empty;
    const serializer = SparseSetSerializer(ComponentA);

    defer set.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    var buffer: [4]u8 = .{ 0, 0, 0, 0 };
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serializeSingle(&set, 1, &fbs);
    const actual: u32 = @bitCast(buffer);
    try t.expectEqual(42, actual);
}
test "'deserializeSingle' should use component's 'deserialize' implementation" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentB).empty;
    var setToDeserialize = SparseSet(ComponentB).empty;
    const serializer = SparseSetSerializer(ComponentB);

    defer set.deinit(alloc);
    defer setToDeserialize.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    var buffer: [4]u8 = .{ 0, 0, 0, 0 };
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serializeSingle(&set, 1, &fbs);

    var fbr = std.io.Reader.fixed(buffer[0..]);
    const component = try serializer.deserializeSingle(alloc, &setToDeserialize, 2, &fbr);
    try t.expectEqual(42, component.fieldA);
}
test "'deserializeSingle' should use default deserialize implementation when no 'deserialize' is implemented on component" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentA).empty;
    var setToDeserialize = SparseSet(ComponentA).empty;
    const serializer = SparseSetSerializer(ComponentA);

    defer set.deinit(alloc);
    defer setToDeserialize.deinit(alloc);

    try set.add(alloc, 1, .{ .fieldA = 42 });

    var buffer: [4]u8 = .{ 0, 0, 0, 0 };
    var fbs = std.io.Writer.fixed(buffer[0..]);
    try serializer.serializeSingle(&set, 1, &fbs);

    var fbr = std.io.Reader.fixed(buffer[0..]);
    const component = try serializer.deserializeSingle(alloc, &setToDeserialize, 2, &fbr);
    try t.expectEqual(42, component.fieldA);
}

test "'serialize' should use component's 'serialize' implementation" {
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

    var reader = Helper.BufferReader.init(&buffer);

    try t.expectEqual(3, std.mem.bytesToValue(u64, try reader.readBytes(@sizeOf(u64))));
    try t.expectEqual(1, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(42, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
    try t.expectEqual(2, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(512, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
    try t.expectEqual(3, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(69, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
}
test "'serialize' should use default serializer implementation when no 'serialize' is implemented on component" {
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

    var reader = Helper.BufferReader.init(&buffer);

    try t.expectEqual(3, std.mem.bytesToValue(u64, try reader.readBytes(@sizeOf(u64))));
    try t.expectEqual(1, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(42, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
    try t.expectEqual(2, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(512, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
    try t.expectEqual(3, std.mem.bytesToValue(Entity, try reader.readBytes(@sizeOf(Entity))));
    try t.expectEqual(69, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
}
test "deserialize' should use component's 'deserialize' implementation" {
    const alloc = t.allocator;
    var set = SparseSet(ComponentB).empty;
    var setToDeserialize = SparseSet(ComponentB).empty;
    const serializer = SparseSetSerializer(ComponentB);
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

    try t.expectEqual(ComponentB{ .fieldA = 42 }, setToDeserialize.dense.items[0]);
    try t.expectEqual(ComponentB{ .fieldA = 43 }, setToDeserialize.dense.items[1]);
    try t.expectEqual(ComponentB{ .fieldA = 44 }, setToDeserialize.dense.items[2]);
}
test "deserialize' should use default deserializer implementation when no 'deserialize' is implemented on component" {
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
