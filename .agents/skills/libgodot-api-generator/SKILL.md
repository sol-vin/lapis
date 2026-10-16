---
name: libgodot-api-generator
description: >-
  Dump Godot engine GDExtension API and generate typed Crystal classes, enums,
  singletons, and method bindings. Use when upgrading Godot versions or regenerating bindings.
---

# LibGodot API Generator Runbook

This skill outlines how to dump the Godot GDExtension specification (`extension_api.json`) and regenerate the complete typed Crystal API bindings.

---

## Table of Contents
<table>
  <thead>
    <tr>
      <th align="left">Section</th>
      <th align="left">Description</th>
      <th align="center">Lines</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="#1-dumping-extensionapijson-regenerating-engine-bindings"><strong>1. Dumping `extension_api.json` & Regenerating Engine Bindings</strong></a></td>
      <td>Whenever Godot is updated to a new version (e.g.</td>
      <td align="center"><code>L54–L74</code></td>
    </tr>
    <tr>
      <td><a href="#2-the-gdextension-api-schema-dispatch-architecture"><strong>2. The GDExtension API Schema & Dispatch Architecture</strong></a></td>
      <td>extension_api.json defines the complete engine interface:</td>
      <td align="center"><code>L75–L86</code></td>
    </tr>
    <tr>
      <td><a href="#3-generating-project-gdscript-node-bindings"><strong>3. Generating Project GDScript Node Bindings</strong></a></td>
      <td>To inspect custom GDScript nodes in a project and generate typed Crystal wrapper classes:</td>
      <td align="center"><code>L87–L102</code></td>
    </tr>
    <tr>
      <td><a href="#4-customizing-mappings-overrides-toolsapigeneratoroverridesyml"><strong>4. Customizing Mappings & Overrides (`tools/api_generator/overrides.yml`)</strong></a></td>
      <td>The generator reads tools/api_generator/overrides.yml to resolve keyword collisions and map native types:</td>
      <td align="center"><code>L103–L134</code></td>
    </tr>
    <tr>
      <td><a href="#5-post-generation-verification"><strong>5. Post-Generation Verification</strong></a></td>
      <td>After regenerating bindings:</td>
      <td align="center"><code>L135–L140</code></td>
    </tr>
  </tbody>
</table>

---

## 1. Dumping `extension_api.json` & Regenerating Engine Bindings

Whenever Godot is updated to a new version (e.g. 4.8-dev7) or engine modules change, regenerate the API bindings using `lapis`:

```bash
lapis bind engine --dump
```
Or via Makefile:
```bash
make dump_api
make generate
```

### What is Generated:
- `src/libgodot/generated/global_enums.cr`: Global engine enums (`Error`, `Key`, `MouseButton`, `PropertyHint`, etc.).
- `src/libgodot/generated/singletons.cr`: Engine singletons (`Engine`, `Input`, `AudioServer`, `RenderingServer`, `Time`, etc.).
- `src/libgodot/generated/classes/*.cr`: Topologically sorted Godot engine class definitions with typed method bindings, doc comments, and properties.
- `src/libgodot/generated/classes/all_classes.cr`: Manifest requiring all generated classes in topological dependency order.

---

## 2. The GDExtension API Schema & Dispatch Architecture

`extension_api.json` defines the complete engine interface:
1. **Builtin Types**: Primitive math structures (`Vector2`, `Vector3`, `Transform3D`, `Color`, `Quaternion`) with exact byte sizes and offsets per architecture (`x86_64`, `arm64`).
2. **Classes & Inheritance Hierarchy**: Every native Godot class, its parent class, exposed properties, signals, constants, and virtual methods.
3. **Method Dispatch Mechanisms**:
   - **`ptrcall` (Fast Direct Dispatch)**: Used for statically typed engine methods passing unboxed pointers (`GDExtensionTypePtr`). Zero Variant allocation overhead.
   - **`call` (Vararg Dispatch)**: Used for dynamic or variadic methods (e.g. `call`, `emit_signal`), taking `GDExtensionConstVariantPtr*`.
   - **Virtual Callbacks**: Hooked via `GDExtensionClassCallVirtual` function pointers registered in `ClassDB`.

---

## 3. Generating Project GDScript Node Bindings

To inspect custom GDScript nodes in a project and generate typed Crystal wrapper classes:

```bash
lapis bind project [project_dir]
```
Or via Makefile:
```bash
make project_bindings [PROJECT=path]
```

This scans all `.gd` scripts with `class_name`, parses their exported variables, signals, and typed functions, and generates drop-in typed Crystal classes with `#alive?` and dead-pointer safety guards.

---

## 4. Customizing Mappings & Overrides (`tools/api_generator/overrides.yml`)

The generator reads `tools/api_generator/overrides.yml` to resolve keyword collisions and map native types:

```yaml
keywords:
  # Rename Godot parameter names that clash with Crystal reserved keywords
  type: type_id
  end: end_pos
  begin: begin_pos
  class: class_type
  default: default_val
  in: in_val
  out: out_val

type_map:
  # Map Godot primitives to Crystal types
  bool: Bool
  int: Int64
  float: Float64
  String: String
  Vector2: Godot::Vector2
  Vector3: Godot::Vector3
  Color: Godot::Color
  Rect2: Godot::Rect2
  Transform3D: Godot::Transform3D
```

If a newly generated Godot class causes a Crystal compilation error due to a reserved keyword or parameter name collision, add the mapping to `tools/api_generator/overrides.yml` and run `make generate` again.

---

## 5. Post-Generation Verification

After regenerating bindings:
1. Run `make all` to ensure all generated classes compile cleanly.
2. Run `make test` to verify that method binds and singletons function properly.
