module Lapis
  module Docs
    # # D. Node DSL, Lifecycle & Signals
    #
    # The `node` macro is the central declarative building block in LibGodot.
    # It provides a clean, expressive DSL for authoring Godot classes in Crystal.
    #
    # ---
    #
    # ### 1. The `node` Macro Syntax
    #
    # ```
    # require "libgodot"
    #
    # # Inherits from Godot::Node by default:
    # node CameraRig do
    #   # ...
    # end
    #
    # # Inherits from a specific Godot class:
    # node Player < CharacterBody3D do
    #   # ...
    # end
    #
    # # Subclassing another custom Crystal node:
    # node Warrior < Player do
    #   # ...
    # end
    # ```
    #
    # ---
    #
    # ### 2. Lifecycle Callback Dispatch
    #
    # Godot nodes execute lifecycle methods at specific stages in the frame lifecycle.
    # LibGodot automatically detects these methods at compile time and registers virtual
    # function pointers with the GDExtension bridge:
    #
    # - `def _ready : Void`
    #   Called once when the node and all of its children have entered the active scene tree.
    # - `def _process(delta : Float64) : Void`
    #   Called every visual frame. `delta` is elapsed time in seconds since previous frame.
    # - `def _physics_process(delta : Float64) : Void`
    #   Called every fixed physics step (typically 60 Hz). Used for physics movement and simulation.
    #
    # Virtual method calls are dispatched directly from the C++ bridge via `call_virtual`,
    # bypassing Variant reflection for maximum execution speed.
    #
    # ---
    #
    # ### 3. Type-Safe Signal System
    #
    # Signals allow nodes to notify observers when state changes occur, decoupled from listeners:
    #
    # ```
    # node BossEnemy < CharacterBody3D do
    #   # Define signals with typed arguments:
    #   signal phase_changed(new_phase : Int32)
    #   signal health_updated(current : Int32, max_health : Int32)
    #   signal defeated
    #
    #   def take_damage(amount : Int32) : Void
    #     @health -= amount
    #     emit_health_updated(@health, @max_health)
    #     if @health <= 0
    #       emit_defeated
    #     end
    #   end
    # end
    # ```
    #
    # Under the hood:
    # 1. The `signal` declaration is harvested at compile time.
    # 2. A `CrystalSignalDesc` entry is registered into Godot's `ClassDB`.
    # 3. A type-safe emission helper method (`emit_<signal_name>(...)`) is generated.
    # 4. Arguments are converted into `CrystalSignalArg` buffers and dispatched via
    #    `Bridge.object_emit_signal`.
    # 5. GDScript, C#, and other Crystal nodes can connect to these signals natively.
    #
    # ---
    #
    # ### 4. Scene Tree APIs
    #
    # Custom nodes have access to Godot's scene tree hierarchy methods:
    # - `add_child(node, force_readable_name = false, internal = 0)`: Adds child to this node.
    # - `remove_child(node)`: Removes a child node without freeing it.
    # - `reparent(new_parent, keep_global_transform = true)`: Moves node to a new parent in one call.
    # - `get_parent : Node` / `get_parent? : Node?`: Returns parent or nil if orphan.
    # - `get_child_count : Int64`: Returns the count of child nodes.
    # - `get_child(idx) : Node` / `get_child?(idx) : Node?`: Retrieves child by index.
    # - `find_child(pattern, recursive = true, owned = false) : Node?`: Searches hierarchy by name.
    # - `queue_free : Void`: Queues the node for clean deletion at the end of the frame.
    # - `is_inside_tree : Bool`: Checks if the node is in the active scene tree.
    # - `instantiate : Node`: Unpacks a `PackedScene` into an active node hierarchy.
    #
    # ---
    #
    # ### 5. In-Editor Tool Scripts (`@[Tool]` or `tool`)
    #
    # Adding `@[Tool]` or invoking `tool` inside a node instructs Godot to run the node
    # inside the **Godot Editor** in real time:
    # ```
    # @[Tool]
    # node ProceduralArchway < Node3D do
    #   @[Export]
    #   property radius : Float32 = 5.0_f32
    #
    #   def _process(delta : Float64) : Void
    #     # Runs inside Godot Editor! Updates visual mesh when radius changes.
    #   end
    # end
    # ```
    #
    # ---
    #
    # ### 6. Network Replication (`@[RPC]`)
    #
    # Methods marked with `@[RPC]` configure multiplayer network replication:
    # ```
    # @[RPC(mode: :any_peer, call_local: true)]
    # def sync_position(pos : Vector3) : Void
    #   self.position = pos
    # end
    # ```
    module D_NODE_DSL_AND_SIGNALS
      # Dummy method for documentation visibility
      def self.lifecycle_methods : Array(String)
        ["_ready", "_process(delta : Float64)", "_physics_process(delta : Float64)"]
      end
    end
  end
end

