module Lapis
  module Docs
    # # L. Macro DSL Reference & In-Editor Reflection Manual
    #
    # LibGodot provides an expressive, compile-time checked Domain Specific Language (DSL)
    # for declaring Godot engine classes, resources, refcounted objects, inspector exports,
    # signals, RPC endpoints, and editor tools.
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
    #       <td><strong>Class Declarations</strong></td>
    #       <td><code>.topic_01_class_declaration_macros</code></td>
    #       <td>node, resource, and gdclass macros with superclasses and zero-block syntax.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Export Annotations</strong></td>
    #       <td><code>.topic_02_property_export_annotations</code></td>
    #       <td>@[Export], @[ExportRange], @[ExportEnum], @[ExportFile], @[ExportToolButton].</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Signals & Bound Signals</strong></td>
    #       <td><code>.topic_03_signals_and_bound_signals</code></td>
    #       <td>signal declaration, emit_<name>, on_<name> blocks, and first-class await.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Tool & RPC Directives</strong></td>
    #       <td><code>.topic_04_tool_and_rpc_directives</code></td>
    #       <td>@[Tool] in-editor execution and @[RPC] multiplayer synchronization.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>OnReady Lazy Bindings</strong></td>
    #       <td><code>.topic_05_onready_lazy_bindings</code></td>
    #       <td>onready macro for automatic node lookup evaluated during _ready.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/macros.cr`, `src/libgodot/binding_macros.cr`
    # - **Live Specifications**: `spec/suites/test_macros_dsl.cr`
    # - **Showcase Examples**: `examples/basic_demo/src/main.cr`
    # - **Related Guides**: `Docs::D_NODE_DSL_AND_SIGNALS`, `Docs::C_EXPORTS_AND_INSPECTOR`
    module L_MACRO_DSL_REFERENCE
      # **Key Features & Capabilities**: Summary list of supported DSL macro directives.
      def self.topic_00_key_features : Array(String)
        [
          "node macro for scene nodes defaulting to Godot::Node",
          "resource macro for custom resources defaulting to Resource",
          "gdclass macro for RefCounted engine classes",
          "Complete @[Export] annotations: ranges, enums, files, flags, groups, buttons",
          "Type-safe signal emission, ergonomic on_<signal> listeners, and first-class await",
          "@[Tool] in-editor execution, @[RPC] networking, and onready lazy node binding",
        ]
      end

      # **Class Declaration Macros**: node, resource, and gdclass macros with superclasses and zero-block syntax.
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Macro</th>
      #       <th>Default Superclass</th>
      #       <th>Zero-Block Syntax</th>
      #       <th>Description</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><code>node Name &lt; Parent do ... end</code></td>
      #       <td><code>Godot::Node</code></td>
      #       <td><code>node Name</code></td>
      #       <td>Declares a scene graph Node class exposed to Godot's ClassDB.</td>
      #     </tr>
      #     <tr>
      #       <td><code>resource Name &lt; Parent do ... end</code></td>
      #       <td><code>Resource</code></td>
      #       <td><code>resource Name</code></td>
      #       <td>Declares a serializable Godot Resource class (.tres / .res).</td>
      #     </tr>
      #     <tr>
      #       <td><code>gdclass Name &lt; Parent do ... end</code></td>
      #       <td><code>RefCounted</code></td>
      #       <td><code>gdclass Name</code></td>
      #       <td>Declares a reference-counted engine class managed by ObjectDB.</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # #### Working Code Examples:
      # ```crystal
      # require "libgodot"
      #
      # # Scene node:
      # node PlayerController < CharacterBody3D do
      #   @[Export]
      #   property speed : Float32 = 7.5_f32
      # end
      #
      # # Custom serializable resource:
      # resource InventoryItem do
      #   @[Export]
      #   property item_name : String = "Health Potion"
      #   @[Export]
      #   property heal_power : Int32 = 50
      # end
      #
      # # RefCounted utility object:
      # gdclass StateMachine do
      #   property current_state : String = "idle"
      # end
      # ```
      #
      # See also: `spec/suites/test_macros_dsl.cr`
      def self.topic_01_class_declaration_macros : Nil
      end

      # **Property Export Annotations**: @[Export], @[ExportRange], @[ExportEnum], @[ExportFile], @[ExportToolButton].
      #
      # Export annotations configure how Crystal properties are exposed to the Godot Inspector,
      # serialized into `.tscn` and `.tres` scene files, and accessed by GDScript:
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Annotation</th>
      #       <th>Inspector Control</th>
      #       <th>Example Syntax</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><code>@[Export]</code></td>
      #       <td>Type-inferred editor control</td>
      #       <td><code>@[Export] property speed : Float32 = 5.0_f32</code></td>
      #     </tr>
      #     <tr>
      #       <td><code>@[ExportRange]</code></td>
      #       <td>Numeric slider with min, max, step</td>
      #       <td><code>@[ExportRange(0.0, 100.0, 0.5)] property hp : Float64 = 100.0</code></td>
      #     </tr>
      #     <tr>
      #       <td><code>@[ExportEnum]</code></td>
      #       <td>Dropdown choice list or Crystal Enum</td>
      #       <td><code>@[ExportEnum("Warrior", "Mage")] property job : String = "Warrior"</code></td>
      #     </tr>
      #     <tr>
      #       <td><code>@[ExportFile]</code></td>
      #       <td>File picker dialog with extension filter</td>
      #       <td><code>@[ExportFile("*.png,*.jpg")] property icon_path : String = ""</code></td>
      #     </tr>
      #     <tr>
      #       <td><code>@[ExportToolButton]</code></td>
      #       <td>Clickable action button in Inspector</td>
      #       <td><code>@[ExportToolButton("Regenerate")] property btn = -&gt;regenerate</code></td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # See also: `Docs::C_EXPORTS_AND_INSPECTOR`
      def self.topic_02_property_export_annotations : Nil
      end

      # **Signals & Bound Signals**: signal declaration, emit_<name>, on_<name> blocks, and first-class await.
      #
      # The `signal` macro synthesizes a type-safe emission helper and event listener hook:
      #
      # ```crystal
      # node GameHero < CharacterBody3D do
      #   signal damage_taken(amount : Int32, source : String)
      #   signal defeated
      #
      #   def take_hit(dmg : Int32, src : String) : Void
      #     emit_damage_taken(dmg, src)
      #   end
      # end
      # ```
      #
      # #### Synthesized Helpers:
      # - `emit_damage_taken(amount : Int32, source : String)`: Type-safe dispatch.
      # - `on_damage_taken(&block)`: Ergonomic closure listener.
      # - `hero.damage_taken`: Returns first-class `BoundSignal` object.
      #
      # #### First-Class Signal Awaiting:
      # ```crystal
      # # Non-blocking asynchronous await:
      # await(hero.defeated, timeout_sec: 10.0)
      # hero.defeated.await(timeout_sec: 10.0)
      # ```
      #
      # See also: `spec/suites/test_editor_signals.cr`
      def self.topic_03_signals_and_bound_signals : Nil
      end

      # **Tool & RPC Directives**: @[Tool] in-editor execution and @[RPC] multiplayer synchronization.
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Directive</th>
      #       <th>Scope</th>
      #       <th>Description</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><code>@[Tool]</code> or <code>tool</code></td>
      #       <td>Class level</td>
      #       <td>Enables execution inside the Godot Editor in real time for gizmos and previews.</td>
      #     </tr>
      #     <tr>
      #       <td><code>@[RPC]</code></td>
      #       <td>Method level</td>
      #       <td>Configures multiplayer network replication (call_local, mode, channel).</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # See also: `src/main.cr`
      def self.topic_04_tool_and_rpc_directives : Nil
      end

      # **OnReady Lazy Bindings**: onready macro for automatic node lookup evaluated during _ready.
      #
      # The `onready` directive evaluates node lookups automatically during `_ready`:
      #
      # ```crystal
      # node CharacterView < Node3D do
      #   onready anim_player : AnimationPlayer = "AnimationPlayer"
      #   onready camera : Camera3D = "CameraRig/Camera3D"
      #
      #   def play_intro : Void
      #     anim_player.play("intro")
      #   end
      # end
      # ```
      #
      # Automatically performs type casting and raises actionable errors if the target node is missing.
      def self.topic_05_onready_lazy_bindings : Nil
      end
    end
  end
end
