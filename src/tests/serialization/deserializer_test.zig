const std = @import("std");
const math = std.math;
const t = std.testing;
const SparseSet = @import("../../sparse_set.zig").SparseSet;
const Helper = @import("helper.zig");
const Serializer = @import("../serialization/serializer.zig").Serializer;
const Deserializer = @import("../serialization/deserializer.zig").Deserializer;

test "Deserializing primitive type" {
    const original_data: u32 = 1;

    // Serialize first
    var buffer: [4]u8 = undefined;
    var reader = std.io.Reader.fixed(&buffer);
    var writer = std.io.Writer.fixed(&buffer);

    try Serializer.serialize(u32, &original_data, &writer);

    // Deserialize
    const deserialized_data = try Deserializer.deserialize(u32, &reader, null);
    // std.debug.print("Yoo: {d}", .{deserialized_data});
    try t.expectEqual(original_data, deserialized_data);
}

test "Deserializing shallow struct type" {
    const original_data = Helper.ShallowStruct{
        .u8 = math.maxInt(u8),
        .u16 = math.maxInt(u16),
        .u32 = math.maxInt(u32),
        .u64 = math.maxInt(u64),
        .u128 = math.maxInt(u128),
        .i8 = math.minInt(i8),
        .i16 = math.minInt(i16),
        .i32 = math.minInt(i32),
        .i64 = math.minInt(i64),
        .i128 = math.minInt(i128),
        .f16 = math.floatMax(f16),
        .f32 = math.floatMax(f32),
        .f64 = math.floatMax(f64),
        .f128 = math.floatMax(f128),
        .bool = true,
        .isize = math.minInt(isize),
        .usize = math.maxInt(usize),
    };

    // Serialize
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    try Serializer.serialize(Helper.ShallowStruct, &original_data, writer);

    // Reset stream for reading
    fbs.pos = 0;
    const reader = fbs.reader();

    // Deserialize
    const deserialized_data = try Deserializer.deserialize(Helper.ShallowStruct, reader, null);

    // Verify all fields match
    try t.expectEqual(original_data.u8, deserialized_data.u8);
    try t.expectEqual(original_data.u16, deserialized_data.u16);
    try t.expectEqual(original_data.u32, deserialized_data.u32);
    try t.expectEqual(original_data.u64, deserialized_data.u64);
    try t.expectEqual(original_data.u128, deserialized_data.u128);
    try t.expectEqual(original_data.i8, deserialized_data.i8);
    try t.expectEqual(original_data.i16, deserialized_data.i16);
    try t.expectEqual(original_data.i32, deserialized_data.i32);
    try t.expectEqual(original_data.i64, deserialized_data.i64);
    try t.expectEqual(original_data.i128, deserialized_data.i128);
    try t.expectEqual(original_data.f16, deserialized_data.f16);
    try t.expectEqual(original_data.f32, deserialized_data.f32);
    try t.expectEqual(original_data.f64, deserialized_data.f64);
    try t.expectEqual(original_data.f128, deserialized_data.f128);
    try t.expectEqual(original_data.bool, deserialized_data.bool);
    try t.expectEqual(original_data.isize, deserialized_data.isize);
    try t.expectEqual(original_data.usize, deserialized_data.usize);
}

// test "Deserializing enum type" {
//     const original_data: EnumComponentTagged = .C;

//     // Serialize
//     var buffer: [4]u8 = undefined;
//     var fbs = std.io.fixedBufferStream(&buffer);
//     const writer = fbs.writer();

//     try Serializer.serialize(EnumComponentTagged, &original_data, writer);

//     // Reset stream for reading
//     fbs.pos = 0;
//     const reader = fbs.reader();

//     // Deserialize
//     const deserialized_data = try Deserializer.deserialize(EnumComponentTagged, reader, null);
//     try t.expectEqual(original_data, deserialized_data);
//     try t.expectEqual(@intFromEnum(original_data), @intFromEnum(deserialized_data));
// }

// test "Deserializing complex struct" {
//     const original_data = ComplexStruct{
//         .fieldA = .{ .innerFieldA = .B },
//         .fieldB = .{ 1, 2, 3, 4, 5, 6, 7, 8 },
//         .fieldC = .{ .A, .B, .C, .A },
//         .fieldD = .{ .innerFieldA = 3.4, .innerFieldB = 2 },
//     };

//     // Serialize
//     var buffer: [512]u8 = undefined;
//     var fbs = std.io.fixedBufferStream(&buffer);
//     const writer = fbs.writer();

//     try Serializer.serialize(ComplexStruct, &original_data, writer);

//     // Reset stream for reading
//     fbs.pos = 0;
//     const reader = fbs.reader();

//     // Deserialize
//     const deserialized_data = try Deserializer.deserialize(ComplexStruct, reader, null);

//     // Verify nested structures
//     try t.expectEqual(original_data.fieldA.innerFieldA, deserialized_data.fieldA.innerFieldA);

//     // Verify arrays
//     for (original_data.fieldB, 0..) |expected, i| {
//         try t.expectEqual(expected, deserialized_data.fieldB[i]);
//     }

//     for (original_data.fieldC, 0..) |expected, i| {
//         try t.expectEqual(expected, deserialized_data.fieldC[i]);
//     }

//     // Verify nested struct with primitive fields
//     try t.expectEqual(original_data.fieldD.innerFieldA, deserialized_data.fieldD.innerFieldA);
//     try t.expectEqual(original_data.fieldD.innerFieldB, deserialized_data.fieldD.innerFieldB);
// }

// // Additional test for arrays with allocator (if your deserializer supports slices)
// test "Deserializing slice type" {
//     const allocator = t.allocator;
//     const original_data = [_]u32{ 1, 2, 3, 4, 5 };

//     // Serialize
//     var buffer: [256]u8 = undefined;
//     var fbs = std.io.fixedBufferStream(&buffer);
//     const writer = fbs.writer();

//     try Serializer.serialize([]const u32, &original_data, writer);

//     // Reset stream for reading
//     fbs.pos = 0;
//     const reader = fbs.reader();

//     // Deserialize with allocator
//     const deserialized_slice = try Deserializer.deserialize([]u32, reader, allocator);
//     defer allocator.free(deserialized_slice);

//     try t.expectEqual(original_data.len, deserialized_slice.len);
//     for (original_data, deserialized_slice) |expected, actual| {
//         try t.expectEqual(expected, actual);
//     }
// }
