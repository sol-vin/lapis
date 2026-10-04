---
name: lapis-dsl-authoring
description: Metaprogramming and macro authoring manual for extending the Lapis DSL, generating GDExtension bindings, and compiling ClassDB registration tables in Crystal. Covers macro AST manipulation, macro finished hooks, argument unpacking from GDExtensionConstTypePtr, variant conversion bridges, annotation inspection, and C-API function pointer synthesis. Use when adding new DSL macros, creating custom node decorators, or debugging macro expansion issues.
---

# Lapis DSL Authoring & Metaprogramming Manual

This skill is the engineering guide for authoring Crystal macros, expanding the **Lapis Gameplay DSL**, and bridging Crystal high-level abstractions to Godot's low-level **GDExtension C-API**.

---

## 1. Architectural Overview

The Lapis DSL sits at the boundary between two worlds:
1. **High-Level Crystal**: Static types, macros, closures, garbage collection, and expressive object-oriented design.
2. **Godot C-API (GDExtension)**: Raw C function pointers, type-erased `GDExtensionConstTypePtr` argument arrays, and C++ ClassDB reflection dictionaries.

```
Crystal Source Code (node Player < CharacterBody2D)
       │
       ▼
Crystal Macro Expansion (macro node)
  ├── 1. Class Inheritance Hierarchy Setup
  ├── 2. Property & Getter/Setter Synthesis
  ├── 3. Signal Declarations & Emitter Synthesis
  └── 4. Defers Registration via `macro finished`
       │
       ▼
`macro finished` Hook
  ├── Inspects @type.methods, annotations, instance_vars
  ├── Generates native C function wrappers (ptrcall / call_virtual_func)
  └── Emits static class registration callback into ClassRegistry
       │
       ▼
GDExtension ClassDB Registration at Engine Startup
```

---

## 2. Macro AST Manipulation & Inspection

### AST Directives
- `macro name(args)`: Defines a macro.
- `{% ... %}`: Macro control flow (`if`, `unless`, `for`, `begin`).
- `{{ ... }}`: Macro expression interpolation into the generated Crystal code.
- `.id`: Converts a macro string or symbol into a raw syntax identifier (e.g. `"Node2D".id`).

### Type & Method Introspection
```crystal
macro inspect_class_members
  {% for method in @type.methods %}
    {% if ann = method.annotation(Export) %}
      # Found exported method {{ method.name }}
      # Arguments: {{ method.args }}
      # Return type: {{ method.return_type }}
    {% end %}
  {% end %}
end
```

---

## 3. The `macro finished` Pattern

In Crystal, subclasses can define methods, properties, and include mixins throughout the body of the class. If registration runs immediately when `macro node` is called, methods defined later in the class body will be missed!

**Invariant**: Always defer ClassDB reflection until the class definition has concluded using `macro finished`:

```crystal
macro node(decl, &block)
  class {{decl}}
    {{block.body}}

    macro finished
      # Runs after the entire class body is parsed by the compiler!
      # All properties, methods, signals, and included mixins are now visible:
      {% for method in @type.methods %}
        # Synthesize ClassDB binding entries here
      {% end %}
    end
  end
end
```

---

## 4. Synthesizing C-API Wrappers & Function Pointers

Godot's GDExtension invokes Crystal methods through raw C function pointers conforming to `GDExtensionClassMethodCall`:

```c
typedef void (*GDExtensionClassMethodCall)(
    void *method_userdata,
    GDExtensionClassInstancePtr p_instance,
    const GDExtensionConstTypePtr *p_args,
    GDExtensionTypePtr r_ret
);
```

### Crystal Wrapper Generator Pattern:
```crystal
# Generate native C callback for a method 'take_damage(amount : Int32) : Void'
->(
  method_userdata : Pointer(Void),
  instance_ptr : LibGodot::GDExtensionClassInstancePtr,
  args_ptr : Pointer(LibGodot::GDExtensionConstTypePtr),
  ret_ptr : LibGodot::GDExtensionTypePtr
) {
  # 1. Recover the Crystal class instance from userdata/instance_ptr
  instance = Box(Player).unbox(instance_ptr)

  # 2. Defensive alive check to prevent segmentation faults
  instance.check_alive!

  # 3. Unpack arguments from raw C pointers
  # arg 0: Int32
  raw_arg0 = args_ptr[0].as(Pointer(Int32)).value

  # 4. Invoke target Crystal method
  result = instance.take_damage(raw_arg0)

  # 5. Pack return value into r_ret if non-void
  # ret_ptr.as(Pointer(ReturnType)).value = result
}
```

---

## 5. Argument Unpacking Rules (`GDExtensionConstTypePtr`)

<table>
  <thead>
    <tr>
      <th align="left">Type Category</th>
      <th align="left">Crystal Type</th>
      <th align="left">Unpacking Logic</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Primitive Integer</td>
      <td><code>Int32</code> / <code>Int64</code></td>
      <td><code>args_ptr[i].as(Pointer(Int32)).value</code></td>
    </tr>
    <tr>
      <td>Primitive Float</td>
      <td><code>Float32</code> / <code>Float64</code></td>
      <td><code>args_ptr[i].as(Pointer(Float64)).value</code></td>
    </tr>
    <tr>
      <td>Primitive Bool</td>
      <td><code>Bool</code></td>
      <td><code>args_ptr[i].as(Pointer(UInt8)).value != 0</code></td>
    </tr>
    <tr>
      <td>Math Struct</td>
      <td><code>Vector2</code>, <code>Vector3</code>, <code>Color</code></td>
      <td><code>args_ptr[i].as(Pointer(Vector2)).value</code></td>
    </tr>
    <tr>
      <td>Godot Object / Node</td>
      <td><code>Godot::Node2D</code></td>
      <td><code>Godot::Object.from_native_ptr(args_ptr[i].as(Pointer(Void)))</code></td>
    </tr>
    <tr>
      <td>Godot String</td>
      <td><code>String</code></td>
      <td>Read <code>Godot::String</code> via C-API and convert with <code>.to_s</code></td>
    </tr>
    <tr>
      <td>Dynamic Variant</td>
      <td><code>Godot::Variant</code></td>
      <td><code>Godot::Variant.new(args_ptr[i].as(Pointer(Void)))</code></td>
    </tr>
  </tbody>
</table>

---

## 6. Authoring New Convenience Node Macros

When authoring new DSL macros (e.g. `node2d`, `node3d`), always forward the block body into the underlying `node` macro while setting the default base class:

```crystal
# Convenience macro for 2D scene nodes defaulting to Godot::Node2D
macro node2d(decl)
  node2d {{decl}} do
  end
end

macro node2d(decl, &block)
  {% if decl.is_a?(Call) && decl.name == "<" %}
    # User specified explicit subclass: node2d Player < CharacterBody2D
    node {{decl}} do
      {{block.body}}
    end
  {% else %}
    # Defaults automatically to Godot::Node2D
    node {{decl}} < Godot::Node2D do
      {{block.body}}
    end
  {% end %}
end
```

---

## 7. The `ensure_lapis` Dependency Loader Macro

When writing redistributable addons or multi-addon test fixtures, use `ensure_lapis` to conditionally load `lapis` without causing duplicate require cycles or missing dependency errors in unified test runner environments:

```crystal
# Expressive loader macro to ensure Lapis engine bindings are loaded
macro ensure_lapis
  {% unless @top_level.has_constant?(:Godot) %}
    require "lapis"
  {% end %}
end
```

---

## 8. Macro AST Unwrapping for Unary Tilde & Expressions

When building ergonomic syntax sugar macros like `onready`, inspecting the Crystal macro AST allows unwrapping expressions at compile time to optimize runtime dispatch:

```crystal
# Unwrapping unary ~ from expressions like: onready sprite = ~"Sprite2D"
{% if stmt.value.is_a?(Call) && stmt.value.name.stringify == "~" %}
  {% inner_arg = stmt.value.receiver || (stmt.value.args.size > 0 ? stmt.value.args[0] : nil) %}
  {% if inner_arg.is_a?(StringLiteral) %}
    # Extracted raw literal path: "Sprite2D"
    found = get_node_as({{inner_arg}}, {{v_type}})
  {% end %}
{% end %}
```

---

## 9. Typed Lambda Flow-Typing in Macro Patterns (`match`)

In Crystal, local variables cannot easily change type within an arbitrary lexical scope without a union or `if var.is_a?(Type)` branch. To enable implicit narrowing (e.g. `match i do is Int64 do i * 2 end end`), wrap the branch execution in an immediately-invoked typed proc:

```crystal
# Synthesize an immediately-invoked typed proc with target variable shadow-binding:
%result = (->({{ target }} : {{ pattern_type }}) {
  {{ branch_body }}
}).call(%cast_value)
```
This guarantees:
1. `{{ target }}` is strictly flow-typed as `pattern_type` inside the branch.
2. Zero heap allocations when inlined by LLVM.
3. Crystal's type inferrer permits calling methods on `{{ target }}` without manual casts or explicit block arguments.

---

## 10. Common Metaprogramming Pitfalls

1. **Macro Expansion Recursion**: Never define a macro that calls itself with identical argument patterns without an AST structural base case.
2. **Missing `check_alive!`**: When generating C-callable wrappers, ALWAYS call `instance.check_alive!` before invoking the underlying Crystal method. If the Godot node was freed via GDScript, accessing it without this check causes an immediate, unrecoverable `0xC0000005` access violation.
3. **Box Unboxing Safety**: Always ensure the pointer passed to `Box(T).unbox` is non-null.
4. **Preserving Doc Comments**: Crystal doc comments (`# ...`) placed above method declarations in user code can be captured via `@type.methods.first.doc` and registered into Godot's `EditorHelp` XML documentation database.
