---
name: libgodot-packaging
description: >-
  Packaging, installers, and release distribution for Lapis and Godot games/addons.
  Use when building the Windows installer, official addon archive, playable standalone games,
  Debian package, benchmarks archive, or complete release distributions.
---

# LibGodot & Lapis Packaging Runbook

This skill outlines how to build installers, redistributable archives, standalone game packages, and release distributions using the project's build system and Lapis CLI.

---

## Cardinal Rule: Always Use `make <package-target>` or `lapis package`

**NEVER manually locate compiler utilities (like `iscc.exe`), execute recursive filesystem searches, or craft ad-hoc packaging scripts.**

The build system (`Makefile`) and the Lapis toolchain (`tools/lapis/src/commands/package.cr`) handle all prerequisite discovery, staging directory management (`scratch/installer_stage`), binary collection, symbol stripping, and output synchronization automatically.

---

## 1. Windows Installer (`.exe`)

To remake or compile the Windows Inno Setup installer executable:

```bash
make windows-installer
```
*(Aliases: `make package-installer`, `make installer`, `make windows_installer`)*

### Optional Parameters:
```bash
# Custom output directory
make windows-installer TARGET_DIR=dist/

# Custom output executable name
make windows-installer OUTPUT=my-custom-setup.exe

# Specific version string (defaults to Lapis::VERSION from shard.yml)
make windows-installer VERSION=0.0.46

# Build with release optimization flags
make windows-installer RELEASE=1
```

### What `make windows-installer` does automatically:
1. Recompiles `bin/lapis.exe` if sources changed.
2. Stages `lapis.exe`, `crystalline.exe` (LSP server), and runtime DLLs (`gc.dll`, `pcre2-8.dll`, `iconv-2.dll`).
3. Discovers Inno Setup Compiler (`ISCC.exe`) via standard installation directories (`%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`, `C:\Program Files (x86)\Inno Setup 6\`, Scoop, Chocolatey, or PATH).
4. Compiles [`packaging/windows/lapis_installer.iss`](file:///c:/Users/Ian/Documents/libgodot/packaging/windows/lapis_installer.iss) into [`bin/windows/lapis-setup-windows-x86_64.exe`](file:///c:/Users/Ian/Documents/libgodot/bin/windows/lapis-setup-windows-x86_64.exe).
5. Synchronizes the generated installer into [`bin/release_dist/`](file:///c:/Users/Ian/Documents/libgodot/bin/release_dist/).

---

## 2. Full Release Distribution (`bin/release_dist/`)

To package all release archives, installers, and SHA-256 checksums:

```bash
make package-release
```
*(Alias: `make package-all`)*

### Optional Flags:
```bash
# Skip tests during packaging
make package-release SKIP_TESTS=1

# Skip performance/benchmark suites during packaging
make package-release SKIP_PERF=1 SKIP_BENCHMARKS=1

# Custom output destination
make package-release OUTPUT_DIR=artifacts/release
```

Produces:
- `godot-crystal-addon.zip` (Official redistributable addon)
- `lapis-<platform>-x86_64.zip` (Standalone CLI toolchain)
- `lapis-setup-windows-x86_64.exe` (Windows installer, on Windows)
- `lapis_<version>_amd64.deb` (Debian package, on Linux)
- `template-project.zip` (Starter game project)
- `template-addon-project.zip` (Addon starter project)
- `examples-<platform>.zip` (Bundled showcase examples)
- `benchmarks-<platform>.zip` (Crystal vs GDScript benchmark suite)
- `SHA256SUMS.txt` (Cryptographic verification checksums)

---

## 3. Official Addon Packaging (`crystal_integration`)

To package the official redistributable GDExtension addon into `godot-crystal-addon.zip`:

```bash
make package-addon
```

### Safety Rule on Addon Isolation:
Only `addons/crystal_integration` is packaged. Dummy test addons (`dummy_audio`, `dummy_dialogue`, `dummy_inventory`, `test_runner`) are **strictly excluded** to prevent ClassDB collisions in consumer projects.

---

## 4. Playable Standalone Game Packaging

To export a Godot + Crystal project as a standalone playable game directory (containing executable, PCK packfile, and required runtime DLLs):

```bash
make package-game
```

### Custom Game Parameters:
```bash
# Target a specific project path (defaults to root project)
make package-game PROJECT=examples/basic_demo

# Custom game name
make package-game NAME=MyGame

# Release mode (optimizations enabled)
make package-game RELEASE=1

# Custom export destination directory
make package-game TARGET_DIR=dist/my_game
```

---

## 5. Other Packaging Targets

| Target | Command | Platform | Description |
| :--- | :--- | :--- | :--- |
| **Debian Package** | `make package-deb` | Linux | Generates `.deb` package with systemd/man integrations. |
| **Lapis CLI Archive** | `make package-lapis` | All | Packages standalone `lapis` binary and licenses into zip/tar.gz. |
| **Starter Template** | `make package-template` | All | Packages clean `template/` starter project (supports `BUNDLE=1`). |
| **Addon Template** | `make package-template-addon` | All | Packages `template-addon/` starter project (supports `BUNDLE=1`). |
| **Showcase Examples** | `make package-examples` | All | Packages all showcase projects in `examples/`. |
| **Benchmarks Suite** | `make package-benchmarks` | All | Packages `benchmarks/` suite with runner and datasets. |

---

## 6. CLI Direct Invocation Alternative

All make targets map directly to `lapis package`:
```bash
bin/lapis package windows-installer [-t <dir>] [-o <name>] [-v <version>] [-r]
bin/lapis package release [--skip-tests] [--skip-benchmarks]
bin/lapis package addon [--platform <plat>] [-o <zip>]
bin/lapis package game [-p <project_path>] [-n <name>] [-r]
bin/lapis package deb [-t <dir>] [-v <version>]
```
