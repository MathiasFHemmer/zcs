const std = @import("std");
const math = std.math;
const t = std.testing;
const Helper = @import("helper.zig");
const SparseSet = @import("../../sparse_set.zig").SparseSet;
const Serializer = @import("../../serialization/serializer.zig").Serializer;

const EnumComponentTagged = Helper.EnumComponentTagged;
const EnumComponent = Helper.EnumComponent;

test "Serializing primitive type" {
    var data: u32 = 1;

    var buffer: [4]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);

    try Serializer.serialize(u32, &data, &fbs);
    const actual: u32 = @bitCast(buffer);
    try t.expectEqual(data, actual);
}

test "Serializing shallow struct type" {
    const data: Helper.ShallowStruct = .{
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

    var buffer: [1024]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);

    try Serializer.serialize(Helper.ShallowStruct, &data, &fbs);

    var reader = Helper.BufferReader.init(&buffer);

    // NOTICE THIS WILL ONLY WORK ON .little ENDIANESS MACHINES!
    // SERIALIZER ALWAYS WRITES LITTLE
    // std.mem.bytesToValue
    try t.expectEqual(data.u8, std.mem.bytesToValue(u8, try reader.readBytes(@sizeOf(u8))));
    try t.expectEqual(data.u16, std.mem.bytesToValue(u16, try reader.readBytes(@sizeOf(u16))));
    try t.expectEqual(data.u32, std.mem.bytesToValue(u32, try reader.readBytes(@sizeOf(u32))));
    try t.expectEqual(data.u64, std.mem.bytesToValue(u64, try reader.readBytes(@sizeOf(u64))));
    try t.expectEqual(data.u128, std.mem.bytesToValue(u128, try reader.readBytes(@sizeOf(u128))));
    try t.expectEqual(data.i8, std.mem.bytesToValue(i8, try reader.readBytes(@sizeOf(i8))));
    try t.expectEqual(data.i16, std.mem.bytesToValue(i16, try reader.readBytes(@sizeOf(i16))));
    try t.expectEqual(data.i32, std.mem.bytesToValue(i32, try reader.readBytes(@sizeOf(i32))));
    try t.expectEqual(data.i64, std.mem.bytesToValue(i64, try reader.readBytes(@sizeOf(i64))));
    try t.expectEqual(data.i128, std.mem.bytesToValue(i128, try reader.readBytes(@sizeOf(i128))));
    try t.expectEqual(data.f16, std.mem.bytesToValue(f16, try reader.readBytes(@sizeOf(f16))));
    try t.expectEqual(data.f32, std.mem.bytesToValue(f32, try reader.readBytes(@sizeOf(f32))));
    try t.expectEqual(data.f64, std.mem.bytesToValue(f64, try reader.readBytes(@sizeOf(f64))));
    try t.expectEqual(data.f128, std.mem.bytesToValue(f128, try reader.readBytes(@sizeOf(f128))));
    try t.expectEqual(data.bool, std.mem.bytesToValue(bool, try reader.readBytes(@sizeOf(bool))));
    try t.expectEqual(data.isize, std.mem.bytesToValue(isize, try reader.readBytes(@sizeOf(isize))));
    try t.expectEqual(data.usize, std.mem.bytesToValue(usize, try reader.readBytes(@sizeOf(usize))));
}

test "Serializing enum type" {
    var data: EnumComponentTagged = .C;

    var buffer: [4]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);

    try Serializer.serialize(EnumComponentTagged, &data, &fbs);
    const actual: u32 = @bitCast(buffer);
    try t.expectEqual(@intFromEnum(data), actual);
}

const ComplexStruct = struct {
    fieldA: struct { innerFieldA: EnumComponentTagged },
    fieldB: [8]u8,
    fieldC: [4]EnumComponentTagged,
    fieldD: struct { innerFieldA: f32, innerFieldB: u32 },
};
test "Serializing complext struct" {
    var data: ComplexStruct = .{
        .fieldA = .{ .innerFieldA = .B },
        .fieldB = .{ 1, 2, 3, 4, 5, 6, 7, 8 },
        .fieldC = .{ .A, .B, .C, .A },
        .fieldD = .{ .innerFieldA = 3.4, .innerFieldB = 2 },
    };

    var buffer: [512]u8 = undefined;
    var fbs = std.io.Writer.fixed(buffer[0..]);

    try Serializer.serialize(ComplexStruct, &data, &fbs);
}
