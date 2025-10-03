const std = @import("std");
const Entity = @import("ecs.zig").Entity;

pub fn SparseSetSerializer(comptime SparseSetDefinition: type) type {
    const Component = @TypeOf(SparseSetDefinition.dense).Item;

    return struct {
        pub fn canSerialize(sparseSet: *SparseSetDefinition, entity: Entity) bool {
            if (sparseSet.sparse.get(entity)) |_| return true;
            return false;
        }

        pub fn serialize(sparseSet: *SparseSetDefinition, entity: Entity, writer: *std.io.Writer) !void {
            if (sparseSet.sparse.get(entity)) |idx| {
                const item = &sparseSet.dense.items[idx];

                comptime if (@hasDecl(Component, "serialize")) {
                    try item.serialize(writer);
                } else {
                    switch (@typeInfo((Component))) {
                        .int => unreachable,
                        else => unreachable,
                    }
                };
            }
        }

        pub fn deserialize(sparseSet: *SparseSetDefinition, entity: Entity, reader: *std.io.Reader) !*Component {
            var item = try sparseSet.create(entity);
            try item.deserialize(reader);
            return item;
        }
    };
}
