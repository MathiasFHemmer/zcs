const std = @import("std");
const t = std.testing;
const ECS = @import("ecs.zig").ECS;
const Entity = @import("ecs.zig").Entity;

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

const TestWorldUnionTag = union(enum(u8)) {
    componentA: ComponentA,
    componentB: ComponentB,
    componentC: ComponentC,
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
    defer world.deinit();

    var buffer: [512]u8 = undefined;
    @memset(&buffer, 0);

    var fbs = std.io.Writer.fixed(buffer[0..]);
    const version = try std.SemanticVersion.parse("1.0.0");

    try world.serialize(1, &fbs, version);

    const array = [4]u32{ 1, 0, 0, 1 };

    try t.expectEqualSlices(u8, buffer[0..16], std.mem.asBytes(&array));

    _ = fbs.consumeAll();
}

// test "Component ECS deserializes metadata" {
//     const alloc = t.allocator;

//     var world = try ecs.init(alloc);
//     defer world.deinit();

//     const data = [4]u32{ 1, 0, 0, 1 };
//     const bytes = std.mem.asBytes(&data);

//     var fbr = std.io.Reader.fixed(bytes);
//     const version = try std.SemanticVersion.parse("1.0.0");

//     const expectedVersion = try world.deserialize(&fbr, version);
//     try t.expect(world.nextEntity == 1);
//     try t.expect(version.major == expectedVersion.major);
//     try t.expect(version.minor == expectedVersion.minor);
// }

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
