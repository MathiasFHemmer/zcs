const std = @import("std");

pub const BufferReader = struct {
    data: []const u8,
    pos: usize,

    pub fn init(data: []const u8) BufferReader {
        return BufferReader{
            .data = data,
            .pos = 0,
        };
    }

    pub fn readBytes(self: *BufferReader, len: usize) ![]const u8 {
        if (self.pos + len > self.data.len) {
            return error.OutOfBounds;
        }
        const slice = self.data[self.pos .. self.pos + len];
        self.pos += len;
        return slice;
    }

    pub fn readBytesAs(self: *BufferReader, len: usize, returnType: type) ![]const returnType {
        if (self.pos + len > self.data.len) {
            return error.OutOfBounds;
        }
        const slice = self.data[self.pos .. self.pos + len];
        self.pos += len;
        return slice;
    }
};

pub const ShallowStruct = struct {
    u8: u8,
    u16: u16,
    u32: u32,
    u64: u64,
    u128: u128,
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,
    i128: i128,
    f16: f16,
    f32: f32,
    f64: f64,
    f128: f128,
    // f80: f80, Im not going to support f80 for now. Not sure if I should just byte align it or compact it somehow.
    bool: bool, // Currently using 1 byte per bool. Maybe bit pack it later.
    isize: isize,
    usize: usize,
    // Im skipping c types for now
    // c_char: c_char,
    // c_short: c_short,
    // c_ushort: c_ushort,
    // c_int: c_int,
    // c_uint: c_uint,
    // c_long: c_long,
    // c_ulong: c_ulong,
    // c_longlong: c_longlong,
    // c_ulonglong: c_ulonglong,
    // c_longdouble: c_longdouble,
    // anyopaque: anyopaque,
    // void: void,
    // noreturn: noreturn,
    // type: type,
    // anyerror: anyerror,
    // comptime_int: comptime_int, // Should I support comptime types?
    // comptime_float: comptime_float, // Should I support comptime types?
};

pub const ComponentA = struct { fieldA: u32 };

pub const ComponentB = struct {
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

pub const ComponentC = struct {
    fieldA: u32,
    pub fn serialize(self: *const ComponentC, writer: *std.io.Writer) !void {
        try writer.writeInt(u32, self.fieldA, .little);
    }
};

pub const EnumComponent = enum {
    A,
    B,
    C,
};
pub const EnumComponentTagged = enum(u32) {
    A,
    B,
    C = 5,
};
