# Crystal Godot Addon Template (`template-addon`)

This template demonstrates how to write, compile, and package a standalone **GDExtension Addon/Plugin in Crystal** for Godot Engine 4.8+.

Compiled addons built with this template can be distributed to **any standard vanilla Godot user**—they do **not** need Crystal, MinGW, or LibGodot installed to use your plugin or custom nodes.

---

## What's Inside

1. **`src/main.cr`**:
   - `CrystalAddonPlugin < EditorPlugin`: An editor plugin lifecycle hook demonstrating `_enter_tree` and `_exit_tree`.
   - `CrystalAddonBanner < Control`: A custom UI node exported with properties (`message`, `text_color`) that can be placed in any scene.
2. **`spec/`**:
   - `main_spec.cr`: Fast offline Crystal unit specifications verifying node registrations and properties.
   - `editor/editor_spec.cr`: Live in-editor tests registered with `Lapis::Test` and executed in the Godot Editor.
3. **`addons/crystal_addon/`**:
   - `plugin.cfg`: Godot plugin metadata.
   - `plugin.gd`: 2-line GDScript stub extending the registered Crystal `EditorPlugin`.
   - `crystal_addon.gdextension`: Configures Godot to load the native bridge from `res://addons/crystal_addon/bin/`.
   - `bin/`: Contains compiled native binaries (`crystal_bridge.dll`, `game.dll`, `gc.dll`, etc.).
4. **`Makefile`**:
   - Build system for compiling the Crystal code and linking with the LibGodot GDExtension bridge.

---

## Quickstart

### 1. Build the Addon
```bash
make
```

### 2. Run Automated Tests

#### A. In-Editor Test Runner (Godot Editor)
```bash
make editor
```
1. Click the **Crystal** tab in the top bar of the Godot Editor.
2. Under the **Unit Test Runner** tab, both **Crystal Specifications** and **In-Editor Test Suites** appear in the test tree.
3. Click **▶ Run In-Editor Tests** to run live addon assertions directly inside the editor without switching scenes!
4. Click **▶ Run All Specs** to run the offline test suite from within the editor.

#### B. Offline CLI Specifications
```bash
make test       # or: crystal spec
```

### 3. Test Live in the Godot Editor
```bash
make editor
```
The Godot Editor will launch with `crystal_addon` enabled. Check the bottom **Output** panel for the activation message:
```text
[CrystalAddonPlugin] Plugin activated in Godot Editor!
Compiled Crystal GDExtension is running without Crystal installed.
```

### 4. Package for Distribution
To create a clean release `.zip` for non-Crystal users:
```bash
make package RELEASE=1
```
This generates `dist/crystal_addon.zip`.

---

## Distributing to Vanilla Godot Users

1. Send `crystal_addon.zip` to the end-user.
2. The user extracts the `.zip` directly into their Godot project root.
3. Their project now has `res://addons/crystal_addon/`.
4. In Godot, they open **Project Settings -> Plugins** and check **Enable**.
5. All custom nodes (`CrystalAddonBanner`) and editor functionality work out of the box!
