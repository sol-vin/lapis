module Lapis
  module Docs
    # # D. Node DSL, Lifecycle & Signals
    #
    # The `node` macro is the central declarative building block in LibGodot.
    # It provides a clean, expressive DSL for authoring Godot classes in Crystal with
    # compile-time ClassDB registration, automatic virtual method hookups, and type-safe signals.
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
    #       <td><strong>Node Macro Syntax</strong></td>
    #       <td><code>.topic_01_node_macro_syntax</code></td>
    #       <td>Declaring nodes with explicit superclasses, zero-block declarations, and defaults.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Lifecycle Callbacks</strong></td>
    #       <td><code>.topic_02_lifecycle_callbacks</code></td>
    #       <td>_ready, _process, _physics_process, frame delta timing, and virtual dispatch.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Signals & Events</strong></td>
    #       <td><code>.topic_03_signals_and_events</code></td>
    #       <td>Declaring signals, generated emit_<name> and on_<name> helpers, and first-class await.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>SceneTree Operations</strong></td>
    #       <td><code>.topic_04_scene_tree_operations</code></td>
    #       <td>add_child, remove_child, reparent, queue_free, and hierarchy traversal.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Tool Scripts (@[Tool])</strong></td>
    #       <td><code>.topic_05_tool_scripts</code></td>
    #       <td>In-editor real-time execution for gizmos, custom UI tools, and live inspectors.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Network Replication (@[RPC])</strong></td>
    #       <td><code>.topic_06_network_rpc</code></td>
    #       <td>Configuring multiplayer RPC endpoints, transfer modes, and synchronization.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/macros.cr`, `src/libgodot/object.cr`
    # - **Live Specifications**: `spec/suites/test_macros_dsl.cr`, `spec/suites/test_virtual_methods_dispatch.cr`
    # - **Showcase Examples**: `examples/basic_demo/src/main.cr`, `src/main.cr`
    # - **Related Guides**: `Docs::L_MACRO_DSL_REFERENCE`, `Docs::C_EXPORTS_AND_INSPECTOR`
    module D_NODE_DSL_AND_SIGNALS
      # **Node Macro Syntax**: Declaring nodes with explicit superclasses, zero-block declarations, and defaults.
      #
      # The `node` macro declares a Godot class registered in `ClassDB`:
      #
      # ```crystal
      # require "libgodot"
      #
      # # 1. Inherits from Godot::Node by default:
      # node GameLevel do
      #   def _ready : Void
      #     Godot.print("Level loaded!")
      #   end
      # end
      #
      # # 2. Inherits from a specific engine node class:
      # node Player < CharacterBody3D do
      #   @[Export]
      #   property speed : Float32 = 7.5_f32
      # end
      #
      # # 3. Zero-block syntax (useful for marker or tag nodes):
      # node SpawnPoint < Marker3D
      # node EnemyRoot
      # ```
      #
      # See also: `spec/suites/test_macros_dsl.cr`
      def self.topic_01_node_macro_syntax : Nil
      end

      # **Lifecycle Callbacks**: _ready, _process, _physics_process, frame delta timing, and virtual dispatch.
      #
      # Godot invokes lifecycle methods at deterministic stages of the frame loop.
      # LibGodot automatically detects these methods at compile time and registers virtual
      # function pointers with the C++ bridge:
      #
      # - `def _ready : Void`: Called once when the node and all children enter the active scene tree.
      # - `def _process(delta : Float64) : Void`: Called every visual frame (variable timestep).
      # - `def _physics_process(delta : Float64) : Void`: Called every fixed physics step (typically 60 Hz).
      # - `def _enter_tree : Void`: Called when entering the SceneTree.
      # - `def _exit_tree : Void`: Called when removed from the SceneTree.
      #
      # ```crystal
      # node KinematicHero < CharacterBody3D do
      #   def _ready : Void
      #     Godot.print("Hero ready: #{name}")
      #   end
      #
      #   def _physics_process(delta : Float64) : Void
      #     # Fixed-rate simulation
      #     move_and_slide
      #   end
      # end
      # ```
      #
      # See also: `spec/suites/test_virtual_methods_dispatch.cr`
      def self.topic_02_lifecycle_callbacks : Nil
      end

      # **Signals & Events**: Declaring signals, generated emit_<name> and on_<name> helpers, and first-class await.
      #
      # Signals provide decoupled event broadcasting across Crystal and GDScript:
      #
      # ```crystal
      # node BossEnemy < CharacterBody3D do
      #   signal health_updated(current : Int32, max_health : Int32)
      #   signal defeated
      #
      #   def take_damage(amount : Int32) : Void
      #     @health = Math.max(0, @health - amount)
      #     emit_health_updated(@health, @max_health)
      #     emit_defeated if @health == 0
      #   end
      # end
      # ```
      #
      # #### Connecting to Signals:
      # ```crystal
      # # Ergonomic block listener:
      # boss.on_health_updated do |current, max|
      #   Godot.print("Boss HP: #{current}/#{max}")
      # end
      #
      # # First-class bound signal awaiting:
      # await(boss.defeated, timeout_sec: 60.0)
      # ```
      #
      # See also: `spec/suites/test_editor_signals.cr`, `spec/suites/test_callable_signals_advanced.cr`
      def self.topic_03_signals_and_events : Nil
      end

      # **SceneTree Operations**: add_child, remove_child, reparent, queue_free, and hierarchy traversal.
      #
      # Nodes have access to Godot's complete scene graph API:
      # - `add_child(node)`: Adds a child to this node.
      # - `remove_child(node)`: Removes a child node without freeing native memory.
      # - `reparent(new_parent)`: Moves node to a new parent in one call.
      # - `queue_free`: Schedules clean deletion at the end of the current frame.
      # - `get_node(path)` / `get_node?(path)`: Retrieves a node by NodePath.
      # - `find_child(pattern)`: Searches children recursively by name.
      #
      # ```crystal
      # def spawn_projectile(bullet : Node3D) : Void
      #   add_child(bullet)
      # end
      # ```
      #
      # See also: `spec/suites/test_node_hierarchy.cr`
      def self.topic_04_scene_tree_operations : Nil
      end

      # **Tool Scripts (@[Tool])**: In-editor real-time execution for gizmos, custom UI tools, and live inspectors.
      #
      # Marking a node with `@[Tool]` or calling `tool` instructs Godot to execute the class
      # inside the **Godot Editor** in real time:
      #
      # ```crystal
      # @[Tool]
      # node ProceduralTerrain < Node3D do
      #   @[Export]
      #   property resolution : Int32 = 64
      #
      #   def _process(delta : Float64) : Void
      #     # Executes live inside Godot Editor! Updates visual mesh when resolution changes.
      #   end
      # end
      # ```
      #
      # See also: `src/main.cr` (`ToolTester2D`, `ToolTester3D`)
      def self.topic_05_tool_scripts : Nil
      end

      # **Network Replication (@[RPC])**: Configuring multiplayer RPC endpoints, transfer modes, and synchronization.
      #
      # Methods decorated with `@[RPC]` configure multiplayer network RPC endpoints:
      #
      # ```crystal
      # node NetworkPlayer < CharacterBody3D do
      #   @[RPC(mode: :any_peer, call_local: true)]
      #   def sync_position(pos : Vector3) : Void
      #     self.position = pos
      #   end
      # end
      # ```
      #
      # See also: `spec/suites/test_macros_dsl.cr`
      def self.topic_06_network_rpc : Nil
      end
    end
  end
end
