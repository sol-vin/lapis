---
name: lapis-addon
description: >-
  Manage, scaffold, install, audit, and package redistributable Godot GDExtension addons using the Lapis CLI.
  Use when installing community addons, creating new addons, managing addon dependencies, or packaging addons for distribution.
---

# Lapis Addon Management & Distribution Runbook

This skill outlines how to manage the full lifecycle of Godot GDExtension addons written in Crystal, from scaffolding and development to git-based installation, `project.godot` registration, and release packaging.

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
      <td><a href="#1-quick-command-reference"><strong>1. Quick Command Reference</strong></a></td>
      <td># Scaffold a new addon project</td>
      <td align="center"><code>L54–L80</code></td>
    </tr>
    <tr>
      <td><a href="#2-scaffolding-a-new-addon"><strong>2. Scaffolding a New Addon</strong></a></td>
      <td>To create a new redistributable addon:</td>
      <td align="center"><code>L81–L139</code></td>
    </tr>
    <tr>
      <td><a href="#3-installing-addons-into-a-game"><strong>3. Installing Addons into a Game</strong></a></td>
      <td>When you run lapis addon install <source>, Lapis performs an atomic, multi-step installation:</td>
      <td align="center"><code>L140–L161</code></td>
    </tr>
    <tr>
      <td><a href="#4-multi-addon-isolation-classdb-rules"><strong>4. Multi-Addon Isolation & ClassDB Rules</strong></a></td>
      <td>To prevent ClassDB naming collisions and ensure clean coexistence:</td>
      <td align="center"><code>L162–L170</code></td>
    </tr>
    <tr>
      <td><a href="#5-packaging-addons-for-distribution"><strong>5. Packaging Addons for Distribution</strong></a></td>
      <td>When distributing your addon to the Godot Asset Library or GitHub Releases:</td>
      <td align="center"><code>L171–L189</code></td>
    </tr>
  </tbody>
</table>

---

## 1. Quick Command Reference

```bash
# Scaffold a new addon project
lapis scaffold addon <name> [--dir=<path>] [--author="<name>"] [--desc="<desc>"]
# Or shorthand:
lapis new addon <name>

# Install an addon from Git or local directory
lapis addon install https://github.com/user/my_addon.git [--branch=<branch>] [--vendor]
lapis addon install ./local_path_to_addon

# List installed addons and their status
lapis addon list

# Update installed addons to latest versions
lapis addon update [name]

# Remove and uninstall an addon
lapis addon remove <name>

# Package an addon for redistribution (creates zip with binaries & gdextension manifest)
lapis package addon [--release] [--output=<dir>]
```

---

## 2. Scaffolding a New Addon

To create a new redistributable addon:
```bash
lapis scaffold addon combat_system --author="Studio Name" --desc="Tactical combat framework"
```

This generates an isolated, self-contained project structure:
```
combat_system/
├── addons/combat_system/
│   ├── bin/                      # Compiled addon DLLs/SOs
│   ├── icons/                    # Custom node icons
│   ├── plugin.cfg                # Godot editor plugin metadata
│   ├── combat_system.gdextension # GDExtension manifest
│   └── combat_system_plugin.gd   # Editor plugin script
├── src/
│   └── main.cr                   # Crystal node definitions and registration
├── shard.yml                     # Crystal dependencies
├── Makefile                      # Addon build recipes
└── project.godot                 # Test project harness for live in-editor testing
```

### 2.1. Plugin Configuration (`plugin.cfg`)
```ini
[plugin]

name="CombatSystem"
description="Tactical turn-based combat framework for Lapis"
author="Studio Name"
version="1.0.0"
script="combat_system_plugin.gd"
```

### 2.2. GDExtension Manifest (`combat_system.gdextension`)
```ini
[configuration]

entry_symbol="combat_system_init"
compatibility_minimum="4.1"

[libraries]

windows.debug.x86_64="bin/combat_system.dll"
windows.release.x86_64="bin/combat_system.dll"
linux.debug.x86_64="bin/libcombat_system.so"
linux.release.x86_64="bin/libcombat_system.so"
macos.debug="bin/libcombat_system.dylib"
macos.release="bin/libcombat_system.dylib"

[dependencies]

windows.debug.x86_64={
    "bin/gc.dll": ""
}
```

---

## 3. Installing Addons into a Game

When you run `lapis addon install <source>`, Lapis performs an atomic, multi-step installation:
1. **Clone or Copy**: Clones the Git repository into a temporary workspace (or reads local folder).
2. **Security Audit**: Audits the addon for malicious file patterns, suspicious shell scripts, or symlink traversal.
3. **Staging**: Copies the redistributable folder into your project's `addons/<addon_name>/`.
4. **Dependency Sync**: If the addon requires Crystal shards, Lapis tracks the shard dependency in your project's `shard.yml` under `dependencies:` or `addons:`.
5. **Project Registration**: Automatically enables the plugin in your `project.godot` under `editor_plugins/enabled`.

### Installing from Git:
```bash
lapis addon install https://github.com/sol-vin/lapis_dialogue.git --branch=v1.2
```

### Vendoring Addon Shards:
If you want to freeze the Crystal source code inside your project repository without external Git submodule dependencies:
```bash
lapis addon install https://github.com/sol-vin/lapis_inventory.git --vendor
```

---

## 4. Multi-Addon Isolation & ClassDB Rules

To prevent ClassDB naming collisions and ensure clean coexistence:
1. **Never Share Class Names Across Addons**: Always prefix custom nodes with an addon namespace (e.g. `CombatPlayer`, `CombatWeapon` instead of generic `Player`).
2. **Distinct GDExtension Entry Points**: Each addon must specify its own unique entry symbol in its `.gdextension` manifest (e.g. `combat_system_init`).
3. **Dummy Addons in Core Workspace**: Test addons in the main Lapis repository (`dummy_audio`, `dummy_dialogue`, `dummy_inventory`, `test_runner`) exist solely to verify ClassDB isolation in test suites. They are NEVER bundled into shipped releases.

---

## 5. Packaging Addons for Distribution

When distributing your addon to the Godot Asset Library or GitHub Releases:
```bash
# Package optimized release archive
lapis package addon --release
```

This command:
1. Compiles the addon in `--release` mode.
2. Packages only the required redistributable files:
   - `addons/<name>/bin/*` (dynamic libraries)
   - `addons/<name>/*.gdextension`
   - `addons/<name>/plugin.cfg`
   - `addons/<name>/**/*.gd`
   - `addons/<name>/icons/*`
3. Strips source code (`src/`), test scenes, and local config files.
4. Produces a ready-to-extract `.zip` archive formatted for direct extraction into any Godot project's root folder.
