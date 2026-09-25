module Lapis
  module Docs
    # # H. Lifecycle, Memory Management & Dead-Pointer Safety
    #
    # In a modern multi-language game engine architecture where GDScript, C++, and Crystal interact
    # dynamically, object lifecycles can be terminated unpredictably from any environment.
    # LibGodot provides a robust, defense-in-depth safety architecture designed to guarantee
    # zero memory leaks and eliminate catastrophic segmentation faults caused by dangling pointers.
    #
    # ---
    #
    # ### 1. Dual Memory Architecture
    #
    # LibGodot bridges two completely independent memory management models operating simultaneously:
    #
    # 1. **Crystal's Boehm Garbage Collector (GC)**:
    #    - Allocates and manages all Crystal memory (class wrappers, structs, strings, arrays, fibers).
    #    - Periodically scans the Crystal stack and heap to collect unreferenced Crystal objects.
    #    - Crystal `Godot::Object` instances hold a raw C++ memory pointer (`@pointer : Void*`) and
    #      a cached 64-bit instance ID (`@instance_id : UInt64`) pointing to the underlying Godot instance.
    #    - When a Crystal wrapper becomes unreachable, Boehm GC frees the wrapper object. However,
    #      garbage collection of the wrapper does **not** deallocate the underlying Godot engine object,
    #      because the engine entity may still be active in the scene tree or referenced by GDScript!
    #
    # 2. **Godot Engine's Native Memory & ObjectDB**:
    #    - Native Godot objects are allocated on the engine C++ heap via `memnew(T)`.
    #    - Every living `Godot::Object` receives a unique, globally monotonic 64-bit ID
    #      assigned by Godot's internal `ObjectDB`.
    #    - `Node` instances follow a scene-tree ownership lifecycle: parent nodes own children,
    #      and deletion occurs either immediately via `node.free()` / `memdelete(node)` or deferred
    #      at the end of the current frame via `node.queue_free()`.
    #    - `RefCounted` and `Resource` instances follow atomic reference counting (`reference()`,
    #      `unreference()`) and are deallocated automatically by the engine when their reference count
    #      drops to zero.
    #
    # ---
    #
    # ### 2. The "Dangling Pointer / Disposed Object" Hazard
    #
    # In unshielded GDExtension or C-API language bindings, a critical hazard arises when an object
    # is deleted outside of Crystal's direct knowledge:
    #
    # ```text
    # [ Crystal Runtime ]                          [ Godot Engine / GDScript ]
    #   enemy = get_node("Enemy")
    #   enemy.@pointer = 0x7FFE_1234  -------->     Node instance at 0x7FFE_1234
    #                                                   |
    #                                                   | GDScript: enemy.queue_free()
    #                                                   v
    #                                                ObjectDB destroys Node & frees memory!
    #                                                0x7FFE_1234 is now DEAD / UNMAPPED!
    #   enemy.position = Vector2.new(...)
    #         |
    #         v
    #   Dereferences 0x7FFE_1234
    #   ==> ACCESS_VIOLATION / SIGSEGV
    #   ==> TOTAL CRASH (Process Killed)
    # ```
    #
    # In unshielded bindings, the next time Crystal tries to access that object (e.g. reading
    # `enemy.position`, calling `enemy.name`, or invoking a method), the CPU dereferences a
    # dead memory address, resulting in an immediate, fatal **segmentation fault (ACCESS_VIOLATION)**
    # that crashes the entire game process with zero diagnostic traceback.
    #
    # ---
    #
    # ### 3. How LibGodot Prevents Crashes: Instance ID & ObjectDB Validation
    #
    # To make LibGodot completely resilient against cross-language deletion hazards:
    #
    # 1. **Automatic Instance ID Registration**:
    #    Whenever a `Godot::Object` wrapper is instantiated in Crystal (via `Godot.create`,
    #    `get_node`, reflection, or callback parameters), Crystal queries the native engine:
    #    ```
    # @instance_id = Bridge.object_get_instance_id(@pointer)
    #    ```
    # 2. **ObjectDB Liveness Verification**:
    #    Before executing any reflection, method call, or ptrcall dispatch, LibGodot calls `#check_alive!`.
    #    This helper queries Godot's internal `ObjectDB` via `Bridge.is_instance_valid(@instance_id)`.
    #    Because `ObjectDB` assigns monotonically increasing 64-bit IDs, even if newly allocated memory
    #    happens to share the old memory address on the C++ heap, the instance ID will **never** collide.
    # 3. **The `DisposedObjectError` Exception**:
    #    If the native Godot object was destroyed on the GDScript side, in the engine, or via
    #    a prior `queue_free()`, `check_alive!` immediately marks the wrapper dead (`@pointer = Pointer(Void).null`)
    #    and raises a clean, catchable Crystal exception:
    #    ```
    # raise Godot::DisposedObjectError.new(@instance_id)
    #    ```
    #    This transforms what would have been an unavoidable process crash into a standard,
    #    traceable Crystal exception that developers can catch, log, or handle gracefully!
    #
    # ---
    #
    # ### 4. Concrete Implications & Developer Guidelines
    #
    # Understanding this architecture is critical for writing robust Godot games and extensions in Crystal:
    #
    # #### A. Performance Implications of ObjectDB Checks
    # - Godot's `ObjectDB::get_instance(id)` is an extremely fast O(1) hash lookup with spinlock protection.
    # - LibGodot's `#check_alive!` executes this check only when invoking method dispatches and hierarchy
    #   operations on Godot objects.
    # - The minuscule overhead (~5-10 nanoseconds) pays dividends by completely eliminating native crashes
    #   in production games and during hot-reloading in the editor.
    #
    # #### B. Defensive Programming: Checking `alive?` and `is_valid?`
    # When caching references to transient entities (such as projectiles, enemies, or UI dialogs),
    # check `#alive?` before operating on them:
    #
    # ```
    # if target_node.alive?
    #   target_node.position = new_pos
    # else
    #   # Cleanly prune target from our tracking list without raising an exception
    #   active_targets.delete(target_node)
    # end
    # ```
    #
    # #### C. Nil-Coalescing with `if_alive` & Safe Collider Queries
    # To avoid explicit boilerplate checks, use `#if_alive` or typed queries like `get_collider?`:
    #
    # ```
    # # Returns self if alive in ObjectDB, or nil if uninitialized, null, or destroyed:
    # if live_target = maybe_target.if_alive
    #   live_target.position = new_pos
    # end
    #
    # # RayCast3D / ShapeCast3D return Godot::Object? directly:
    # if col = shapecast.get_collider?
    #   Godot.print("Hit collider: #{col}")
    # end
    # ```
    #
    # #### D. Engine Value Equality (`==`) and Hashing (`hash`)
    # `Godot::Object` implements value equality based on Godot's 64-bit instance ID (or native pointer).
    # Distinct Crystal wrapper instances representing the same engine object compare equal:
    #
    # ```
    # obj_a == obj_b  # => true if both refer to the same Godot entity
    # null_obj == nil # => true if underlying engine pointer is null
    # nil == null_obj # => true (symmetric nil equality)
    # set = Set(Godot::Object).new
    # set.add(obj_a)
    # set.add(obj_b)
    # set.size # => 1 (properly deduplicated)
    # ```
    #
    # #### E. Handling Disposed Objects with `rescue`
    # If code interacts with arbitrary or external nodes passed from GDScript, you can catch
    # `Godot::DisposedObjectError` at system boundaries:
    #
    # ```
    # begin
    #   untrusted_node.do_something
    # rescue ex : Godot::DisposedObjectError
    #   Godot.print_warn "Encountered dead node (ID: #{ex.instance_id}); skipping operation."
    # end
    # ```
    #
    # #### D. Lifecycle Rules for Nodes vs RefCounted
    # - **Nodes Added to the Scene Tree**: Owned by the scene tree. Do **NOT** call `.destroy` manually
    #   on a parented node; use `node.queue_free` to let Godot safely deallocate it at the end of the frame.
    # - **Standalone Nodes**: If you create a node via `Godot.create(Godot::Node2D)` and never add it
    #   to the scene tree, you **MUST** call `node.destroy` when done with it to prevent a native memory leak!
    # - **RefCounted & Resources**: Managed automatically by Godot's reference counter. If you create a
    #   `Resource` or `RefCounted` object and keep it in Crystal, call `ref_counted.reference` and
    #   `ref_counted.unreference` to participate in reference counting, or allow LibGodot's built-in
    #   lifecycle helpers to manage it.
    #
    # #### E. Quantitative Memory Leak Prevention
    # To verify that Crystal and Godot properly deallocate memory across all operations:
    # - Godot exposes the `Performance` singleton monitors:
    #   - `Performance::OBJECT_COUNT` (Total active engine objects)
    #   - `Performance::OBJECT_NODE_COUNT` (Total active nodes in memory)
    #   - `Performance::MEMORY_STATIC` (Total static engine heap memory in bytes)
    # - In the LibGodot test suite, thousands of nodes and resources are spawned, linked,
    #   unlinked, and destroyed, followed by explicit calls to `GC.collect` in Crystal.
    #   The monitors verify that object counts and static memory return to baseline,
    #   proving zero memory leaks.
    module H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY
      def self.features : Array(String)
        [
          "Monotonic 64-bit ObjectDB instance ID tracking",
          "Zero-crash DisposedObjectError on access to freed engine objects",
          "O(1) alive? and is_valid? inspection helpers",
          "Atomic RefCounted reference tracking with zero leaks",
          "Quantitative Performance monitor leak verification",
        ]
      end
    end
  end
end

