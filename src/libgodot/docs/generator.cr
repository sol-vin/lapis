module Lapis
  module Docs
    # # T. Bindings Architecture & Engine Code Generator
    #
    # LibGodot provides a high-performance binding generator (`tools/api_generator/generate_bindings.cr`
    # and `lapis bind`) that ingests Godot's machine-readable `extension_api.json` and emits strongly-typed
    # Crystal wrapper classes, enums, singletons, and ptrcall dispatches.
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
    #       <td>Core features of the bindings generator.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Extension API Ingestion</strong></td>
    #       <td><code>.topic_01_extension_api_ingestion</code></td>
    #       <td>Parsing extension_api.json: enums, builtin types, classes, and singletons.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Topological Inheritance Sort</strong></td>
    #       <td><code>.topic_02_topological_inheritance_sort</code></td>
    #       <td>DAG resolution ensuring superclasses are compiled before child node types.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Zero-Alloc Stack Ptrcalls</strong></td>
    #       <td><code>.topic_03_zero_alloc_stack_ptrcalls</code></td>
    #       <td>Stack-allocated StaticArray buffers bypassing heap allocation during dispatches.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Type Marshaling Matrix</strong></td>
    #       <td><code>.topic_04_type_marshaling_matrix</code></td>
    #       <td>Mapping table between Godot Variants and Crystal primitive and struct types.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `tools/api_generator/generate_bindings.cr`, `src/libgodot/binding_macros.cr`
    # - **Config**: `rsrc/extension_api.json`
    # - **Related Guides**: `Docs::N_GODOT_UPGRADE_GUIDE`, `Docs::U_CODE_CLEANUP_AND_DRY_PATTERNS`
    module T_BINDINGS_ARCHITECTURE_AND_GENERATOR
      # **Key Features**: Returns core features of the bindings generator.
      def self.topic_00_key_features : Array(String)
        [
          "Automated extension_api.json ingestion with topological class DAG resolution",
          "Zero-heap-allocation ptrcalls using stack-allocated StaticArray parameter buffers",
          "Dynamic method bind caching through bridge_get_method_bind",
          "Dedicated macros for void, primitive, value-struct, object, and enum dispatches",
        ]
      end

      # **Extension API Ingestion**: Parsing extension_api.json for enums, builtin types, and singletons.
      #
      # When Godot runs `godot --dump-extension-api`, it dumps the reflection metadata
      # of the engine API into `extension_api.json`. The generator parses:
      # - **Global Enums and Constants**: Core engine flags, key codes, and return codes.
      # - **Core Builtin Classes**: Math value types (Vector2, Vector3, Transform2D, Color, etc.).
      # - **Engine Classes & Singletons**: All 1,000+ classes derived from `Godot::Object`.
      #
      # See also: `tools/api_generator/generate_bindings.cr`
      def self.topic_01_extension_api_ingestion : Nil
      end

      # **Topological DAG Inheritance Resolution**: Ordering classes so superclasses precede child node types.
      #
      # Because Crystal requires base classes to be defined before subclasses, the generator constructs
      # a Directed Acyclic Graph (DAG) of class inheritance and performs a **topological sort**
      # (`inherit_chain`), ensuring foundational classes like `Godot::Object`, `Godot::RefCounted`,
      # and `Godot::Node` precede derived nodes like `Godot::Sprite2D` or `Godot::Camera3D`.
      def self.topic_02_topological_inheritance_sort : Nil
      end

      # **Zero-Allocation Stack Ptrcalls**: Stack-allocated parameter buffers bypassing heap allocations during dispatch.
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
      # See also: `src/libgodot/binding_macros.cr`
      def self.topic_03_zero_alloc_stack_ptrcalls : Nil
      end

      # **Type Marshaling Reference Table**: Mapping table between Godot Variants and Crystal types.
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Godot Engine Type</th>
      #       <th>Crystal Binding Type</th>
      #       <th>Dispatch Mechanism</th>
      #       <th>Memory Characteristics</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><code>int / float / bool</code></td>
      #       <td><code>Int64 / Float64 / Bool</code></td>
      #       <td><code>godot_ptrcall_int / float / bool</code></td>
      #       <td>Direct stack pass, zero allocation</td>
      #     </tr>
      #     <tr>
      #       <td><code>Vector2 / Vector3 / Transform3D</code></td>
      #       <td><code>Godot::Vector2 / Vector3 / Transform3D</code></td>
      #       <td><code>godot_ptrcall_val</code></td>
      #       <td>Value struct copied by reference on stack</td>
      #     </tr>
      #     <tr>
      #       <td><code>Object / Node / Resource</code></td>
      #       <td><code>Godot::Object</code> wrapper instance</td>
      #       <td><code>godot_ptrcall_obj</code></td>
      #       <td>Native pointer wrapped with monotonic instance ID tracking</td>
      #     </tr>
      #     <tr>
      #       <td><code>String / StringName</code></td>
      #       <td><code>String / Godot::StringName</code></td>
      #       <td><code>bridge_string_to_crystal</code> / ptrcall</td>
      #       <td>UTF-8 conversion via bridge C-API</td>
      #     </tr>
      #   </tbody>
      # </table>
      def self.topic_04_type_marshaling_matrix : Nil
      end
    end
  end
end
