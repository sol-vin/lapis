---
name: lapis-project-workflow
description: >-
  Manage the complete game project lifecycle using Lapis CLI: init, scaffolding, shard management, workspace cleaning, and synchronization.
  Use when initializing new projects, creating template scenes, updating shards, cleaning build artifacts, or syncing multi-target directories.
---

# Lapis Project Lifecycle & Workspace Management Runbook

This skill outlines how to use the Lapis CLI to manage projects from initial creation through daily maintenance, dependency management, and multi-target directory synchronization.

---

## 1. Project Initialization (`lapis init`)

Initialize a brand-new Lapis game in a fresh or existing folder:
```bash
# Initialize with custom name and directory
lapis init --name "SpaceShooter" --path ./games/space_shooter

# Or initialize inside the current directory
lapis init --name "SpaceShooter"
```

### Initialized Directory Structure:
```
space_shooter/
├── project.godot                 # Godot project configuration
├── shard.yml                     # Crystal dependencies and metadata
├── scenes/
│   └── main.tscn                 # Default entry scene
├── src/
│   └── main.cr                   # Game entry point and custom nodes
├── addons/
│   └── crystal_integration/      # GDExtension bridge and editor plugin
└── bin/                          # Output binaries and runtime libraries
```

---

## 2. Scaffolding Showcase Examples & Addons (`lapis scaffold` / `lapis new`)

```bash
# Scaffold a new standalone game template
lapis scaffold game "DungeonCrawler" --dir=examples/dungeon_crawler

# Scaffold a new showcase demo
lapis scaffold example "PhysicsShowcase" --dir=examples/physics_showcase

# Scaffold a new redistributable Godot addon
lapis scaffold addon "InventorySystem" --author="Studio" --desc="Grid-based inventory"
```

---

## 3. Shard & Dependency Management (`lapis shard`)

Lapis wraps Crystal's `shards` tool with Godot-specific intelligence:

```bash
# Install all shards listed in shard.yml
lapis shard install

# Update shards to latest compatible versions
lapis shard update

# Prune unused or orphaned shard directories
lapis shard prune

# Verify shard.yml integrity and dependency tree
lapis shard check
```

When an addon is installed via `lapis addon install`, Lapis automatically updates `shard.yml` to track the required dependencies without breaking version constraints.

---

## 4. Workspace Cleaning & Disk Reclamation (`lapis clean`)

During iterative development, compiler caches, shadow DLLs, and temporary object files accumulate. `lapis clean` safely reclaims disk space:

```bash
# Clean project build artifacts (preserves runtime DLLs like libgodot.dll and gc.dll)
lapis clean

# Preview what would be deleted without removing files
lapis clean --dry-run

# Clean all build artifacts including cached shadow copies
lapis clean --shadows

# Deep clean across all examples, templates, and root bins
lapis clean --all
```

> [!IMPORTANT]
> `lapis clean` is safety-aware: it will **never** delete active shadow DLLs currently locked by running Godot instances, nor will it wipe necessary runtime dependencies.

---

## 5. Directory Synchronization (`lapis sync`)

In multi-project workspaces (such as the core Lapis repository, or projects with multiple example sub-games):

```bash
# Synchronize runtime DLLs, addons, and manifests across all targets
lapis sync

# Force overwrite all target binaries
lapis sync --force

# Verbose inspection of synchronization operations
lapis sync --verbose
```

`lapis sync` ensures that all consumers (`bin/`, `template/bin/`, `examples/*/bin/`) have identical, synchronized copies of:
- `crystal_bridge.dll` (or `.so`)
- `addons/crystal_integration/`
- Runtime libraries (`gc.dll`, `pcre2-8.dll`, `iconv-2.dll`, `libgodot.dll`)
