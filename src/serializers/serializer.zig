const std = @import("std");
const Writer = std.io.Writer;

pub const Serializer = struct {
    pub fn serialize(comptime T: type, data: *const T, writer: *Writer) !void {
        const info = @typeInfo(T);

        switch (info) {
            .@"struct" => |struct_info| {
                if (@hasDecl(T, "serialize")) {
                    try T.serialize(data, writer);
                    return;
                }

                inline for (struct_info.fields) |field| {
                    const field_value = @field(data.*, field.name);
                    try serializeField(field.type, &field_value, writer, T, field.name);
                }
            },
            else => try serializeField(T, data, writer, T, null),
        }
    }

    fn serializeField(comptime T: type, data: *const T, writer: *Writer, comptime ParentType: type, comptime field_name: ?[]const u8) !void {
        const info = @typeInfo(T);
        switch (info) {
            .bool => try writeBool(writer, T, data.*),
            .int => try writeInt(writer, T, data.*, .little),
            .float => try writeFloat(writer, T, data.*),
            .@"enum" => try writeEnum(writer, T, data.*),
            .array => |array_info| {
                try writeInt(writer, usize, data.*.len, .little);
                for (data.*) |elem| {
                    try serialize(array_info.child, &elem, writer);
                }
            },
            .pointer => |ptr_info| {
                switch (ptr_info.size) {
                    .Slice => {
                        try writeInt(writer, usize, data.*.len, .little);
                        for (data.*) |elem| {
                            try serialize(ptr_info.child, &elem, writer);
                        }
                    },
                    else => @compileError("Unsupported pointer type in " ++ @typeName(ParentType) ++ (if (field_name) |name| "." ++ name else "")),
                }
            },
            .@"struct" => try serialize(T, data, writer), // Recursive call for nested structs
            else => @compileError("Unsupported type: " ++ @typeName(T) ++ (if (field_name) |name| " in field " ++ name else "")),
        }
    }
};

inline fn writeBool(writer: *Writer, comptime T: type, value: T) !void {
    var bytes: [1]u8 = undefined;
    @memcpy(&bytes, std.mem.asBytes(&value));
    try writer.writeAll(&bytes);
}

inline fn writeInt(writer: *Writer, comptime T: type, value: T, endian: std.builtin.Endian) !void {
    try writer.writeInt(T, value, endian);
}

/// Asserts the `buffer` was initialized with a capacity of at least `@sizeOf(T)` bytes.
/// This is a mimic from std.io.Writer.writeInt but for floats.
inline fn writeFloat(writer: *Writer, comptime T: type, value: T) !void {
    var bytes: [@divExact(@typeInfo(T).float.bits, 8)]u8 = undefined;
    @memcpy(&bytes, std.mem.asBytes(&value));
    try writer.writeAll(&bytes);
}

inline fn writeEnum(writer: *Writer, comptime T: type, value: T) !void {
    const enum_value = @intFromEnum(value);
    var bytes: [try std.math.divCeil(u32, @typeInfo(@typeInfo(T).@"enum".tag_type).int.bits, 8)]u8 = undefined;
    std.mem.writeInt(std.math.ByteAlignedInt(@TypeOf(enum_value)), &bytes, enum_value, .little);
    try writer.writeAll(&bytes);
}
