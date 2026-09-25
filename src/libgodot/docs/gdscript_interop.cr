module Lapis
  module Docs
    # # F. GDScript Interoperability & Automated Project Bindings
    #
    # LibGodot includes automated compile-time interoperability with GDScript, generating strongly
    # typed Crystal wrapper classes directly from your project's custom GDScript nodes and scenes.
    # It supports seamless bidirectional signal handling, method calling, and Variant marshaling.
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
    #       <td><strong>Autobound Project Nodes</strong></td>
    #       <td><code>.topic_01_autobound_project_nodes</code></td>
    #       <td>Compiling typed Crystal wrappers for project GDScript nodes via make project_bindings.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Variant Marshaling</strong></td>
    #       <td><code>.topic_02_variant_marshaling</code></td>
    #       <td>Transparent two-way type conversion between Crystal primitives and Godot Variants.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Bidirectional Signals</strong></td>
    #       <td><code>.topic_03_bidirectional_signals</code></td>
    #       <td>Connecting GDScript listeners to Crystal signals and vice-versa.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Cross-Language Instantiation</strong></td>
    #       <td><code>.topic_04_cross_language_instantiation</code></td>
    #       <td>Instantiating GDScript scenes in Crystal and attaching Crystal nodes in GDScript.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Dynamic Reflection</strong></td>
    #       <td><code>.topic_05_dynamic_reflection</code></td>
    #       <td>Using call, get, and set for dynamic runtime dispatch.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/variant.cr`, `src/libgodot/bridge.cr`
    # - **Live Specifications**: `spec/suites/test_autobound_gdscript_nodes.cr`, `spec/suites/test_gdscript_crystal_interop_deep.cr`
    # - **Related Guides**: `Docs::D_NODE_DSL_AND_SIGNALS`, `Docs::K_CONCURRENCY_CHANNELS_AND_ERGONOMICS`
    module F_GDSCRIPT_INTEROP
      # **Key Features & Capabilities**: Core capabilities of GDScript interoperability.
      def self.topic_00_key_features : Array(String)
        [
          "automated_ast_introspection",
          "typed_project_bindings",
          "typed_properties",
          "typed_signals",
          "variant_marshaling",
        ]
      end

      # **Autobound Project Nodes**: Compiling typed Crystal wrappers for project GDScript nodes via make project_bindings.
      #
      # Custom GDScript nodes (declared with `class_name` and extending Godot node types) are
      # introspected at compile time by Godot in headless mode. The binding generator creates
      # typed Crystal classes in `src/generated/project_nodes/`:
      #
      # ```crystal
      # # Generated wrapper in src/generated/project_nodes/:
      # module Godot
      #   class QuestTracker < Godot::Node
      #     def self.from(node : Godot::Object) : self
      #     def award_experience(points : Int64) : Int64
      #     def get_current_quest_title : String
      #     def active_quest_id : String
      #     def active_quest_id=(val : String) : Void
      #     def quest_completed : Godot::BoundSignal
      #   end
      # end
      #
      # # Usage in Crystal:
      # tracker = Godot::QuestTracker.from(quest_node)
      # tracker.award_experience(500_i64)
      # Godot.print("Active Quest: #{tracker.active_quest_id}")
      # tracker.active_quest_id = "QUEST_002"
      # ```
      #
      # See also: `spec/suites/test_autobound_gdscript_nodes.cr`
      def self.topic_01_autobound_project_nodes : Nil
      end

      # **Variant Marshaling**: Transparent two-way type conversion between Crystal primitives and Godot Variants.
      #
      # 1. When calling an auto-bound GDScript method, Crystal passes typed arguments through
      #    the GDExtension bridge argument marshaller.
      # 2. It dispatches the call through Godot's `object_call` / `object_call_ret_*` C-API.
      # 3. Return values are unmarshaled back into native Crystal types (`String`, `Int64`,
      #    `Float64`, `Bool`, `Godot::Object`).
      # 4. Native variant resources are automatically lifecycle-managed to prevent memory leaks.
      #
      # See also: `src/libgodot/variant.cr`
      def self.topic_02_variant_marshaling : Nil
      end

      # **Bidirectional Signals**: Connecting GDScript listeners to Crystal signals and vice-versa.
      #
      # Signals flow freely across the language boundary:
      #
      # #### Crystal Emitting to GDScript:
      # ```crystal
      # node BossMonster < Node3D do
      #   signal enraged(multiplier : Float32)
      #
      #   def trigger_phase_two : Void
      #     emit_enraged(1.5_f32)
      #   end
      # end
      # ```
      #
      # ```gdscript
      # # In GDScript:
      # func _ready():
      #     $BossMonster.enraged.connect(_on_boss_enraged)
      #
      # func _on_boss_enraged(multiplier: float):
      #     print("Boss enraged with multiplier: ", multiplier)
      # ```
      #
      # See also: `spec/suites/test_gdscript_crystal_interop_deep.cr`
      def self.topic_03_bidirectional_signals : Nil
      end

      # **Cross-Language Instantiation**: Instantiating GDScript scenes in Crystal and attaching Crystal nodes in GDScript.
      #
      # Crystal can load and instantiate GDScript scene hierarchies (`.tscn`):
      #
      # ```crystal
      # scene_resource = ResourceLoader.load("res://scenes/enemy.tscn").as(PackedScene)
      # enemy_instance = scene_resource.instantiate.as(Node3D)
      # add_child(enemy_instance)
      # ```
      def self.topic_04_cross_language_instantiation : Nil
      end

      # **Dynamic Reflection**: Using call, get, and set for dynamic runtime dispatch.
      #
      # For dynamic properties or un-typed GDScript scripts, use `call`:
      #
      # ```crystal
      # result = node.call("custom_gdscript_method", 42, "hello")
      # ```
      def self.topic_05_dynamic_reflection : Nil
      end
    end
  end
end
