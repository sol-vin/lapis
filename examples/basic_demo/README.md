# LibGodot Crystal Demo Showcase

This directory contains the interactive 3D showcase game demonstrating the capabilities of **LibGodot for Crystal**.

## Overview

The demo provides a fully playable 3D character controller and scene with:
- **Interactive 3D Movement**: Full WASD movement, jumping, sprinting, and smooth physics collisions via `CharacterBody3D`.
- **Spinning Collectible Crystals**: Floating, rotating crystals with sinusoidal bobbing motion that award points when collected.
- **Dynamic UI / HUD**: In-game health bar and score counter showcasing Godot `Range` cohesion.
- **GDScript Interoperability**: Direct invocation of GDScript helper methods and status queries from Crystal.
- **Compile-Time Doc Comments**: All nodes, properties, and signals include rich doc comments exposed to Godot's Inspector and Editor Help.

---

## Controls

| Key / Input | Action |
| :--- | :--- |
| **W, A, S, D** | Move character forward, left, backward, right |
| **Space** | Jump |
| **Shift** (Hold) | Sprint (1.8x speed multiplier) |
| **H** | Revive character when health reaches zero |
| **Esc** | Release / capture mouse cursor |

---

## Demonstrated Features

### 1. `DemoCharacter < CharacterBody3D`
- Exported properties with ranges:
  - `speed` (1.0 to 15.0 m/s)
  - `sprint_multiplier` (1.1 to 3.0x)
  - `jump_velocity` (1.0 to 25.0 m/s)
  - `gravity` (1.0 to 50.0 m/s²)
  - `max_health` (10 to 500 HP)
- Signals:
  - `health_changed(new_health : Int32, max_health : Int32)`
  - `score_changed(new_score : Int32)`
  - `died`

### 2. `SpinningCrystal < Area3D`
- Exported properties:
  - `rotation_speed` (0.1 to 10.0 rad/s)
  - `bob_height` (0.05 to 1.5 meters)
  - `bob_frequency` (0.5 to 10.0 rad/s)
  - `score_value` (10 to 1000 points)
- Static crystal respawn manager: `SpinningCrystal.reset_all!`

### 3. `DemoHUD < Control`
- Binds to Godot's UI nodes and demonstrates Crystal `Range` cohesion with Godot's `Range` control:
  ```crystal
  godot_range = (0..100).to_godot_range(step: 1.0)
  ```
- Continuously updates health bar display during `_process`.

### 4. Custom GDScript Interoperability
- Custom GDScript nodes can be automatically bound at compile time via `make project_bindings`:
  ```crystal
  # Auto-generated typed wrapper from CompanionController.gd:
  companion = Godot::CompanionController.from(node)
  bonus = companion.calculate_bonus(100_i64)
  companion.bonus_multiplier = 1.5_f64
  ```

---

## Running the Demo

From the repository root:

```bash
# Launch game directly
make run

# Open in Godot Editor
make editor
```

Or from within the `demo/` folder:

```bash
cd demo
make run
```
