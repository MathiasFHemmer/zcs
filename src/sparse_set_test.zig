const std = @import("std");
const t = std.testing;
const SparseSet = @import("sparse_set.zig").SparseSet;

const ComponentA = struct { fieldA: u32 };

const ComponentB = struct {
    fieldA: u32,
    pub fn serialize(self: *ComponentB, writer: *std.io.Writer) !void {
        try writer.writeInt(u32, self.fieldA, .little);
    }
    pub fn deserialize(self: *ComponentB, reader: *std.io.Reader) !void {
        self.fieldA = try reader.takeInt(u32, .little);
    }
};

const ComponentC = struct {
    fieldA: u32,
    pub fn serialize(self: *ComponentC, writer: *std.io.Writer) !void {
        try writer.writeInt(u32, self.fieldA, .little);
    }
};

test "Adding new value populates dense and sparse arrays and entity hashmap" {
    const alloc = t.allocator;
    var set = SparseSet(u32).empty;
    defer set.deinit(alloc);

    try set.add(alloc, 1, 42);

    try t.expect(set.dense.items.len == 1);
    try t.expect(set.dense.items[0] == 42);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items.len == 1);
    try t.expect(set.entities.items[0] == 1);
}
test "Removing from the middle correctly remakes entity to and from dense mappings" {
    const alloc = t.allocator;
    var set = SparseSet(u32).empty;
    defer set.deinit(alloc);

    try set.add(alloc, 1, 42);
    try set.add(alloc, 2, 69);
    try set.add(alloc, 3, 420);

    try t.expect(set.dense.items[0] == 42);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items[0] == 1);

    try t.expect(set.dense.items[1] == 69);
    try t.expect(set.sparse.get(2) == 1);
    try t.expect(set.entities.items[1] == 2);

    try t.expect(set.dense.items[2] == 420);
    try t.expect(set.sparse.get(3) == 2);
    try t.expect(set.entities.items[2] == 3);

    set.remove(2);
    try t.expect(set.dense.items.len == 2);
    try t.expect(set.sparse.contains(2) == false);
    try t.expect(set.entities.items.len == 2);

    try t.expect(set.dense.items[0] == 42);
    try t.expect(set.sparse.get(1) == 0);
    try t.expect(set.entities.items[0] == 1);

    try t.expect(set.dense.items[1] == 420);
    try t.expect(set.sparse.get(3) == 1);
    try t.expect(set.entities.items[1] == 3);
}
