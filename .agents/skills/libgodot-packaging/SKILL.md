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
      <td><a href="#1-cardinal-rule-always-use-make-package-target-or-lapis-package"><strong>1. Cardinal Rule: Always Use `make <package-target>` or `lapis package`</strong></a></td>
      <td>NEVER manually locate compiler utilities (like iscc.exe), execute recursive filesystem searches, or craft a...</td>
      <td align="center"><code>L65–L72</code></td>
    </tr>
    <tr>
      <td><a href="#2-windows-installer-exe"><strong>2. Windows Installer (`.exe`)</strong></a></td>
      <td>To compile the Windows Inno Setup installer executable:</td>
      <td align="center"><code>L73–L105</code></td>
    </tr>
    <tr>
      <td><a href="#3-full-release-distribution-binreleasedist"><strong>3. Full Release Distribution (`bin/release_dist/`)</strong></a></td>
      <td>To package all release archives, installers, and SHA-256 checksums:</td>
      <td align="center"><code>L106–L139</code></td>
    </tr>
    <tr>
      <td><a href="#4-official-addon-packaging-crystalintegration"><strong>4. Official Addon Packaging (`crystal_integration`)</strong></a></td>
      <td>To package the official redistributable GDExtension addon into godot-crystal-addon.zip:</td>
      <td align="center"><code>L140–L152</code></td>
    </tr>
    <tr>
      <td><a href="#5-playable-standalone-game-packaging"><strong>5. Playable Standalone Game Packaging</strong></a></td>
      <td>To export a Godot + Crystal project as a standalone playable game directory (containing executable, PCK pac...</td>
      <td align="center"><code>L153–L192</code></td>
    </tr>
    <tr>
      <td><a href="#6-comprehensive-packaging-targets-reference"><strong>6. Comprehensive Packaging Targets Reference</strong></a></td>
      <td><table></td>
      <td align="center"><code>L193–L269</code></td>
    </tr>
    <tr>
      <td><a href="#7-cli-direct-invocation-alternative"><strong>7. CLI Direct Invocation Alternative</strong></a></td>
      <td>All make targets map directly to lapis package:</td>
      <td align="center"><code>L270–L280</code></td>
    </tr>
  </tbody>
</table>

---

## 1. Cardinal Rule: Always Use `make <package-target>` or `lapis package`

**NEVER manually locate compiler utilities (like `iscc.exe`), execute recursive filesystem searches, or craft ad-hoc packaging scripts.**

The build system (`Makefile`) and the Lapis toolchain (`tools/lapis/src/commands/package.cr`) handle all prerequisite discovery, staging directory management (`scratch/installer_stage`), binary collection, symbol stripping, and output synchronization automatically.

---

## 2. Windows Installer (`.exe`)

To compile the Windows Inno Setup installer executable:

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
make windows-installer VERSION=0.1.0

# Build with release optimization flags
make windows-installer RELEASE=1
```

### What `make windows-installer` does automatically:
1. Recompiles `bin/lapis.exe` if sources changed.
2. Stages `lapis.exe`, `crystalline.exe` (LSP server), and runtime DLLs (`gc.dll`, `pcre2-8.dll`, `iconv-2.dll`) into `scratch/installer_stage/`.
3. Discovers Inno Setup Compiler (`ISCC.exe`) via standard installation directories (`%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`, `C:\Program Files (x86)\Inno Setup 6\`, Scoop, Chocolatey, or PATH).
4. Compiles `packaging/windows/lapis_installer.iss` into `bin/windows/lapis-setup-windows-x86_64.exe`.
5. Synchronizes the generated installer into `bin/release_dist/`.

---

## 3. Full Release Distribution (`bin/release_dist/`)

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

### Generated Artifacts in `bin/release_dist/`:
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

## 4. Official Addon Packaging (`crystal_integration`)

To package the official redistributable GDExtension addon into `godot-crystal-addon.zip`:

```bash
make package-addon
```

### Safety Rule on Addon Isolation:
Only `addons/crystal_integration` is packaged. Dummy test addons (`dummy_audio`, `dummy_dialogue`, `dummy_inventory`, `test_runner`) are **strictly excluded** to prevent ClassDB collisions in consumer projects.

---

## 5. Playable Standalone Game Packaging

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

# Debug mode with portable radare2 bundled & automated crash dump generation
make package-game DEBUG=1

# Custom export destination directory
make package-game TARGET_DIR=dist/my_game
```

### Export Debug Packaging (Crash Diagnostics Harness):
When sharing experimental or test builds with friends or QA testers, unhandled crashes often yield no stack traces. Use `--debug`:
```bash
lapis package --debug
# or
make package-game DEBUG=1
```
This bundles:
- Game executable compiled with debug symbols (`-d`)
- Portable standalone `r2` toolchain in `bin/r2/`
- Supervisor scripts (`run_debug.bat` / `run_debug.sh`) that trap crashes (`0xC0000005` / `SIGSEGV`) and automatically bundle registers, backtraces, decompiled crash site (`pdc`), and instance ID forensics into `crash_reports/crash_report_<timestamp>.zip`.

---

## 6. Comprehensive Packaging Targets Reference

<table>
  <thead>
    <tr>
      <th align="left">Target</th>
      <th align="left">Command</th>
      <th align="left">Platform</th>
      <th align="left">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Windows Installer</strong></td>
      <td><code>make windows-installer</code></td>
      <td>Windows</td>
      <td>Compiles Inno Setup installer executable with PATH and file associations.</td>
    </tr>
    <tr>
      <td><strong>Debian Package</strong></td>
      <td><code>make package-deb</code></td>
      <td>Linux</td>
      <td>Generates <code>.deb</code> package with bash completion and man pages.</td>
    </tr>
    <tr>
      <td><strong>Official Addon</strong></td>
      <td><code>make package-addon</code></td>
      <td>All</td>
      <td>Packages <code>addons/crystal_integration</code> into clean redistributable zip.</td>
    </tr>
    <tr>
      <td><strong>Playable Game</strong></td>
      <td><code>make package-game</code></td>
      <td>All</td>
      <td>Packages game executable, PCK packfile, and runtime DLLs into shipping folder.</td>
    </tr>
    <tr>
      <td><strong>Lapis CLI Archive</strong></td>
      <td><code>make package-lapis</code></td>
      <td>All</td>
      <td>Packages standalone <code>lapis</code> binary, licenses, and docs into zip/tar.gz.</td>
    </tr>
    <tr>
      <td><strong>Starter Template</strong></td>
      <td><code>make package-template</code></td>
      <td>All</td>
      <td>Packages clean <code>template/</code> starter game project.</td>
    </tr>
    <tr>
      <td><strong>Addon Template</strong></td>
      <td><code>make package-template-addon</code></td>
      <td>All</td>
      <td>Packages clean <code>template-addon/</code> starter plugin project.</td>
    </tr>
    <tr>
      <td><strong>Showcase Examples</strong></td>
      <td><code>make package-examples</code></td>
      <td>All</td>
      <td>Packages all showcase projects in <code>examples/</code>.</td>
    </tr>
    <tr>
      <td><strong>Benchmarks Suite</strong></td>
      <td><code>make package-benchmarks</code></td>
      <td>All</td>
      <td>Packages <code>benchmarks/</code> suite with runner and datasets.</td>
    </tr>
    <tr>
      <td><strong>Full Release</strong></td>
      <td><code>make package-release</code></td>
      <td>All</td>
      <td>Builds all packaging targets and computes SHA-256 checksums.</td>
    </tr>
  </tbody>
</table>

---

## 7. CLI Direct Invocation Alternative

All make targets map directly to `lapis package`:
```bash
bin/lapis package windows-installer [-t <dir>] [-o <name>] [-v <version>] [-r]
bin/lapis package release [--skip-tests] [--skip-benchmarks]
bin/lapis package addon [--platform <plat>] [-o <zip>]
bin/lapis package game [-p <project_path>] [-n <name>] [-r]
bin/lapis package deb [-t <dir>] [-v <version>]
```
