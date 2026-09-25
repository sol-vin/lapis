module Lapis
  module Docs
    # # U. Code Cleanup, DRY Patterns & C++ RAII
    #
    # LibGodot adheres to strict Don't Repeat Yourself (DRY) principles and RAII safety standards
    # across both its Crystal macro DSL and native C++ loader bridge.
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
    #       <td><strong>Key Features</strong></td>
    #       <td><code>.topic_00_key_features</code></td>
    #       <td>Key DRY architectural patterns implemented across LibGodot.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Ptrcall Dispatch Macros</strong></td>
    #       <td><code>.topic_01_ptrcall_dispatch_macros</code></td>
    #       <td>Consolidated method dispatch macros eliminating thousands of boilerplate lines.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Singleton Delegation</strong></td>
    #       <td><code>.topic_02_singleton_delegation</code></td>
    #       <td>Declarative class-level proxy macros for Godot engine singletons.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>C++ RAII Primitives</strong></td>
    #       <td><code>.topic_03_cpp_raii_primitives</code></td>
    #       <td>ScopedString and ScopedStringName automatic resource management in the bridge.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Actionable Runtime Errors</strong></td>
    #       <td><code>.topic_04_actionable_runtime_errors</code></td>
    #       <td>Context-rich exception messages with hierarchy hints and recovery advice.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/binding_macros.cr`, `src/bridge/common.hpp`
    # - **Live Specifications**: `spec/suites/test_core_builtins.cr`
    # - **Related Guides**: `Docs::T_BINDINGS_ARCHITECTURE_AND_GENERATOR`, `Docs::W_CPP_BRIDGE_ARCHITECTURE`
    module U_CODE_CLEANUP_AND_DRY_PATTERNS
      # **Key Features**: Returns key DRY architectural patterns implemented across LibGodot.
      def self.topic_00_key_features : Array(String)
        [
          "Centralized ptrcall dispatch macros eliminating thousands of lines of boilerplate",
          "Declarative singleton delegation macros for clean, idiomatic Crystal APIs",
          "C++ RAII primitives ensuring exception safety and leak-free native bridge execution",
          "Actionable runtime diagnostics with child hierarchy hints and dead-pointer recovery advice",
        ]
      end

      # **Ptrcall Dispatch Macros**: Consolidated method dispatch macros eliminating boilerplate.
      #
      # Rather than repeating raw pointer declarations, `nil` checks, and unsafe casts across 1,000+ classes,
      # LibGodot consolidates ptrcall execution into dedicated macros in `src/libgodot/binding_macros.cr`:
      # - `godot_ptrcall_void`: Executes a non-returning engine method call.
      # - `godot_ptrcall_bool`: Dispatches and returns a primitive boolean.
      # - `godot_ptrcall_int`: Dispatches and casts a typed integer.
      # - `godot_ptrcall_float`: Dispatches and casts a floating-point scalar.
      # - `godot_ptrcall_val`: Allocates a value-type struct buffer on the stack and populates it.
      # - `godot_ptrcall_obj`: Marshals a native pointer return into a typed `Godot::Object` wrapper.
      # - `godot_ptrcall_enum`: Safely casts an underlying integer return to a Crystal enum member.
      #
      # See also: `src/libgodot/binding_macros.cr`
      def self.topic_01_ptrcall_dispatch_macros : Nil
      end

      # **Singleton & Instance Delegation**: Declarative class-level proxy macros for engine singletons.
      #
      # Engine singletons (e.g. `Input`, `Time`, `OS`, `DisplayServer`) often expose global convenience methods.
      # The `delegate_to_instance` and `delegate_property_to_instance` macros synthesize class-level
      # forwarders to the underlying singleton instance in a single declarative line:
      #
      # ```crystal
      # class Input
      #   delegate_to_instance(
      #     is_action_pressed, is_action_just_pressed, is_action_just_released,
      #     get_action_strength, get_vector, get_axis
      #   )
      #   delegate_property_to_instance(mouse_mode, use_accumulated_input)
      # end
      # ```
      def self.topic_02_singleton_delegation : Nil
      end

      # **Native C++ RAII Scoped Handlers**: Automatic resource management primitives in the bridge.
      #
      # In `src/bridge/`, manual memory management is safeguarded using RAII primitives:
      # - **`ScopedString`**: Automatically frees heap-allocated temporary C strings upon scope exit.
      # - **`ScopedStringName`**: Encapsulates Godot `StringName` allocations with automated cleanup.
      # - **`generic_dispatch_lifecycle`**: Unifies node lifecycle callbacks under a single thread-safe template.
      #
      # See also: `src/bridge/common.hpp`
      def self.topic_03_cpp_raii_primitives : Nil
      end

      # **Actionable Runtime Diagnostics**: Context-rich exception messages with hierarchy hints.
      #
      # When runtime errors occur, LibGodot provides actionable debugging context:
      # - If `get_node("Player")` fails, the error lists all available children on the node.
      # - If an object was freed, `DisposedObjectError` reports the exact 64-bit instance ID.
      def self.topic_04_actionable_runtime_errors : Nil
      end
    end
  end
end
