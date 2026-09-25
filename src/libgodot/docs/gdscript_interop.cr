module Lapis
  module Docs
    # # F. GDScript Interoperability & Automated Project Bindings
    #
    # LibGodot includes automated compile-time interoperability with GDScript, generating strongly
    # typed Crystal wrapper classes directly from your project's custom GDScript nodes and scenes.
    #
    # ---
    #
    # ### Automated Compile-Time Binding (`make project_bindings`)
    #
    # Custom GDScript nodes (declared with `class_name` and extending Godot node types) are automatically
    # introspected at compile time by Godot in headless mode (`dump_project_nodes.gd`). The binding generator
    # (`generate_project_bindings.cr`) creates typed Crystal classes in `src/generated/project_nodes/`:
    #
    # ```
    # # Automatically generated wrapper:
    # # module Godot
    # #   class QuestTracker < Godot::Node
    # #     def self.from(node : Godot::Object) : self
    # #     def award_experience(points : Int64) : Int64
    # #     def get_current_quest_title : String
    # #     def active_quest_id : String
    # #     def active_quest_id=(val : String) : Void
    # #     def quest_completed : Godot::BoundSignal
    # #   end
    # # end
    #
    # # Crystal usage:
    # tracker = Godot::QuestTracker.from(quest_node)
    # tracker.award_experience(500_i64)
    # Godot.print("Active Quest: #{tracker.active_quest_id}")
    # tracker.active_quest_id = "QUEST_002"
    # ```
    #
    # ---
    #
    # ### How Variant Marshaling Works
    #
    # 1. When calling an auto-bound GDScript method, Crystal passes typed arguments through the GDExtension
    #    bridge argument marshaller.
    # 2. It dispatches the call through Godot's `object_call` / `object_call_ret_*` C-API.
    # 3. Return values are unmarshaled back into native Crystal types (`String`, `Int64`, `Float64`,
    #    `Bool`, `Godot::Object`).
    # 4. Native variant resources are automatically lifecycle-managed to prevent memory leaks.
    module F_GDSCRIPT_INTEROP
      # Dummy method for documentation visibility
      def self.features : Array(String)
        ["automated_ast_introspection", "typed_project_bindings", "typed_properties", "typed_signals", "variant_marshaling"]
      end
    end
  end
end

