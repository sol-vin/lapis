---
name: lapis-upgrade
description: Upgrade Godot engine binaries, Cradare2 / Radare2 debugger toolchain, Opal terminal toolkit, and Lapis framework. Use when executing /upgrade commands or upgrading dependencies.
---

# Lapis Toolchain & Dependency Upgrade Manual

This operational skill governs the automated and manual procedures for executing `/upgrade` commands and upgrading core components of the Lapis ecosystem: the Godot Engine binary, Radare2 / Cradare2 native debugging toolchain, Opal terminal UI library, and Lapis itself.

---

## 1. Upgrade Command Matrix

<table>
  <thead>
    <tr>
      <th align="left">Command / Target</th>
      <th align="left">Primary Action</th>
      <th align="left">Target Path / Component</th>
      <th align="left">Verification Check</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>/upgrade godot</code></td>
      <td>Fetch latest Godot 4.x binary, dump API, update manifests</td>
      <td><code>bin/godot.exe</code> or system PATH</td>
      <td><code>lapis doctor</code> &amp; <code>bin/godot.exe --version</code></td>
    </tr>
    <tr>
      <td><code>/upgrade cradare2</code></td>
      <td>Update cradare2 bindings and radare2 debugger symbols</td>
      <td><code>lib/cradare2/</code> &amp; radare2 toolchain</td>
      <td><code>lapis decompile bin/game.dll Node2D</code></td>
    </tr>
    <tr>
      <td><code>/upgrade opal</code></td>
      <td>Pull &amp; verify Opal TUI framework from local repo or git</td>
      <td><code>C:/Users/Ian/Documents/Github/opal</code></td>
      <td><code>crystal spec</code> &amp; zero-dependency audit</td>
    </tr>
    <tr>
      <td><code>/upgrade lapis</code></td>
      <td>Pull upstream framework, recompile CLI, rebuild toolchain</td>
      <td>Workspace root &amp; <code>bin/lapis.exe</code></td>
      <td><code>make all</code> &amp; <code>lapis test --no-tui</code></td>
    </tr>
  </tbody>
</table>

---

## 2. `/upgrade godot` Procedure

When upgrading the Godot engine binary or when requested via `/upgrade godot`:

### Step-by-Step Workflow:
1. **Identify Target Godot Version**:
   - Determine target version (e.g. Godot `4.3-stable` or `4.4-stable`).
2. **Download or Relocate Godot Binary**:
   - Automated via `make setup-dev GODOT_VERSION=<version>`:
     ```powershell
     make setup-dev GODOT_VERSION=4.3-stable
     ```
   - Or manually copy Godot binary into `bin/godot.exe`.
3. **Verify Version String**:
   ```powershell
   bin/godot.exe --version
   ```
4. **Dump GDExtension Extension API**:
   - When the engine version changes, dump the new `extension_api.json`:
     ```powershell
     bin/godot.exe --headless --dump-extension-api
     ```
   - This creates `extension_api.json` in the workspace root.
5. **Regenerate Crystal Bindings (if major/minor API bump)**:
   - Use `libgodot-api-generator` skill:
     ```powershell
     bin/lapis generate-api extension_api.json
     ```
6. **Rebuild &amp; Verify Toolchain**:
   - Run the Golden Build Rule:
     ```powershell
     make all
     ```
7. **Run Diagnostic Doctor**:
   ```powershell
   bin/lapis doctor
   ```

---

## 3. `/upgrade cradare2` Procedure

When upgrading the Cradare2 Crystal shard or native Radare2 debugger:

### Step-by-Step Workflow:
1. **Verify Native Radare2 Installation**:
   - Check native radare2 version in PATH:
     ```powershell
     radare2 -v
     ```
   - Ensure `r2`, `rasm2`, and `rabin2` are responsive and version is 5.8+.
2. **Update Cradare2 Shard**:
   - In `shard.yml`:
     ```yaml
     dependencies:
       cradare2:
         github: sol-vin/cradare2
         branch: master
     ```
   - Run `shards update cradare2`.
3. **Audit Native C API Symbols**:
   - Ensure the required RCore symbols (`r_core_new`, `r_core_free`, `r_core_cmd_str`, `r_core_file_open`) link cleanly against `libr_core.dll` or static radare2.
4. **Test Disassembly and Decompilation**:
   - Build test game binary:
     ```powershell
     make all
     ```
   - Test disassembly output:
     ```powershell
     bin/lapis decompile bin/game.dll "crystal_bridge_init"
     ```
   - Test side-by-side Ghidra decompiler (`pdc`) and disassembly (`pdf`):
     ```powershell
     bin/lapis decompile bin/game.dll "crystal_bridge_init" --side-by-side
     ```
5. **Verify In-Editor Debugger Plugins**:
   - Run the headless editor test to verify `addons/crystal_integration/crystal_integration.gd` and r2 bridge tabs load without syntax errors:
     ```powershell
     bin/godot.exe --headless --editor --path . --quit-after 50
     ```

---

## 4. `/upgrade opal` Procedure

The Opal terminal toolkit (`Documents/Github/opal`) powers the interactive Lapis TUI dashboard, test runner, benchmark visualizer, and docs reader.

### Architectural Invariant: Zero External Dependencies
Opal must remain a standalone, ultra-lean terminal framework with **zero external dependencies** and **zero Godot/LibGodot imports**.

### Step-by-Step Workflow:
1. **Navigate to Opal Workspace**:
   - Work directory: `C:\Users\Ian\Documents\Github\opal`.
2. **Pull Upstream or Switch Branch**:
   ```powershell
   git -C "C:\Users\Ian\Documents\Github\opal" status
   git -C "C:\Users\Ian\Documents\Github\opal" pull origin main
   ```
3. **Execute Opal Standalone Specs**:
   ```powershell
   cd "C:\Users\Ian\Documents\Github\opal"
   crystal spec
   ```
   All specs in Opal must pass with 0 failures and 0 errors.
4. **Audit Dependencies**:
   - Verify `shard.yml` in `Documents/Github/opal` contains NO external dependencies.
5. **Update Consumer Reference**:
   - If Lapis references Opal via local path:
     ```yaml
     dependencies:
       opal:
         path: C:/Users/Ian/Documents/Github/opal
     ```
   - If referencing via git:
     ```powershell
     shards update opal
     ```
6. **Recompile Lapis CLI**:
   ```powershell
   crystal build tools/lapis/src/lapis.cr -o bin/lapis.exe
   ```
7. **Verify Terminal User Interfaces**:
   - Test runner ANSI double-buffer dashboard:
     ```powershell
     bin/lapis test --no-tui
     ```
   - Test benchmark visualizer:
     ```powershell
     bin/lapis bench --dry-run
     ```
   - Test docs TUI viewer:
     ```powershell
     bin/lapis docs lookup guide "gdscript"
     ```

---

## 5. `/upgrade lapis` Procedure

When upgrading the core Lapis engine framework and toolchain:

### Step-by-Step Workflow:
1. **Check Git Status &amp; Fetch Upstream**:
   ```powershell
   git status
   git fetch origin
   git merge origin/main
   ```
2. **Re-resolve Shards**:
   ```powershell
   shards update
   ```
3. **Recompile Lapis CLI Toolchain**:
   ```powershell
   crystal build tools/lapis/src/lapis.cr -o bin/lapis.exe
   ```
4. **Execute CLI Spec Suite**:
   ```powershell
   crystal spec tools/lapis/spec
   ```
5. **Execute Full Golden Build (`make all`)**:
   ```powershell
   make all
   ```
   Remember: Monitor background execution every 30 seconds until completed with exit code 0.
6. **Run Full Specification Suite**:
   ```powershell
   bin/lapis test --no-tui
   ```
7. **Run In-Editor Headless Driver**:
   ```powershell
   crystal spec spec/editor_driver_spec.cr
   ```
8. **Verify System Health**:
   ```powershell
   bin/lapis doctor
   ```

---

## 6. Post-Upgrade Verification Checklist

After running any upgrade procedure, ensure the following checklist is completed:

<table>
  <thead>
    <tr>
      <th align="left">Check</th>
      <th align="left">Command</th>
      <th align="left">Expected Result</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Diagnostic Health</td>
      <td><code>bin/lapis doctor</code></td>
      <td>All green checkmarks (Crystal, Make, Godot, Radare2)</td>
    </tr>
    <tr>
      <td>CLI Specs</td>
      <td><code>crystal spec tools/lapis/spec</code></td>
      <td>0 failures, 0 errors</td>
    </tr>
    <tr>
      <td>Core Specs</td>
      <td><code>crystal spec spec/core_spec.cr</code></td>
      <td>0 failures, 0 errors</td>
    </tr>
    <tr>
      <td>Golden Build</td>
      <td><code>make all</code></td>
      <td>Exit code 0, all DLLs synchronized</td>
    </tr>
    <tr>
      <td>Documentation</td>
      <td><code>bin/lapis docs lookup guide &quot;gdscript&quot;</code></td>
      <td>Resolves and renders without crash</td>
    </tr>
  </tbody>
</table>
