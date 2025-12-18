# SparseSet Documentation

## General Information

### What is a "Sparse Set"?

A sparse set is a data structure that efficiently stores and retrieves components associated with entities in an Entity Component System (ECS). Unlike traditional arrays or hash maps, sparse sets minimize memory usage while providing fast access times by maintaining a compact, dense representation of data alongside a sparse mapping for quick lookups. In this implementation, `Entity` is a type alias (currently `u32`) that serves as the key type for identifying entities, allowing users to define the underlying type used for entity IDs.

### How This Sparse Set Achieves Its Goals

The SparseSet implementation uses three main data structures:
- A dense array that stores the actual component data in contiguous memory for fast iteration and access.
- An entities array that mirrors the dense array, storing the entity IDs in the same order.
- A sparse hash map that maps entity IDs directly to indices in the dense array.

This design allows for O(1) average-time complexity for insertions, deletions, and lookups while ensuring that the data remains densely packed, reducing memory overhead and improving cache locality. When an entity-component pair is added, it's appended to the dense and entities arrays, and the sparse map is updated. Removals use a "swap and pop" technique to maintain density without shifting elements.

## Architectural Structure

### Comptime Execution for Generalization

The SparseSet is implemented as a generic Zig type using `comptime T: type`, allowing it to be specialized at compile time for any component type `T`. This compile-time polymorphism ensures type safety and optimization without runtime overhead, as the Zig compiler generates a unique type for each `T` used.

### Dependent Data Structures

The implementation depends on:
- `std.array_list.Aligned(T, null)` for the dense array, providing dynamic arrays with alignment.
- `std.array_list.Aligned(Entity, null)` for the entities array.
- `std.hash_map.AutoHashMapUnmanaged(Entity, u32)` for the sparse map, which maps `Entity` to a `u32` index.

These are all part of Zig's standard library, ensuring portability and reliability.

### Memory Layout

The memory layout consists of:
- **Dense Array**: A contiguous block of memory storing `T` components in the order they were added.
- **Entities Array**: A parallel contiguous block storing `Entity` IDs corresponding to each component in the dense array.
- **Sparse Map**: A hash map where keys are `Entity` and values are `u32` indices into the dense and entities arrays.

This layout ensures that iterating over components (via the dense array) is cache-efficient, while lookups (via the sparse map) are fast.

### Overview of Addition/Removal Handling

- **Addition**: New components are appended to the end of the dense and entities arrays, and the sparse map is updated with the new index. This preserves the dense property.
- **Removal**: Uses "swap and pop" – the element to remove is swapped with the last element in the arrays, then the last element is popped. The sparse map is updated to reflect the new position of the swapped element, ensuring all mappings remain valid without expensive shifts.

## Init and Deinit Methods

There is no explicit `init` method; SparseSet instances can be initialized with the `empty` constant, which provides zero-capacity arrays and maps.

The `deinit` method frees all allocated memory by calling `deinit` on the dense array, entities array, and sparse map, setting the instance to undefined.

### Memory Allocations

Memory allocations occur dynamically during operations:
- `ensureCapacity`: Reserves space in all three structures.
- `add` and `create`: Append to arrays and insert into the hash map, potentially triggering reallocations if capacity is exceeded.
- No pre-allocation in init; allocations happen on-demand during usage.

## Public Methods

### Available Public Methods and Interactions

- `length()`: Returns the number of components stored (length of dense array). O(1).
- `ensureCapacity(allocator, capacity)`: Reserves capacity for at least `capacity` elements in all structures. May invalidate pointers.
- `add(allocator, entity, data)`: Adds or replaces a component for an entity. Appends to dense/entities and updates sparse map. O(1) average.
- `create(allocator, entity)`: Creates a zero-initialized component entry, returns a pointer. Useful for in-place initialization.
- `createAssumeCapacity(entity)`: Same as `create` but assumes sufficient capacity, avoiding checks.
- `get(entity)`: Returns a pointer to the component if it exists, else null. O(1) average lookup.
- `getUnsafe(entity)`: Returns a pointer assuming the component exists; undefined behavior if not. Faster but unsafe.
- `getEntity(index)`: Returns the entity at a given dense array index, or 0 if out of bounds.
- `getDenseSlice()`: Returns a slice of all components in the dense array for iteration.
- `getEntitiesSlice()`: Returns a slice of all entities in the entities array.
- `remove(entity)`: Removes the component for an entity if it exists. Uses swap-and-pop to maintain density. O(1).

### In-Depth Addition/Removal Handling

- **Addition (add/create)**: 
  - Calculates the new index as the current length of the dense array.
  - Appends the data/entity to the respective arrays.
  - Inserts the entity-index pair into the sparse map.
  - If replacing an existing component, the old data is overwritten in place via the sparse lookup and direct access to the dense array index.
  - Capacity checks ensure arrays can grow; reallocations occur as needed.

- **Removal (remove)**:
  - Looks up the index in the sparse map; returns early if not found.
  - Removes the entry from the sparse map.
  - If the index is the last element, simply pops from both arrays.
  - Otherwise, swaps the element at `index` with the last element in both arrays, then pops the last.
  - Updates the sparse map for the swapped entity to reflect its new index.
  - This keeps the dense array contiguous and valid without shifting, but invalidates pointers to swapped elements.

### Sample Use Cases

#### ECS Component Storage
In a game engine's ECS, SparseSet can store components like health for entities. For example, entities represent game objects (players, enemies), and health is an optional component. Use `add` to assign health to an entity, `get` to retrieve it for damage calculations, and iterate over `getDenseSlice()` for system updates like regeneration. This allows O(1) lookups and cache-friendly iteration.

```zig
// Assuming Entity is u32, Health is a struct
const Health = struct { current: i32, max: i32 };
var healthSet = SparseSet(Health).empty;

// Add health to entity 1
healthSet.add(allocator, 1, .{ .current = 100, .max = 100 }) catch {};

// Get and modify health
if (healthSet.get(1)) |health| {
    health.current -= 10; // Apply damage
}

// Iterate over all health components for regeneration
for (healthSet.getDenseSlice()) |*health| {
    if (health.current < health.max) {
        health.current += 1;
    }
}
```

#### Sparse Data Management
For RPGs with optional attributes like inventory, SparseSet efficiently handles cases where only some entities (e.g., players, NPCs with items) have inventories. Use `create` for in-place initialization, `remove` when an entity drops items, and `getDenseSlice()` for querying all inventories without checking every entity.

```zig
const Inventory = struct { items: std.ArrayList(u32) };
var inventorySet = SparseSet(Inventory).empty;

// Create inventory for player entity
const playerInv = inventorySet.create(allocator, playerEntity) catch {};
playerInv.* = .{ .items = std.ArrayList(u32).init(allocator) };
playerInv.items.append(123) catch {}; // Add item ID

// Check if NPC has inventory before interaction
if (inventorySet.get(npcEntity)) |inv| {
    // Trade logic
}

// Remove inventory when entity dies
inventorySet.remove(deadEntity);
```

#### Real-time Systems
In game loops requiring frequent additions/removals, like buffs or effects, SparseSet's swap-and-pop removal avoids shifts, maintaining performance. Use `ensureCapacity` to preallocate, `add` for new effects, and iterate over dense slices for updates. Pointers may invalidate on additions, so re-fetch as needed.

```zig
const Buff = struct { duration: f32, effect: enum { speed, strength } };
var buffSet = SparseSet(Buff).empty;

// Preallocate for performance
buffSet.ensureCapacity(allocator, 1000) catch {};

// Add temporary buff
buffSet.add(allocator, entity, .{ .duration = 10.0, .effect = .speed }) catch {};

// Update loop: decrement durations, remove expired
var i: usize = 0;
while (i < buffSet.getDenseSlice().len) {
    const buff = &buffSet.getDenseSlice()[i];
    buff.duration -= deltaTime;
    if (buff.duration <= 0) {
        const entityToRemove = buffSet.getEntity(i);
        buffSet.remove(entityToRemove);
        // Don't increment i, as removal swaps with last
    } else {
        i += 1;
    }
}
```
