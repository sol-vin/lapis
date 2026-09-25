module Lapis
  module Docs
    # # H. Lifecycle, Memory Management & Dead-Pointer Safety
    #
    # In a dynamic multi-language game engine where GDScript, C++, and Crystal interact
    # asynchronously, object lifecycles can be terminated unpredictably from any environment.
    # LibGodot provides a robust, defense-in-depth safety architecture designed to guarantee
    # zero memory leaks and eliminate catastrophic segmentation faults caused by dangling pointers.
    #
    # ### Executive Summary & Key Topics
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Topic</th>
    #       <th>Method / Anchor</th>
    #       <th>Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>Dual Memory Models</strong></td>
    #       <td><code>.topic_01_dual_memory_models</code></td>
    #       <td>Bridging Crystal Boehm GC with Godot ObjectDB and reference counting.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Dead-Pointer Hazard</strong></td>
    #       <td><code>.topic_02_dead_pointer_hazard</code></td>
    #       <td>Why unshielded C-API pointers trigger fatal ACCESS_VIOLATION crashes on freed nodes.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Monotonic Instance IDs</strong></td>
    #       <td><code>.topic_03_monotonic_instance_ids</code></td>
    #       <td>Non-colliding 64-bit instance IDs in ObjectDB and O(1) liveness checks.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>#check_alive! & DisposedObjectError</strong></td>
    #       <td><code>.topic_04_check_alive_and_disposed_error</code></td>
    #       <td>Defensive inspection patterns, alive?, destroyed?, and catchable exceptions.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Ownership & Zero Leaks</strong></td>
    #       <td><code>.topic_05_ownership_and_leaks</code></td>
    #       <td>SceneTree queue_free vs manual destroy on orphan nodes, and assert_no_leak verification.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/object.cr`, `src/libgodot/bridge.cr`
    # - **Live Specifications**: `spec/suites/test_dead_pointer_safety.cr`, `spec/suites/test_lifecycle_destruction.cr`
    # - **Showcase Examples**: `template/src/my_node.cr`
    # - **Related Guides**: `Docs::G_CAVEATS_AND_INTERNALS`, `Docs::D_NODE_DSL_AND_SIGNALS`, `Docs::Q_TESTING_FRAMEWORK_AND_EDITOR_SUITES`
    module H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY
      # **Dual Memory Models**: Bridging Crystal Boehm GC with Godot ObjectDB and reference counting.
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
      #    - Every living `Godot::Object` receives a unique, globally monotonic 64-bit ID assigned by Godot's internal `ObjectDB`.
      #    - `Node` instances follow a scene-tree ownership lifecycle: parent nodes own children,
      #      and deletion occurs either immediately via `node.free()` or deferred via `node.queue_free()`.
      #    - `RefCounted` and `Resource` instances follow atomic reference counting (`reference()`, `unreference()`)
      #      and are deallocated automatically by the engine when their reference count drops to zero.
      #
      # See also: `src/libgodot/object.cr`
      def self.topic_01_dual_memory_models : Nil
      end

      # **Dead-Pointer Hazard**: Why unshielded C-API pointers trigger fatal ACCESS_VIOLATION crashes on freed nodes.
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
      #   ==> ACCESS_VIOLATION / SIGSEGV (0xC0000005)
      #   ==> TOTAL CRASH (Process Killed Instantly)
      # ```
      #
      # Without protective interception, accessing that dead pointer triggers an unrecoverable
      # segmentation fault (`0xC0000005`) that crashes the game without any stack trace.
      def self.topic_02_dead_pointer_hazard : Nil
      end

      # **Monotonic Instance IDs**: Non-colliding 64-bit instance IDs in ObjectDB and O(1) liveness checks.
      #
      # To prevent crashes from dangling pointers, LibGodot tracks every Godot object by its
      # engine-assigned 64-bit instance ID:
      #
      # 1. **ID Query at Initialization**:
      #    Whenever a `Godot::Object` wrapper is instantiated in Crystal (via `Godot.create`,
      #    `get_node`, reflection, or callback parameters), Crystal queries:
      #    ```crystal
      #    @instance_id = Bridge.object_get_instance_id(@pointer)
      #    ```
      # 2. **Monotonic Non-Collision**:
      #    Because `ObjectDB` generates strictly monotonic 64-bit IDs, even if newly allocated memory
      #    happens to share the old memory address on the C++ heap, the instance ID will **never** collide.
      # 3. **O(1) Liveness Lookups**:
      #    Godot's `ObjectDB::get_instance(id)` executes an ultra-fast O(1) hash lookup protected by a spinlock.
      #
      # See also: `spec/suites/test_dead_pointer_safety.cr`
      def self.topic_03_monotonic_instance_ids : Nil
      end

      # **Liveness Checks & DisposedObjectError**: Defensive inspection patterns, alive?, destroyed?, and catchable exceptions.
      #
      # Before performing method dispatches, reflection calls, or scene operations, LibGodot
      # invokes `#check_alive!`:
      #
      # ```crystal
      # def check_alive! : Void
      #   return if alive?
      #   @pointer = Pointer(Void).null
      #   raise Godot::DisposedObjectError.new(@instance_id)
      # end
      # ```
      #
      # #### Defensive Inspection APIs:
      # - `obj.alive?`: Returns `true` if the underlying Godot object is still valid in `ObjectDB`.
      # - `obj.destroyed?`: Returns `true` if the underlying Godot object has been freed.
      #
      # #### Example Handling:
      # ```crystal
      # begin
      #   target.position = target.position + Vector3.new(0, 1, 0)
      # rescue ex : Godot::DisposedObjectError
      #   Godot.print_warn("Target #{ex.instance_id} was destroyed before position update!")
      # end
      # ```
      #
      # This converts fatal process crashes into standard, catchable Crystal exceptions!
      #
      # See also: `spec/suites/test_dead_pointer_safety.cr`
      def self.topic_04_check_alive_and_disposed_error : Nil
      end

      # **Ownership & Zero Leaks**: SceneTree queue_free vs manual destroy on orphan nodes, and assert_no_leak verification.
      #
      # To achieve mathematically verified zero memory leaks in production:
      #
      # 1. **SceneTree Owned Nodes**:
      #    Nodes added to the scene tree via `add_child` are owned by their parent.
      #    Always call `node.queue_free` to let Godot deallocate them cleanly at frame end.
      # 2. **Orphan Standalone Nodes**:
      #    Nodes created via `Godot.create(Node2D)` that are **not** added to the tree are **not**
      #    owned by Godot. You **MUST** call `node.destroy` when finished with them to avoid leaking C++ memory!
      # 3. **RefCounted & Resources**:
      #    `RefCounted` and `Resource` instances are managed by Godot's atomic reference counter.
      #    Never call `.destroy` manually on refcounted resources.
      # 4. **Zero Leak Verification (`assert_no_leak`)**:
      #    Standardized testing apparatus verifies zero object or static memory leaks using Godot's
      #    `Performance` singleton monitors and `GC.collect`:
      #    ```crystal
      #    Lapis::Test.assert_no_leak do
      #      node = Godot.create(Godot::Node2D)
      #      node.destroy
      #    end
      #    ```
      #
      # See also: `spec/suites/test_lifecycle_destruction.cr`
      def self.topic_05_ownership_and_leaks : Nil
      end
    end
  end
end
