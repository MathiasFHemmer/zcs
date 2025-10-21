const std = @import("std");
pub const SparseSet = @import("sparse_set.zig").SparseSet;

const ECSModule = @import("ecs.zig");
pub const Entity = ECSModule.Entity;
pub const ECS = ECSModule.ECS;

test {
    _ = @import("tests/serialization/serializer_test.zig");
    // _ = @import("serializers/deserializer_test.zig");
    _ = @import("tests/serialization/sparse_set_serializer_test.zig");
    _ = @import("tests/ecs_test.zig");
    // _ = @import("ecs_test.zig");
}
