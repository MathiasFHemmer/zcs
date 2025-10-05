const std = @import("std");
const SparseSet = @import("sparse_set.zig").SparseSet;
const SparseSetSerializer = @import("sparse_set_serializer.zig").SparseSetSerializer;
const logger = std.log.scoped(.ECS);

pub const Entity = u32;

pub fn ECS(
    comptime ComponentTypes: type,
    comptime Options: struct {
        State: ?type = null,
        AssetManager: ?type = null,
    },
) type {
    switch (@typeInfo(ComponentTypes)) {
        .@"union" => |value| std.debug.assert(value.tag_type != null),
        else => @compileError("ComponentTypes must be a struct type"),
    }

    const StateType = if (Options.State) |s| blk: {
        std.debug.assert(@hasDecl(s, "init"));
        std.debug.assert(@hasDecl(s, "deinit"));
        break :blk s;
    } else struct {};

    const AssetManagerType = if (Options.AssetManager) |am| blk: {
        std.debug.assert(@hasDecl(am, "init"));
        std.debug.assert(@hasDecl(am, "deinit"));
        break :blk am;
    } else struct {};

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        assetManager: AssetManagerType,
        state: StateType,

        nextEntity: Entity,
        entitiesToRemove: std.array_list.Aligned(Entity, null),

        componentStorage: ComponentStorages,

        const ComponentStorages = blk: {
            var fields: []const std.builtin.Type.StructField = &.{};
            const info = @typeInfo(ComponentTypes).@"union";

            for (info.fields) |field| {
                const T = field.type;
                fields = fields ++ [1]std.builtin.Type.StructField{
                    .{
                        .name = field.name,
                        .type = SparseSet(T),
                        .default_value_ptr = null,
                        .is_comptime = false,
                        .alignment = @alignOf(SparseSet(T)),
                    },
                };
                fields = fields ++ [1]std.builtin.Type.StructField{
                    .{
                        .name = field.name ++ "Serializer",
                        .type = SparseSetSerializer(SparseSet(T)),
                        .default_value_ptr = null,
                        .is_comptime = false,
                        .alignment = @alignOf(SparseSetSerializer(SparseSet(T))),
                    },
                };
            }

            break :blk @Type(.{
                .@"struct" = .{
                    .layout = .auto,
                    .fields = fields,
                    .decls = &.{},
                    .is_tuple = false,
                },
            });
        };

        pub fn init(allocator: std.mem.Allocator) !Self {
            var self: Self = .{
                .allocator = allocator,
                .nextEntity = 1,
                .entitiesToRemove = .empty,
                .componentStorage = undefined,
                .state = undefined,
                .assetManager = undefined,
            };

            if (Options.State) |t| self.state = t.init();
            if (Options.AssetManager) |t| self.assetManager = t.init();

            inline for (@typeInfo(ComponentTypes).@"union".fields) |field| {
                const T = field.type;
                const data = SparseSet(T).empty;
                @field(self.componentStorage, field.name) = data;
            }

            return self;
        }

        pub fn printRegistry() void {
            inline for (@typeInfo(ComponentTypes).@"union".fields) |field| {
                logger.debug("Component [{s}] Type [{s}] active", .{ field.name, @typeName(field.type) });
            }
        }

        pub fn deinit(self: *Self) void {
            if (Options.State) |_| self.state = Options.State.deinit();
            if (Options.AssetManager) |_| self.assetManager = Options.AssetManager.deinit();
            self.entitiesToRemove.deinit(self.allocator);

            inline for (@typeInfo(ComponentTypes).@"union".fields) |field| {
                @field(self.componentStorage, field.name).deinit(self.allocator);
            }
        }

        pub fn createEntity(self: *Self) Entity {
            logger.debug("Creating new entity...", .{});
            const current = self.nextEntity;
            self.nextEntity += 1;
            logger.debug("Entity {any} created!", .{current});
            return current;
        }

        pub fn addComponent(self: *Self, entity: Entity, component: anytype) void {
            const T: type = @TypeOf(component);
            logger.debug("Adding component {any} to entity {any}...", .{ T, entity });
            inline for (@typeInfo(ComponentTypes).@"union".fields) |field| {
                if (field.type == T) {
                    @field(self.componentStorage, field.name).add(self.allocator, entity, component) catch {};
                    return;
                }
            }
            @compileError("Component type " ++ @typeName(T) ++ " not registered in ECS");
        }

        pub fn getComponent(self: *Self, entity: Entity, comptime T: type) ?*T {
            inline for (@typeInfo(ComponentTypes).@"struct".fields) |field| {
                if (field.type == T) {
                    return @field(self.componentStorage, field.name).get(entity);
                }
            }
            @compileError("Component type " ++ @typeName(T) ++ " not registered in ECS");
        }

        pub fn getComponentEntity(self: *Self, index: usize, comptime T: type) Entity {
            inline for (@typeInfo(ComponentTypes).@"struct".fields) |field| {
                if (field.type == T) {
                    return @field(self.componentStorage, field.name).getEntity(index);
                }
            }
            @compileError("Component type " ++ @typeName(T) ++ " not registered in ECS");
        }

        pub fn getComponentSet(self: *Self, comptime T: type) *SparseSet(T) {
            inline for (@typeInfo(ComponentTypes).@"struct".fields) |field| {
                if (field.type == T) {
                    return &@field(self.componentStorage, field.name);
                }
            }
            @compileError("Component type " ++ @typeName(T) ++ " not registered in ECS");
        }

        pub fn markForRemoval(self: *Self, entity: Entity) void {
            self.entitiesToRemove.append(self.allocator, entity) catch unreachable;
        }

        // This removes an entity and all its associated components.
        // Do not use this inside a query!
        pub fn removeEntity(self: *Self, entity: Entity) void {
            inline for (@typeInfo(ComponentTypes).@"struct".fields) |field| {
                @field(self.componentStorage, field.name).remove(entity);
            }
        }

        pub fn flushRemoval(self: *Self) void {
            for (self.entitiesToRemove.items) |entity| {
                self.removeEntity(entity);
            }
            self.entitiesToRemove.clearRetainingCapacity();
        }

        //
        // Entity Serialization. Utilizes a 4x32 bits of header data for version and entity id
        // The next 32 bits specify a component id. If the component is present on the ECS fields table, it will try to deserialize the component
        // TODO: Add version resolution for each component
        //
        // 3x32 [Major, Minor, Patch] -> Version
        // 1x32 [Id] -> Entity Id
        // <repeat>
        // 1x32 [Component Tag] -> Component Tag Id
        // ... The following bytes should be filled by the component deserialization logic. This lets components have an unknown size fo bytes to write on the serialization step
        // But requires careful version implementation, as different memory layouts will break the entire serialization loop
        // <end>
        pub fn serialize(self: *Self, entity: Entity, writer: *std.io.Writer, version: std.SemanticVersion) !void {
            try writer.writeInt(u32, @intCast(version.major), .little);
            try writer.writeInt(u32, @intCast(version.minor), .little);
            try writer.writeInt(u32, @intCast(version.patch), .little);

            try writer.writeInt(Entity, entity, .little);

            const info = @typeInfo(ComponentTypes).@"union";
            const fields = info.fields;
            inline for (fields) |field| {
                const storage = @field(self.componentStorage, field.name);
                const sparseSetSerializer = SparseSetSerializer(@TypeOf(storage));
                if (sparseSetSerializer.canSerialize(entity)) {
                    try writer.writeInt(u32, @intFromEnum(@field(ComponentTypes, field.name)), .little);
                    try sparseSetSerializer.serialize(entity, writer);
                }
            }
        }

        //TODO: Implement versioning on components
        // ------------ IGNORE ------------
        // pub fn deserialize(self: *Self, reader: *std.io.Reader, version: std.SemanticVersion) !std.SemanticVersion {
        //     _ = version;
        //     const major = try reader.takeInt(u32, .little);
        //     const minor = try reader.takeInt(u32, .little);
        //     const patch = try reader.takeInt(u32, .little);
        //     const saveVersion = std.SemanticVersion{ .major = major, .minor = minor, .patch = patch };

        //     const id = try reader.takeInt(Entity, .little);

        //     self.nextEntity = id;

        //     //TODO: Loop over the rest of the data, gathering 32 bytes first for the component id, and if it matched the id on the configured table, try to call the deserialize on it to generate a new
        //     // component
        //     const info = @typeInfo(ComponentTypes).@"union";
        //     const fields = info.fields;

        //     const tag = try reader.takeInt(u32, .little);
        //     const entity = self.createEntity();
        //     inline for (fields) |field| {
        //         if (@intFromEnum(@field(ComponentTypes, field.name)) == tag) {
        //             var storage = @field(self.componentStorage, field.name);
        //             try storage.deserialize(entity, reader);
        //         }
        //     }

        //     return saveVersion;
        // }
        // ------------

        pub fn query(self: *Self, comptime Components: type) Query(Components) {
            return Query(Components).init(self);
        }
        pub fn Query(comptime Components: type) type {
            return struct {
                sets: Sets,

                const Sets = blk: {
                    var fields: []const std.builtin.Type.StructField = &.{};
                    const info = @typeInfo(Components).@"struct";

                    for (info.fields) |field| {
                        const T = field.type;
                        const field_type = *SparseSet(T);
                        fields = fields ++ [1]std.builtin.Type.StructField{
                            .{
                                .name = field.name,
                                .type = field_type,
                                .default_value_ptr = null,
                                .is_comptime = false,
                                .alignment = @alignOf(field_type),
                            },
                        };
                    }

                    break :blk @Type(.{
                        .@"struct" = .{
                            .layout = .auto,
                            .fields = fields,
                            .decls = &.{},
                            .is_tuple = false,
                        },
                    });
                };

                pub fn init(ecs: *Self) @This() {
                    var _query: @This() = undefined;

                    inline for (@typeInfo(Components).@"struct".fields) |field| {
                        const T = field.type;
                        @field(_query.sets, field.name) = ecs.getComponentSet(T);
                    }

                    return _query;
                }
            };
        }
    };
}
