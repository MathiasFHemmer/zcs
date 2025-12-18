# ECS Documentation

## General Information

### What is an ECS?

An Entity Component System (ECS) is an architectural pattern used in game development and simulations to manage complex systems efficiently. It separates data (components) from logic (systems) and uses entities as identifiers. Unlike traditional object-oriented approaches, ECS avoids deep inheritance hierarchies by composing entities from reusable components, enabling better performance, modularity, and scalability. In this implementation, `Entity` is a type alias (currently `u32`) that serves as the key type for identifying entities, allowing users to define the underlying type used for entity IDs.

### How This ECS Achieves Its Goals

The ECS implementation provides a generic, compile-time configurable system for managing entities, components, and their relationships. It uses SparseSets for each component type to ensure efficient storage and retrieval. Entities are simple IDs, components are data structs attached to entities, and systems operate on queries of components. This design supports fast iteration over relevant components, easy addition/removal of components, and serialization for persistence. Component types are defined via a union at compile time, ensuring type safety and allowing the ECS to generate optimized storage for each component.

## Architectural Structure

### Comptime Execution for Generalization

The ECS is a generic function `ECS(ComponentTypes, Options)` that takes a union of component types and optional state/asset manager types at compile time. This generates a specialized type with component storage fields using SparseSets, query types, and methods tailored to the specified components. Compile-time reflection via `@typeInfo` builds the storage structures and methods dynamically.

### Dependent Data Structures

The implementation depends on:
- `SparseSet(T)` for each component type `T`, providing efficient storage.
- `std.array_list.Aligned(Entity, null)` for pending entity removals.
- User-defined state and asset manager types if provided in Options.

Component storage is a struct with SparseSet fields for each component and their serializers.

### Memory Layout

The ECS struct contains:
- **Component Storage**: A struct with SparseSet fields for each component type and their serializers, storing data densely per component.
- **Entity Management**: A counter for next entity ID and a list for entities marked for removal.
- **State/Asset Managers**: Optional user-provided structs for game state and assets.

Each SparseSet manages its component data separately, ensuring contiguous storage per component type.

### Overview of Addition/Removal Handling

- **Entity Creation**: Increments a counter to generate new Entity IDs.
- **Component Addition**: Uses the appropriate SparseSet's `add` method to attach components to entities.
- **Entity Removal**: Iterates over all component SparseSets to remove the entity's components.
- **Deferred Removal**: Entities can be marked for removal and flushed later to avoid invalidating iterations.

## Init and Deinit Methods

### Init

The `init` method takes an allocator and initializes the ECS instance. It sets up the next entity counter, entities-to-remove list, and initializes component storage SparseSets to empty. If Options include state or asset managers, their `init` methods are called. No component pre-allocation occurs; storage grows dynamically.

### Deinit

The `deinit` method frees all allocated memory: component SparseSets, entities-to-remove list, and calls deinit on state/asset managers if present.

### Memory Allocations

Memory allocations occur dynamically:
- **Entity Creation**: Minimal, just updating counters.
- **Component Addition**: Via SparseSet operations, potentially reallocating arrays/maps.
- **Serialization/Deserialization**: Allocates during data loading.
- **Queries**: No additional allocation; returns references to existing storage.

## 📚 Public Methods

### Available Public Methods and Interactions

`createEntity() -> Entity`  
Generates a new unique Entity ID by incrementing the next entity counter. Returns the new Entity.

`addComponent(entity: Entity, component: anytype) -> void`  
Attaches the given component to the specified entity. The component type determines which SparseSet is used. Replaces existing components of the same type.  

| Parameter | Type | Description |  
|-----------|------|-------------|  
| entity | Entity | The entity to attach the component to |  
| component | anytype | The component data to attach |

`getComponent(entity: Entity, comptime T: type) -> ?*T`  
Retrieves a pointer to the component of type `T` for the entity, or null if not present. `T` must match a component type in the union.  

| Parameter | Type | Description |  
|-----------|------|-------------|  
| entity | Entity | The entity to retrieve the component from |  
| T | comptime type | The component type to retrieve |

`getComponentEntity(index: usize, comptime T: type) -> Entity`  
Returns the Entity at the given index in the dense array of component type `T`. Returns 0 if index is out of bounds.  

| Parameter | Type | Description |  
|-----------|------|-------------|  
| index | usize | The index in the dense array |  
| T | comptime type | The component type |

`getComponentSet(comptime T: type) -> *SparseSet(T)`  
Returns a pointer to the SparseSet storing components of type `T`, allowing direct access to SparseSet methods.  

| Parameter | Type | Description |  
|-----------|------|-------------|  
| T | comptime type | The component type |

`markForRemoval(entity: Entity) -> void`  
Adds the entity to the removal queue for deferred deletion. Does not immediately remove components.  

| Parameter | Type | Description |  
|-----------|------|-------------|  
| entity | Entity | The entity to mark for removal |

`removeEntity(entity: Entity) -> void`  
Immediately removes all components associated with the entity by calling `remove` on each SparseSet. Does not affect entity ID counters.  

| Parameter | Type | Description |  
|-----------|------|-------------|  
| entity | Entity | The entity to remove |

`flushRemoval() -> void`  
Processes the removal queue, calling `removeEntity` on each marked entity, then clears the queue. Used to batch removals after iterations.

`query(comptime Components: type) -> Query(Components)`  
Creates a query struct containing pointers to SparseSets for the specified component types in `Components` (a struct type). Allows efficient iteration over entities with those components.  

| Parameter | Type | Description |  
|-----------|------|-------------|  
| Components | comptime type | A struct type specifying the component types to query |

`serialize(writer: *std.io.Writer, version: std.SemanticVersion) -> !void`  
Serializes the ECS state to the writer, including version, next entity ID, and all component data via SparseSet serializers.  

| Parameter | Type | Description |  
|-----------|------|-------------|  
| writer | *std.io.Writer | The writer to serialize to |  
| version | std.SemanticVersion | The version of the data |

`deserialize(reader: *std.io.Reader, version: std.SemanticVersion) -> !std.SemanticVersion`  
Deserializes ECS state from the reader, restoring components and returning the saved version. Handles version compatibility.  

| Parameter | Type | Description |  
|-----------|------|-------------|  
| reader | *std.io.Reader | The reader to deserialize from |  
| version | std.SemanticVersion | The expected version of the data |

### In-Depth Addition/Removal Handling

- **Component Addition (addComponent)**: 
  - The method uses compile-time type checking to match the component's type against the fields in the `ComponentTypes` union.
  - If a match is found, it calls `add` on the corresponding SparseSet, passing the entity and component data.
  - SparseSet handles appending to dense/entities arrays and updating the sparse map.
  - If the entity already has a component of that type, it replaces the data in place.
  - Potential reallocations occur in SparseSet if capacity is exceeded.

- **Entity Removal (removeEntity)**: 
  - Iterates over all fields in the `ComponentTypes` union using an inline loop.
  - For each component type, calls `remove(entity)` on the respective SparseSet.
  - SparseSet uses swap-and-pop to remove the component without shifting the array, updating the sparse map for the swapped entity.
  - This ensures O(1) removal per component type, with total time O(number of component types).
  - Entity IDs are not reused or reset; removed entities simply have no components attached.

- **Deferred Removal (markForRemoval/flushRemoval)**: 
  - `markForRemoval` appends the entity to `entitiesToRemove`, an `ArrayList(Entity)`, potentially reallocating if capacity is exceeded.
  - `flushRemoval` iterates the list, calling `removeEntity` on each entity to clear all components.
  - After processing, it clears the list but retains capacity for future use.
  - This pattern allows marking entities for removal during iteration without immediately invalidating pointers or indices, deferring actual removal until safe.

### Sample Use Cases

#### Game Entity Management
In a 2D game, manage player, enemy, and bullet entities with components like Position, Velocity, Health. Create entities, attach components, query for updates.

```zig
const Components = union {
    Position: struct { x: f32, y: f32 },
    Velocity: struct { dx: f32, dy: f32 },
    Health: struct { current: i32, max: i32 },
};

const MyECS = ECS(Components, .{});
var ecs = try MyECS.init(allocator);

// createEntity() -> Entity: Create player
const player = ecs.createEntity();

// addComponent(entity: Entity, component: anytype) -> void: Attach components
ecs.addComponent(player, Components{ .Position = .{ .x = 0, .y = 0 } });
ecs.addComponent(player, Components{ .Health = .{ .current = 100, .max = 100 } });

// query(comptime Components: type) -> Query(Components): Query for movement
var query = ecs.query(struct { pos: *SparseSet(Components.Position), vel: *SparseSet(Components.Velocity) });
for (0..query.pos.length()) |i| {
    // getComponentEntity(index: usize, comptime T: type) -> Entity
    const entity = query.pos.getEntity(i);
    // getComponent(entity: Entity, comptime T: type) -> ?*T
    if (query.vel.get(entity)) |vel| {
        if (query.pos.get(entity)) |pos| {
            pos.x += vel.dx;
            pos.y += vel.dy;
        }
    }
}
```

#### Simulation with Optional Components
For a particle system, some particles have physics, others are decorative. Use optional components, remove expired particles.

```zig
// addComponent(entity: Entity, component: anytype) -> void: Add physics to some
ecs.addComponent(particle, Components{ .Velocity = .{ .dx = 1.0, .dy = 0.0 } });

// getComponent(entity: Entity, comptime T: type) -> ?*T: Check for physics
if (ecs.getComponent(particle, Components.Velocity)) |vel| {
    // Apply physics
}

// markForRemoval(entity: Entity) -> void: Mark expired
ecs.markForRemoval(expiredParticle);

// flushRemoval() -> void: Batch remove after updates
ecs.flushRemoval();
```

#### Serialization for Save/Load
Persist game state by serializing ECS data to disk, reloading on startup.

```zig
// serialize(writer: *std.io.Writer, version: std.SemanticVersion) -> !void
var file = try std.fs.cwd().createFile("save.dat", .{});
var writer = file.writer();
try ecs.serialize(writer, .{ .major = 1, .minor = 0, .patch = 0 });
file.close();

// deserialize(reader: *std.io.Reader, version: std.SemanticVersion) -> !std.SemanticVersion
var loadFile = try std.fs.cwd().openFile("save.dat", .{});
var reader = loadFile.reader();
const loadedVersion = try ecs.deserialize(reader, .{ .major = 1, .minor = 0, .patch = 0 });
loadFile.close();
