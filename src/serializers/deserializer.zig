const std = @import("std");
const Reader = std.io.Reader;

pub const Deserializer = struct {
    pub fn deserialize(comptime T: type, reader: *Reader, allocator: std.mem.Allocator) !T {
        const info = @typeInfo(T);

        switch (info) {
            .@"struct" => |struct_info| {
                if (@hasDecl(T, "deserialize")) {
                    return try T.deserialize(reader, allocator);
                }

                var result: T = undefined;
                inline for (struct_info.fields) |field| {
                    @field(result, field.name) = try deserializeField(field.type, reader, allocator, T, field.name);
                }
                return result;
            },
            else => return try deserializeField(T, reader, allocator, T, null),
        }
    }

    fn deserializeField(comptime T: type, reader: *Reader, allocator: std.mem.Allocator, comptime ParentType: type, comptime field_name: ?[]const u8) !T {
        const info = @typeInfo(T);
        switch (info) {
            .bool => return try readBool(reader),
            .int => return try readInt(reader, T, .little),
            .float => return try readFloat(reader, T),
            .@"enum" => return try readEnum(reader, T),
            .array => |array_info| {
                const length = try readInt(reader, usize, .little);
                if (length != array_info.len) {
                    return error.InvalidArrayLength;
                }

                var result: T = undefined;
                for (&result) |*elem| {
                    elem.* = try deserialize(array_info.child, reader, allocator);
                }
                return result;
            },
            .pointer => |ptr_info| {
                switch (ptr_info.size) {
                    .Slice => {
                        const length = try readInt(reader, usize, .little);
                        const slice = try allocator.?.alloc(ptr_info.child, length);
                        for (slice) |*elem| elem.* = try deserialize(ptr_info.child, reader, allocator);
                        return slice;
                    },
                    else => @compileError("Unsupported pointer type in " ++ @typeName(ParentType) ++ (if (field_name) |name| "." ++ name else "")),
                }
            },
            .@"struct" => return deserialize(T, reader, allocator),
            else => @compileError("Unsupported type: " ++ @typeName(T) ++ (if (field_name) |name| " in field " ++ name else "")),
        }
    }
};

inline fn readBool(reader: *Reader, comptime T: type) !T {
    const bytes = try reader.take(1);
    return @as(T, @bitCast(bytes[0]));
}

inline fn readInt(reader: *Reader, comptime T: type, endian: std.builtin.Endian) !T {
    return reader.takeInt(T, endian);
}

inline fn readFloat(reader: *Reader, comptime T: type) !T {
    const bytes = try reader.take(@divExact(@typeInfo(T).float.bits, 8));
    return @as(T, @bitCast(bytes));
}

inline fn readEnum(reader: *Reader, comptime T: type) !T {
    const TagType = @typeInfo(T).@"enum".tag_type;
    const bytes = try reader.take(try std.math.divCeil(u32, @typeInfo(TagType).int.bits, 8));
    const enum_value = std.mem.readInt(std.math.ByteAlignedInt(TagType), &bytes, .little);
    return @as(T, @enumFromInt(enum_value));
}
