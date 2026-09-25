module Lapis
  module Docs
    # # T. Bindings Architecture & Engine Code Generator
    #
    # LibGodot provides a high-performance binding generator (`tools/api_generator/generate_bindings.cr`
    # and `lapis bind`) that ingests Godot's machine-readable `extension_api.json` and emits strongly-typed
    # Crystal wrapper classes, enums, singletons, and ptrcall dispatches.
    #
    # ---
    #
    # ### 1. Extension API Ingestion & Inheritance Resolution
    #
    # When Godot runs `godot --dump-extension-api`, it dumps the complete reflection specification of the
    # engine API into `extension_api.json`. The generator parses:
    # - **Global Enums and Constants**: Core engine flags, key codes, and return codes.
    # - **Core Builtin Classes**: Math value types (Vector2, Vector3, Transform2D, Color, etc.).
    # - **Engine Classes & Singletons**: All 1,000+ classes derived from `Godot::Object`.
    #
    # Because Crystal requires base classes to be defined before subclasses, the generator constructs
    # a Directed Acyclic Graph (DAG) of class inheritance and performs a **topological sort**
    # (`inherit_chain`), ensuring foundational classes like `Godot::Object`, `Godot::RefCounted`,
    # and `Godot::Node` precede derived nodes like `Godot::Sprite2D` or `Godot::Camera3D`.
    #
    # ---
    #
    # ### 2. Zero-Allocation Stack Ptrcall (`StaticArray`)
    #
    # High-performance games step hundreds of nodes 60 or 120 times per second in `_process` and
    # `_physics_process`. Heap allocations during method dispatch trigger frequent GC pauses.
    #
    # LibGodot generates method invocations using stack-allocated `StaticArray` buffers:
    # ```crystal
    # # Zero-heap allocation: array resides on the C execution stack
    # args = StaticArray[pointerof(arg_0).as(Void*), pointerof(arg_1).as(Void*)]
    # godot_ptrcall_val(m_bind, @pointer, args, ret_val)
    # ```
    #
    # ---
    #
    # ### 3. Type Marshalling Reference Table
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Godot Engine Type</th>
    #       <th style="padding: 10px 14px;">Crystal Binding Type</th>
    #       <th style="padding: 10px 14px;">Dispatch Mechanism</th>
    #       <th style="padding: 10px 14px;">Memory Characteristics</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>int / float / bool</code></td>
    #       <td style="padding: 10px 14px;"><code>Int64 / Float64 / Bool</code></td>
    #       <td style="padding: 10px 14px;"><code>godot_ptrcall_int / float / bool</code></td>
    #       <td style="padding: 10px 14px;">Direct stack pass, zero allocation</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>Vector2 / Vector3 / Transform3D</code></td>
    #       <td style="padding: 10px 14px;"><code>Godot::Vector2 / Vector3 / Transform3D</code></td>
    #       <td style="padding: 10px 14px;"><code>godot_ptrcall_val</code></td>
    #       <td style="padding: 10px 14px;">Value struct copied by reference on stack</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>Object / Node / Resource</code></td>
    #       <td style="padding: 10px 14px;"><code>Godot::Object</code> wrapper instance</td>
    #       <td style="padding: 10px 14px;"><code>godot_ptrcall_obj</code></td>
    #       <td style="padding: 10px 14px;">Native pointer wrapped with monotonic instance ID tracking</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>String / StringName</code></td>
    #       <td style="padding: 10px 14px;"><code>String / Godot::StringName</code></td>
    #       <td style="padding: 10px 14px;"><code>bridge_string_to_crystal</code> / ptrcall</td>
    #       <td style="padding: 10px 14px;">UTF-8 conversion via bridge C-API</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    module T_BINDINGS_ARCHITECTURE_AND_GENERATOR
      def self.features : Array(String)
        [
          "Automated extension_api.json ingestion with topological class DAG resolution",
          "Zero-heap-allocation ptrcalls using stack-allocated StaticArray parameter buffers",
          "Dynamic method bind caching through bridge_get_method_bind",
          "Dedicated macros for void, primitive, value-struct, object, and enum dispatches",
        ]
      end
    end
  end
end

