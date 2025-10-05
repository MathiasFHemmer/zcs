const std = @import("std");
const Allocator = std.mem.Allocator;
const Entity = @import("ecs.zig").Entity;
const logger = std.log.scoped(.SparseSet);

pub fn SparseSet(comptime T: type) type {
    return struct {
        const Self = @This();
        const tag = @tagName(T);

        // Contains the Data itself
        dense: std.array_list.Aligned(T, null),
        // Contains all entities that has this component
        entities: std.array_list.Aligned(Entity, null),
        // Maps the Entity to the index of the Dense array
        sparse: std.hash_map.AutoHashMapUnmanaged(Entity, u32),

        pub const empty = Self{
            .dense = .empty,
            .entities = .empty,
            .sparse = .empty,
        };

        pub fn deinit(self: *Self, allocator: Allocator) void {
            logger.debug("Deinitializing SparseSet({any})", .{T});
            self.dense.deinit(allocator);
            self.entities.deinit(allocator);
            self.sparse.deinit(allocator);
            self.* = undefined;
        }

        pub inline fn length(self: *Self) usize {
            return self.dense.items.len;
        }

        pub fn ensureCapacity(self: *Self, allocator: Allocator, capacity: u32) !void {
            try self.dense.ensureTotalCapacity(allocator, capacity);
            try self.entities.ensureTotalCapacity(allocator, capacity);
            try self.sparse.ensureTotalCapacity(allocator, capacity);
        }

        pub fn add(self: *Self, allocator: Allocator, entity: Entity, data: T) !void {
            logger.debug("Adding data {any} to SparseSet on entity {any}", .{ entity, T });
            const index: u32 = @intCast(self.dense.items.len);
            try self.dense.append(allocator, data);
            try self.entities.append(allocator, entity);
            try self.sparse.put(allocator, entity, index);
        }

        // Creates an entry for the entity, but defaults the T to a zero initialized value.
        // If the component needs initialization, it should be done right after calling this method, before its usage.
        pub fn create(self: *Self, allocator: Allocator, entity: Entity) !*T {
            logger.debug("Creating entry on SparseSet for entity {any}", .{entity});
            const index: u32 = @intCast(self.dense.items.len);
            const item = try self.dense.addOne(allocator);
            try self.entities.append(allocator, entity);
            try self.sparse.put(allocator, entity, index);
            return item;
        }

        // Gets a pointer to an Entity Component
        // Looks for the entity in the Sparse set first. If it exists, extract the index from the Sparse set and uses it as a key in the Dense set
        pub fn get(self: *Self, entity: Entity) ?*T {
            logger.debug("Looking for component {any} of entity {any}", .{ T, entity });
            if (self.sparse.get(entity)) |index| {
                logger.debug("Entity {any} contains component at Dense({d})", .{ entity, index });
                return &self.dense.items[index];
            }
            return null;
        }

        // Gets a pointer to an Entity Component
        // May raise illegal behavior as its not guaranteed that the entity has said component.
        pub fn getUnsafe(self: *Self, entity: Entity) *T {
            std.debug.assert(true);
            const index = self.sparse.get(entity) orelse std.math.maxInt(u32);
            return &self.dense.items[index];
        }

        pub fn getEntity(self: *Self, index: usize) Entity {
            if (index < self.entities.items.len) {
                return self.entities.items[index];
            }
            return 0;
        }

        pub fn getDenseSlice(self: *Self) []T {
            return self.dense.items;
        }

        pub fn getEntitiesSlice(self: *Self) []Entity {
            return self.entities.items;
        }

        pub fn remove(self: *Self, entity: Entity) void {
            logger.debug("Removing component {any} from Entity({d})", .{ T, entity });
            const index = self.sparse.get(entity) orelse return;
            _ = self.sparse.remove(entity);
            const lastIndex = self.dense.items.len - 1;
            if (index == lastIndex) {
                _ = self.dense.pop();
                _ = self.entities.pop();
                return;
            }
            const swapped = self.entities.items[lastIndex];
            _ = self.entities.swapRemove(index);
            _ = self.dense.swapRemove(index);
            self.sparse.putAssumeCapacity(swapped, index);
        }
    };
}
