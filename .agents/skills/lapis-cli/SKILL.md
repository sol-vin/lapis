---
name: lapis-cli
description: Master operational runbook and cheatsheet for the Lapis CLI toolchain. Use when running lapis commands, configuring flags and environment variables, troubleshooting CLI execution, or building, testing, and packaging Godot Crystal games.
---

# Lapis CLI Master Operational Runbook

The `lapis` executable is the single, unified native CLI toolchain for developing, testing, debugging, profiling, and packaging Godot games written in Crystal.

---

## 1. Quick Reference: Command Matrix

<table>
  <thead>
    <tr>
      <th align="left">Command</th>
      <th align="left">Shorthand / Subcommand</th>
      <th align="left">Primary Purpose</th>
      <th align="left">Common Flags &amp; Options</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>build</code></td>
      <td><code>lapis build [entry]</code></td>
      <td>Compiles Crystal game libraries or plugins</td>
      <td><code>--release</code>, <code>--strip-docs</code>, <code>--leak-tracker</code>, <code>--no-thread-safety</code></td>
    </tr>
    <tr>
      <td><code>test</code></td>
      <td><code>lapis test [suite]</code></td>
      <td>Executes unified multi-phase test suite</td>
      <td><code>--tui</code>, <code>--no-tui</code>, <code>--suite=&lt;name&gt;</code>, <code>--headless</code>, <code>--filter=&lt;str&gt;</code></td>
    </tr>
    <tr>
      <td><code>bench</code></td>
      <td><code>lapis bench / benchmarks</code></td>
      <td>Runs Crystal vs GDScript performance benchmarks</td>
      <td><code>--tui</code>, <code>--runs=N</code>, <code>--export-html</code>, <code>--compare</code>, <code>--analyze</code></td>
    </tr>
    <tr>
      <td><code>docs</code></td>
      <td><code>lapis docs [action]</code></td>
      <td>Compiles docs or queries documentation database</td>
      <td><code>lookup gd &lt;symbol&gt;</code>, <code>lookup crystal &lt;query&gt;</code>, <code>lookup guide &lt;slug&gt;</code>, <code>--serve</code></td>
    </tr>
    <tr>
      <td><code>template</code></td>
      <td><code>lapis template &lt;subcommand&gt;</code></td>
      <td>Modular template store and TUI manager</td>
      <td><code>save</code>, <code>list</code>, <code>info</code>, <code>clean</code>, <code>export</code>, <code>import</code>, <code>manager</code></td>
    </tr>
    <tr>
      <td><code>new</code></td>
      <td><code>lapis new [name]</code></td>
      <td>Scaffolds a new project or squirrel-aways template</td>
      <td><code>--template &lt;name&gt;</code>, <code>template &lt;name&gt;</code>, interactive wizard</td>
    </tr>
    <tr>
      <td><code>decompile</code></td>
      <td><code>lapis decompile &lt;bin&gt; &lt;sym&gt;</code></td>
      <td>Radare2 / Ghidra disassembly &amp; pseudo-C decompiler</td>
      <td><code>--side-by-side</code>, <code>--offset=&lt;addr&gt;</code></td>
    </tr>
    <tr>
      <td><code>run</code></td>
      <td><code>lapis run</code></td>
      <td>Launches the game in Godot</td>
      <td><code>--release</code>, <code>--scene=&lt;path&gt;</code>, <code>-d</code> (debug)</td>
    </tr>
    <tr>
      <td><code>editor</code></td>
      <td><code>lapis editor</code></td>
      <td>Opens the project in the Godot Editor</td>
      <td><code>--path=&lt;dir&gt;</code>, <code>-d</code> (debug), <code>--quit=&lt;sec&gt;</code></td>
    </tr>
    <tr>
      <td><code>doctor</code></td>
      <td><code>lapis doctor</code></td>
      <td>Diagnoses developer environment and toolchains</td>
      <td><code>--verbose</code>, <code>--fix</code></td>
    </tr>
    <tr>
      <td><code>upgrade</code></td>
      <td><code>lapis upgrade &lt;target&gt;</code></td>
      <td>Upgrades Godot, Cradare2, Opal, or Lapis</td>
      <td><code>godot</code>, <code>cradare2</code>, <code>opal</code>, <code>lapis</code></td>
    </tr>
    <tr>
      <td><code>addon</code></td>
      <td><code>lapis addon</code></td>
      <td>Installs, lists, updates, or audits GDExtension addons</td>
      <td><code>install &lt;url/path&gt;</code>, <code>remove &lt;name&gt;</code>, <code>list</code>, <code>audit</code></td>
    </tr>
    <tr>
      <td><code>shard</code></td>
      <td><code>lapis shard</code></td>
      <td>Manages Crystal shard dependencies</td>
      <td><code>install</code>, <code>update</code>, <code>prune</code>, <code>check</code></td>
    </tr>
    <tr>
      <td><code>clean</code></td>
      <td><code>lapis clean</code></td>
      <td>Reclaims disk space and purges build artifacts</td>
      <td><code>--all</code>, <code>--shadows</code>, <code>--dry-run</code></td>
    </tr>
    <tr>
      <td><code>sync</code></td>
      <td><code>lapis sync</code></td>
      <td>Synchronizes DLLs, addons, and manifests</td>
      <td><code>--force</code>, <code>--verbose</code></td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td><code>lapis deps</code></td>
      <td>Verifies and stages runtime DLLs (<code>gc.dll</code>, <code>libgodot.dll</code>)</td>
      <td><code>--check-only</code>, <code>--target=&lt;dir&gt;</code></td>
    </tr>
    <tr>
      <td><code>ide</code></td>
      <td><code>lapis ide</code></td>
      <td>Generates VS Code, Zed, or Cursor configurations</td>
      <td><code>--vscode</code>, <code>--zed</code>, <code>--all</code></td>
    </tr>
    <tr>
      <td><code>package</code></td>
      <td><code>lapis package</code></td>
      <td>Packages games, addons, or release installers</td>
      <td><code>game</code>, <code>addon</code>, <code>windows-installer</code>, <code>deb</code>, <code>release</code></td>
    </tr>
    <tr>
      <td><code>log</code></td>
      <td><code>lapis log</code></td>
      <td>Streams, filters, and formats game and editor logs</td>
      <td><code>--level=INFO</code>, <code>--filter=TAG</code>, <code>--tail</code></td>
    </tr>
  </tbody>
</table>

---

## 2. Global Command-Line Flags

These flags can be supplied to any `lapis` subcommand:

- **`-v`, `--version`**: Displays the Lapis toolchain version, git revision, and target Godot engine version.
- **`-h`, `--help`**: Displays context-sensitive help, usage syntax, and available options for the command.
- **`--verbose`**: Outputs detailed process command lines, compiler invocations, environment variables, and timing metrics.
- **`-q`, `--quiet`**: Suppresses informational banners and outputs only warnings and errors. Ideal for automated CI pipelines.

---

## 3. Environment Variables Reference

<table>
  <thead>
    <tr>
      <th align="left">Variable</th>
      <th align="left">Values</th>
      <th align="left">Effect</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>GODOT_BIN</code></td>
      <td>Absolute path</td>
      <td>Overrides the Godot engine binary path</td>
    </tr>
    <tr>
      <td><code>CRYSTAL_BIN</code></td>
      <td>Absolute path</td>
      <td>Overrides the Crystal compiler path</td>
    </tr>
    <tr>
      <td><code>RELEASE</code></td>
      <td><code>1</code>, <code>true</code></td>
      <td>Compiles with <code>--release -O3</code> optimizations across all build steps</td>
    </tr>
    <tr>
      <td><code>STRIP_DOCS</code></td>
      <td><code>1</code>, <code>true</code></td>
      <td>Strips doc comments and EditorHelp XML strings (<code>-Dno_doc</code>)</td>
    </tr>
    <tr>
      <td><code>NO_THREAD_SAFETY</code></td>
      <td><code>1</code>, <code>true</code></td>
      <td>Eliminates runtime main-thread checks for high-performance dispatch</td>
    </tr>
    <tr>
      <td><code>LEAK_TRACKER</code></td>
      <td><code>1</code>, <code>true</code></td>
      <td>Enables object allocation and lifecycle tracking (<code>-Dleak_tracker</code>)</td>
    </tr>
    <tr>
      <td><code>TRACE_SIGNALS</code></td>
      <td><code>1</code>, <code>true</code></td>
      <td>Logs all signal emissions across the scene tree (<code>-Dtrace_signals</code>)</td>
    </tr>
    <tr>
      <td><code>PROFILE_DISPATCHES</code></td>
      <td><code>1</code>, <code>true</code></td>
      <td>Measures nanosecond virtual method dispatch latency (<code>-Dprofile_dispatches</code>)</td>
    </tr>
    <tr>
      <td><code>TRACE_DEAD_POINTERS</code></td>
      <td><code>1</code>, <code>true</code></td>
      <td>Maintains deallocation callstacks for <code>DisposedObjectError</code> diagnostics</td>
    </tr>
    <tr>
      <td><code>NO_TESTING</code></td>
      <td><code>1</code>, <code>true</code></td>
      <td>Excludes test runner and benchmark apparatus from output binaries</td>
    </tr>
    <tr>
      <td><code>NO_CRASH_HANDLER</code></td>
      <td><code>1</code>, <code>true</code></td>
      <td>Disables Windows VEH crash handler for clean radare2 execution</td>
    </tr>
  </tbody>
</table>

---

## 4. Key Workflows &amp; Specialized Subcommands

### 4.1. Documentation Search (`lapis docs lookup`)
Query Godot engine APIs, Crystal standard library / bindings, and architectural guides offline:
```powershell
# Godot API lookup
lapis docs lookup gd "Node2D.global_position"

# Crystal LibGodot binding lookup
lapis docs lookup crystal "Godot::Node2D#global_position"

# Architectural guide lookup
lapis docs lookup guide "gdscript"
lapis docs lookup guide "concurrency"
```

### 4.2. Interactive Test Runner TUI (`lapis test --tui`)
Launches the full-screen Opal ANSI dashboard:
```powershell
lapis test --tui
```
- Multi-phase execution checklist (Language Specs, Headless Tool Tests, Standalone Runtime Suites).
- Split-pane rolling execution logs with syntax coloring.
- Interactive navigation (`↑`/`↓`), phase inspection modals (`Enter`), and help overlay (`?`).
- In automated CI, invoke with `--no-tui` for clean streaming output.

### 4.3. Interactive Benchmarks &amp; Visualizer (`lapis bench --tui`)
Runs Crystal vs GDScript performance benchmarks with live ANSI charting:
```powershell
# Run benchmark suite with comparative ASCII/Unicode bars
lapis bench --tui

# Export static HTML report with interactive SVG charts
lapis bench --export-html report.html
```

### 4.4. Decompilation &amp; Binary Forensics (`lapis decompile`)
Disassemble and decompile functions side-by-side using Radare2 and Ghidra:
```powershell
# Inspect pseudo-C and disassembly of crystal_bridge_init
lapis decompile bin/game.dll "crystal_bridge_init" --side-by-side

# Launch full radare2 interactive visual session on game binary
lapis decompile bin/game.dll --r2
```

### 4.5. Modular Template Management (`lapis template`)
Squirrel away projects into the global store or browse in the interactive manager:
```powershell
# Save current project as a template
lapis template save pixel_rpg --desc "2D top-down starter"

# List stored templates
lapis template list

# Launch interactive split-pane Template Manager TUI
lapis template manager
```

### 4.6. Daily In-Editor Development (Mode A)
```powershell
# Launch Godot Editor (automatic shadow DLL loading on Windows)
lapis editor

# In editor: edit scenes and .cr files, press F5 to recompile game.dll hot-reloaded!
```
