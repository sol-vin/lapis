module Lapis
  module Docs
    # # U. Code Cleanup, DRY Patterns & C++ RAII
    #
    # LibGodot adheres to strict Don't Repeat Yourself (DRY) principles and RAII safety standards
    # across both its Crystal macro DSL and native C++ loader bridge.
    #
    # ---
    #
    # ### 1. Ptrcall Dispatch Macros
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
    # ---
    #
    # ### 2. Singleton & Instance Delegation
    #
    # Engine singletons (e.g. `Input`, `Time`, `OS`, `DisplayServer`) often expose global convenience methods.
    # The `delegate_to_instance` and `delegate_property_to_instance` macros synthesize class-level
    # forwarders to the underlying singleton instance in a single declarative line:
    # ```crystal
    # class Input
    #   delegate_to_instance(
    #     is_action_pressed, is_action_just_pressed, is_action_just_released,
    #     get_action_strength, get_vector, get_axis
    #   )
    #   delegate_property_to_instance(mouse_mode, use_accumulated_input)
    # end
    # ```
    #
    # ---
    #
    # ### 3. Native C++ RAII Scoped Handlers
    #
    # In `src/bridge/`, manual memory management is safeguarded using RAII (Resource Acquisition Is
    # Initialization) primitives:
    # - **`ScopedString`**: Automatically frees heap-allocated temporary C strings upon scope exit.
    # - **`ScopedStringName`**: Encapsulates Godot `StringName` allocations with automated cleanup.
    # - **`generic_dispatch_lifecycle`**: Unifies node lifecycle callbacks (`_ready`, `_process`,
    #   `_physics_process`, `_enter_tree`, `_exit_tree`) under a single thread-safe, GC-registered template.
    #
    # ---
    #
    # ### 4. Architectural Evolution Summary
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Area</th>
    #       <th style="padding: 10px 14px;">Legacy Pattern</th>
    #       <th style="padding: 10px 14px;">Modernized DRY Pattern</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Method Dispatch</strong></td>
    #       <td style="padding: 10px 14px;">Heap <code>Array(Void*)</code> with 12 lines per method</td>
    #       <td style="padding: 10px 14px;">Stack <code>StaticArray</code> + one-line <code>godot_ptrcall_*</code> macro</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Singleton Proxies</strong></td>
    #       <td style="padding: 10px 14px;">Manual <code>def self.foo; Bridge.foo; end</code> forwarders</td>
    #       <td style="padding: 10px 14px;">Declarative <code>delegate_to_instance</code> macro</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>C++ Memory Safety</strong></td>
    #       <td style="padding: 10px 14px;">Manual <code>free()</code> / <code>destructor</code> pairs</td>
    #       <td style="padding: 10px 14px;">RAII <code>ScopedString</code> and <code>ScopedStringName</code> wrappers</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Runtime Errors</strong></td>
    #       <td style="padding: 10px 14px;">Generic exceptions without context</td>
    #       <td style="padding: 10px 14px;">Actionable hints (child listing for get_node, #alive? for disposed objects)</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    module U_CODE_CLEANUP_AND_DRY_PATTERNS
      def self.features : Array(String)
        [
          "Centralized ptrcall dispatch macros eliminating thousands of lines of boilerplate",
          "Declarative singleton delegation macros for clean, idiomatic Crystal APIs",
          "C++ RAII primitives ensuring exception safety and leak-free native bridge execution",
          "Actionable runtime diagnostics with child hierarchy hints and dead-pointer recovery advice",
        ]
      end
    end
  end
end

