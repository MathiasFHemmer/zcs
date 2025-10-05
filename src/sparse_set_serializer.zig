const std = @import("std");
const Entity = @import("ecs.zig").Entity;
const Serializer = @import("serializers/serializer.zig").Serializer;
const Deserializer = @import("serializers/deserializer.zig").Deserializer;
const SparseSet = @import("sparse_set.zig").SparseSet;

pub fn SparseSetSerializer(comptime SetType: type) type {
    return struct {
        pub fn serialize(sparseSet: *SparseSet(SetType), writer: *std.io.Writer) !void {
            const len = sparseSet.length();
            try writer.writeInt(u64, len, .little);
            var iterator = sparseSet.sparse.iterator();
            while (iterator.next()) |item| {
                try writer.writeInt(Entity, item.key_ptr.*, .little);
                const ent = &sparseSet.dense.items[item.value_ptr.*];
                try Serializer.serialize(SetType, ent, writer);
            }
        }

        pub fn serializeSingle(sparseSet: *SparseSet(SetType), entity: Entity, writer: *std.io.Writer) !void {
            if (sparseSet.sparse.get(entity)) |idx| {
                const item = &sparseSet.dense.items[idx];
                try Serializer.serialize(SetType, item, writer);
            }
        }

        pub fn deserialize(allocator: std.mem.Allocator, sparseSet: *SparseSet(SetType), reader: *std.io.Reader) !void {
            const len = try reader.takeInt(u64, .little);
            try sparseSet.ensureCapacity(allocator, @intCast(len));
            for (0..len) |_| {
                const entity = try reader.takeInt(Entity, .little);
                const item = try sparseSet.create(allocator, entity);
                item.* = try Deserializer.deserialize(SetType, reader, allocator);
            }
        }

        pub fn deserializeSingle(allocator: std.mem.Allocator, sparseSet: *SparseSet(SetType), entity: Entity, reader: *std.io.Reader) !*SetType {
            const item = try sparseSet.create(allocator, entity);
            item.* = try Deserializer.deserialize(SetType, reader, allocator);
            return item;
        }
    };
}
