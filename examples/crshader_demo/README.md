# CrShader Showcase Demo

A complete, working showcase demonstration project combining **Lapis for Crystal** and the **CrShader** GDExtension addon in Godot 4.

## Features

- **2D Animated Water Shader (`shaders/water.crshader`)**:
  - Authored in pure Crystal DSL (`shader_type :canvas_item`).
  - Dual sine wave displacement, dynamic foam interpolation, and configurable wave speed/frequency uniforms.
- **3D Spatial Procedural Plasma Shader (`shaders/plasma.crshader`)**:
  - Authored in pure Crystal DSL (`shader_type :spatial`).
  - Vertex displacement pulse along normal vectors with tri-harmonic 3D procedural noise and emissive color blending.
- **In-Editor CrShader Studio Dock**:
  - Seamless bottom panel editor with syntax highlighting and split-pane live preview.
  - Automatically compiles `.crshader` files to `.gdshader` upon save or modification.
- **Interactive Scene Controller (`src/main.cr`)**:
  - Native Crystal node (`CrShaderDemoScene < Node3D`) managing real-time mesh rotation and FPS metrics.

---

## Architectural Note: Why GDExtension Addons Do Not Contain `libgodot.dll`

In Lapis, execution follows a **Dual-Paradigm Architecture**:
- **Mode A: GDExtension Addons & In-Editor Iteration**:
  - **Host Binary**: `godot.exe` (or `godot` on Linux/macOS).
  - **Libraries**: `crystal_bridge.dll` + addon dynamic library (`game.dll`) + CRT dependencies (`gc.dll`, `iconv-2.dll`, `pcre2-8.dll`).
  - When Godot loads the addon, it provides a C function pointer table (`GDExtensionInterface*`).
  - **`libgodot.dll` is never linked or loaded**. Bundling `libgodot.dll` (~85MB) would cause severe memory conflicts with Godot's internal ObjectDB singletons.
- **Mode B: Standalone Embedded Host**:
  - **Host Binary**: `bin/game.exe` (compiled Crystal executable).
  - **Library**: `bin/libgodot.dll` (Godot engine embedded shared library).

---

## Building and Running

### 1. Build the Demo
```powershell
make all
```

### 2. Launch in Godot Editor
```powershell
make editor
```
In the editor:
1. Observe the **"CrShader Studio"** tab in the bottom panel.
2. Select `water.crshader` or `plasma.crshader` from the dropdown.
3. Edit shader parameters (e.g. `wave_speed` or `plasma_color_a`) and click **▶ Compile**.
4. The viewport immediately updates with your live shader changes!

### 3. Run the Playable Demo
```powershell
make run
```
