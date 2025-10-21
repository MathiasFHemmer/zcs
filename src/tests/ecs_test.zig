const builtin = @import("builtin");
const std = @import("std");
const t = std.testing;
const ECS = @import("../ecs.zig").ECS;
const Entity = @import("../ecs.zig").Entity;

const Helper = @import("serialization/helper.zig");
const ComponentA = Helper.ComponentA;
const ComponentB = Helper.ComponentB;
const ComponentC = Helper.ComponentC;

const TestWorldUnionTag = union(enum(u8)) {
    componentA: ComponentA = 12,
    componentB: ComponentB = 5,
    componentC: ComponentC = 1,
};

const ecs = ECS(TestWorldUnionTag, .{});

test {
    const alloc = t.allocator;

    const typeInfo = @typeInfo(TestWorldUnionTag).@"union";
    const world = try ecs.init(alloc);
    inline for (typeInfo.fields) |field| {
        try t.expect(@hasField(@TypeOf(world.componentStorage), field.name));
    }
}

test "Component ECS serializes metadata" {
    const alloc = t.allocator;

    var world = try ecs.init(alloc);
    try world.componentStorage.componentA.add(alloc, 1, .{ .fieldA = 42 });
    try world.componentStorage.componentB.add(alloc, 1, .{ .fieldA = 15 });
    defer world.deinit();

    var buffer: [512]u8 = undefined;
    @memset(&buffer, 0);

    var writer = std.io.Writer.fixed(buffer[0..]);

    const version = try std.SemanticVersion.parse("1.0.0");
    try world.serialize(&writer, version);

    var reader = Helper.BufferReader.init(&buffer);

    const versionBytes = [_]u8{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    // [u32] Component Tag ID
    // [u32] Component SparseSet length
    // [u32] ComponentA.fieldA
    const componentABytes = [_]u8{
        12, 0, 0, 0, // (little endian ComponentA tag)
        1, 0, 0, 0, 0, 0, 0, 0, // (little endian ComponentA SparseSet length)
        1, 0, 0, 0, // (little endian ComponentA~entity id)
        42, 0, 0, 0, // (little endian ComponentA fieldA)
        5, 0, 0, 0, // (little endian ComponentB tag)
        1, 0, 0, 0, 0, 0, 0, 0, // (little endian ComponentA SparseSet length)
        1, 0, 0, 0, // (little endian ComponentB~entity id)
        15, 0, 0, 0, // (little endian ComponentB fieldA)
    };

    try t.expectEqualSlices(u8, &versionBytes, try reader.readBytes(@sizeOf(u32) * 3));
    try t.expectEqualSlices(u8, componentABytes[0..4], try reader.readBytes(@sizeOf(u32)));
    try t.expectEqualSlices(u8, componentABytes[4..12], try reader.readBytes(@sizeOf(u64)));
    try t.expectEqualSlices(u8, componentABytes[12..16], try reader.readBytes(@sizeOf(u32)));
    try t.expectEqualSlices(u8, componentABytes[16..20], try reader.readBytes(@sizeOf(u32)));
    try t.expectEqualSlices(u8, componentABytes[20..24], try reader.readBytes(@sizeOf(u32)));
    try t.expectEqualSlices(u8, componentABytes[24..28], try reader.readBytes(@sizeOf(u32)));
    try t.expectEqualSlices(u8, componentABytes[28..32], try reader.readBytes(@sizeOf(u32)));

    _ = writer.consumeAll();
}

test "Component ECS deserializes metadata" {
    const alloc = t.allocator;

    var world = try ecs.init(alloc);
    try world.componentStorage.componentA.add(alloc, 1, .{ .fieldA = 42 });
    try world.componentStorage.componentB.add(alloc, 1, .{ .fieldA = 15 });
    defer world.deinit();

    var buffer: [512]u8 = undefined;
    @memset(&buffer, 0);

    var writer = std.io.Writer.fixed(buffer[0..]);

    const version = try std.SemanticVersion.parse("1.0.0");
    try world.serialize(&writer, version);

    var reader = std.io.Reader.fixed(buffer[0..]);

    var worldToDeserialize = try ecs.init(alloc);
    defer worldToDeserialize.deinit();

    const versionDeserialized = try worldToDeserialize.deserialize(&reader, version);

    try t.expectEqual(1, versionDeserialized.major);

    _ = writer.consumeAll();
}

// test "Component ECS serializes component field" {
//     const alloc = t.allocator;

//     var world = try ecs.init(alloc);
//     world.addComponent(1, ComponentB{ .fieldA = 42 });
//     defer world.deinit();

//     var buffer: [512]u8 = undefined;
//     @memset(&buffer, 0);

//     var fbs = std.io.Writer.fixed(buffer[0..]);
//     const version = try std.SemanticVersion.parse("1.0.0");

//     try world.serialize(1, &fbs, version);

//     const array = [_]u32{ 1, 0, 0, 1, 1, 42 };

//     try t.expectEqualSlices(u8, buffer[0..24], std.mem.asBytes(&array));

//     _ = fbs.consumeAll();
// }

// test "Component ECS deserializes component field" {
//     const alloc = t.allocator;

//     var world = try ecs.init(alloc);
//     defer world.deinit();

//     const data = [6]u32{ 1, 0, 0, 1, 1, 42 };
//     const bytes = std.mem.asBytes(&data);

//     var fbr = std.io.Reader.fixed(bytes);
//     const version = try std.SemanticVersion.parse("1.0.0");

//     const expectedVersion = try world.deserialize(&fbr, version);
//     try t.expect(world.nextEntity == 1);
//     try t.expect(version.major == expectedVersion.major);
//     try t.expect(version.minor == expectedVersion.minor);
// }
