# LibGodot Crystal Starter Template

This directory provides a clean, minimal starter skeleton for creating new Godot games powered by Crystal and LibGodot.

---

## Directory Structure

```
template/
├── .github/
│   └── workflows/
│       ├── ci.yml          # Automated CI: Crystal specs + build on push/PR
│       └── release.yml     # Automated releases: multi-platform build & tag release
├── project.godot           # Godot project configuration
├── scenes/                 # Game scene files (main.tscn)
├── spec/
│   ├── main_spec.cr        # Offline Crystal unit specifications
│   └── editor/
│       └── editor_spec.cr  # Live in-editor tests (Lapis::Test / Crystal Hub)
├── src/
│   ├── main.cr             # Game entry point and custom nodes
│   └── my_node.cr          # Sample custom node definition
├── Makefile                # Cross-platform build configuration (Windows & Linux)
```

---

## Getting Started

### 1. Copy or Scaffold the Template
Create your new project via Lapis or copy the `template/` directory:

```bash
lapis new game my_game
cd my_game
```

### 2. Define Your Nodes
Edit `src/main.cr` to define your custom Godot nodes:

```crystal
require "lapis"
require "./**"

{% unless flag?(:release) %}
  require "../spec/editor/**"
{% end %}

# Root node for your game scene
node MainNode < Node3D do
  @[ExportMultiline]
  property say_text : String = "Hello from Crystal in Godot!"

  # Emitted when initialization completes
  signal initialized

  def _ready : Void
    Godot.print("Game initialized successfully!")
    emit_initialized
  end
end
```

### 3. Running Tests

#### A. In-Editor Test Runner (Godot Editor)
Launch the editor:
```bash
make editor
```
1. Click the **Crystal** tab in the main screen bar at the top of the editor.
2. Under the **Unit Test Runner** dock tab, you will see both **Crystal Specifications** (`spec/main_spec.cr`, `spec/editor/editor_spec.cr`) and **In-Editor Test Suites** (`Lapis::Test`).
3. Click **▶ Run In-Editor Tests** to execute live engine tests without leaving the editor workspace!
4. Click **▶ Run All Specs** to run all specifications in the background with formatted pass/fail badges.

#### B. Offline CLI Specifications
Run Crystal specs directly from the terminal without launching Godot:

```bash
make test       # or: crystal spec
```

### 4. Build & Run
Run with Make:

```bash
make          # Build game library (game.dll on Windows, game.so on Linux)
make run      # Launch game with Godot
make editor   # Open in Godot Editor
```

---

## Automated CI/CD (GitHub Actions)

The template comes pre-configured with out-of-the-box GitHub Actions in `.github/workflows/`:
- **`ci.yml`**: Runs `crystal spec`, builds the game, and runs a headless Godot smoke test on every push and pull request.
- **`release.yml`**: Automatically packages Windows and Linux game release archives and publishes a GitHub Release when you push a version tag (e.g. `git tag v1.0.0 && git push --tags`).
