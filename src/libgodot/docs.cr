# ==============================================================================
# LibGodot Documentation System
# ==============================================================================
#
# This file provides the unified entry point and master navigation hub for LibGodot
# and Lapis technical documentation. Individual architectural guides, topic
# explanations, and engine caveats are organized across 23 modular files in
# `src/libgodot/docs/`.
#
# To browse the generated manual locally:
# ```bash
# make docs
# ```
# Then open `docs/index.html` in your web browser.
# ==============================================================================

module Lapis
  # The `Lapis::Docs` module is the authoritative technical reference and architectural
  # manual for the LibGodot and Lapis toolchains.
  #
  # ## Learning Tracks & Topic Index
  #
  # The documentation is structured into 5 foundational learning tracks:
  #
  # ### 1. Core Architecture & Native Integration
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Module</th>
  #       <th>Topic</th>
  #       <th>Key Concepts</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>A_ARCHITECTURE</code></td>
  #       <td>Dual-Paradigm Model</td>
  #       <td>Mode A (GDExtension Editor / Runner) vs Mode B (Standalone LibGodot Host)</td>
  #     </tr>
  #     <tr>
  #       <td><code>B_COMPILATION_AND_BUILD</code></td>
  #       <td>Build System Orchestration</td>
  #       <td>C++ bridge, Windows shadow DLL file-locking bypass, F5 editor build hook</td>
  #     </tr>
  #     <tr>
  #       <td><code>W_CPP_BRIDGE_ARCHITECTURE</code></td>
  #       <td>Native Loader Bridge</td>
  #       <td>Memory layout, GDExtension proc address table, classdb dispatch, crash guards</td>
  #     </tr>
  #     <tr>
  #       <td><code>H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY</code></td>
  #       <td>Memory Safety & ObjectDB</td>
  #       <td>Dead-pointer prevention, monotonic 64-bit instance IDs, DisposedObjectError</td>
  #     </tr>
  #     <tr>
  #       <td><code>G_CAVEATS_AND_INTERNALS</code></td>
  #       <td>Engine Internals & Caveats</td>
  #       <td>Boehm GC vs Godot refcounting, SceneTree thread affinity, cached method binds</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ### 2. Declarative Gameplay DSL & Systems
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Module</th>
  #       <th>Topic</th>
  #       <th>Key Concepts</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>D_NODE_DSL_AND_SIGNALS</code></td>
  #       <td>Node DSL & Lifecycle</td>
  #       <td>Declarative scene nodes, _ready, _process, signals, scene tree APIs, @[Tool]</td>
  #     </tr>
  #     <tr>
  #       <td><code>L_MACRO_DSL_REFERENCE</code></td>
  #       <td>Macro DSL Reference</td>
  #       <td>node, resource, gdclass, @[Export*], signals, @[Tool], @[RPC], onready</td>
  #     </tr>
  #     <tr>
  #       <td><code>C_EXPORTS_AND_INSPECTOR</code></td>
  #       <td>Export System & Inspector</td>
  #       <td>Ranges, enums, flags, files, node paths, categories, groups, tool buttons</td>
  #     </tr>
  #     <tr>
  #       <td><code>O_LOW_LATENCY_INPUT_GUIDE</code></td>
  #       <td>Low-Latency Controls</td>
  #       <td>_unhandled_input, sub-frame mouse look, disabling accumulation, zero-alloc queries</td>
  #     </tr>
  #     <tr>
  #       <td><code>I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY</code></td>
  #       <td>Concurrency & Thread Safety</td>
  #       <td>Fibers with Fiber.yield, OS worker threads, buffered channels, call_deferred</td>
  #     </tr>
  #     <tr>
  #       <td><code>K_CONCURRENCY_CHANNELS_AND_ERGONOMICS</code></td>
  #       <td>Channels & Ergonomics</td>
  #       <td>GodotChannel actor pattern, GDScript signal interop, async engine helpers</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ### 3. Scripting, Interoperability & IDE Experience
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Module</th>
  #       <th>Topic</th>
  #       <th>Key Concepts</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>E_DOC_COMMENTS_AND_HELP</code></td>
  #       <td>Doc Comments & Editor Help</td>
  #       <td>Compile-time doc comment harvesting, DocData XML, F1 offline help</td>
  #     </tr>
  #     <tr>
  #       <td><code>F_GDSCRIPT_INTEROP</code></td>
  #       <td>GDScript Interoperability</td>
  #       <td>Automated project bindings, Variant marshaling, cross-language signals and calls</td>
  #     </tr>
  #     <tr>
  #       <td><code>J_FIRST_CLASS_CRYSTAL_SCRIPTS</code></td>
  #       <td>First-Class Crystal Scripts</td>
  #       <td>Direct .cr editing in Godot Script Editor, syntax highlighting, Crystalline LSP</td>
  #     </tr>
  #     <tr>
  #       <td><code>S_IDE_INTEGRATION_AND_DEVELOPER_EXPERIENCE</code></td>
  #       <td>IDE Integration</td>
  #       <td>One-click workspace setup for VS Code, Cursor, Zed, and Neovim</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ### 4. Quality Assurance, Diagnostics & Benchmarks
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Module</th>
  #       <th>Topic</th>
  #       <th>Key Concepts</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>Q_TESTING_FRAMEWORK_AND_EDITOR_SUITES</code></td>
  #       <td>Testing Apparatus</td>
  #       <td>Lapis::Test matchers, async frame-stepping, signal timeouts, in-editor suites</td>
  #     </tr>
  #     <tr>
  #       <td><code>M_LLDB_NATIVE_DEBUGGING_GUIDE</code></td>
  #       <td>Native LLDB Debugging</td>
  #       <td>In-editor gutter breakpoints, PDB/DWARF symbol resolution, multiplayer sessions</td>
  #     </tr>
  #     <tr>
  #       <td><code>V_PERFORMANCE_AND_BENCHMARKS</code></td>
  #       <td>Performance & Benchmarks</td>
  #       <td>Crystal vs GDScript benchmarks, SVG and dark-mode HTML reports, CI tracking</td>
  #     </tr>
  #     <tr>
  #       <td><code>U_CODE_CLEANUP_AND_DRY_PATTERNS</code></td>
  #       <td>Clean Code & DRY Patterns</td>
  #       <td>Consolidated ptrcall macros, singleton delegation, C++ RAII memory safety</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ### 5. Toolchain, Operations & Distribution
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Module</th>
  #       <th>Topic</th>
  #       <th>Key Concepts</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>P_LAPIS_TOOLCHAIN_AND_PACKAGING</code></td>
  #       <td>Lapis CLI & Packaging</td>
  #       <td>doctor, init, build, test, clean, packaging hygiene, Windows and Debian installers</td>
  #     </tr>
  #     <tr>
  #       <td><code>N_GODOT_UPGRADE_GUIDE</code></td>
  #       <td>Godot Upgrades</td>
  #       <td>lapis setup engine upgrades, extension API dumping, workspace synchronization</td>
  #     </tr>
  #     <tr>
  #       <td><code>R_RELEASE_OPTIMIZATION_AND_EDITOR_STRIPPING</code></td>
  #       <td>Release Optimization</td>
  #       <td>Compile-time flag stripping, ClassDB runtime filtering, minimal distribution payloads</td>
  #     </tr>
  #     <tr>
  #       <td><code>T_BINDINGS_ARCHITECTURE_AND_GENERATOR</code></td>
  #       <td>Bindings Generator</td>
  #       <td>extension_api.json parser, topological DAG resolution, zero-alloc stack ptrcalls</td>
  #     </tr>
  #     <tr>
  #       <td><code>X_ADDONS_AND_PLUGINS_GUIDE</code></td>
  #       <td>Addons & Plugins</td>
  #       <td>Multi-target execution (Editor, Standalone, Portable), pure Crystal test runner, isolation</td>
  #     </tr>
  #   </tbody>
  # </table>
  module Docs
    # **Quick-Start Commands**: Essential make and lapis CLI commands for building, running, and testing.
    def self.topic_01_quick_start : String
      <<-HELP
      Lapis Quick Start:
        - make all         : Compile bridge, test project, examples, template, and sync
        - make test        : Execute complete test suite (specs, tool tests, runtime runner)
        - make editor      : Open test project in Godot Editor
        - make docs        : Build offline HTML documentation site in docs/
        - make run         : Launch game standalone
      HELP
    end

    # **Learning Tracks & Reading Paths**: Curated guides organized by developer role (Beginner, Systems, Tooling, Performance).
    def self.topic_02_reading_paths : Hash(String, Array(String))
      {
        "Getting Started (New Game Developer)" => [
          "D_NODE_DSL_AND_SIGNALS",
          "L_MACRO_DSL_REFERENCE",
          "C_EXPORTS_AND_INSPECTOR",
          "O_LOW_LATENCY_INPUT_GUIDE",
          "P_LAPIS_TOOLCHAIN_AND_PACKAGING",
        ],
        "Architecture & Systems Programming" => [
          "A_ARCHITECTURE",
          "B_COMPILATION_AND_BUILD",
          "W_CPP_BRIDGE_ARCHITECTURE",
          "H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY",
          "I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY",
        ],
        "Scripting, Interop & Tooling" => [
          "E_DOC_COMMENTS_AND_HELP",
          "F_GDSCRIPT_INTEROP",
          "J_FIRST_CLASS_CRYSTAL_SCRIPTS",
          "S_IDE_INTEGRATION_AND_DEVELOPER_EXPERIENCE",
          "M_LLDB_NATIVE_DEBUGGING_GUIDE",
        ],
        "Production Quality, Testing & Performance" => [
          "Q_TESTING_FRAMEWORK_AND_EDITOR_SUITES",
          "V_PERFORMANCE_AND_BENCHMARKS",
          "U_CODE_CLEANUP_AND_DRY_PATTERNS",
          "R_RELEASE_OPTIMIZATION_AND_EDITOR_STRIPPING",
          "T_BINDINGS_ARCHITECTURE_AND_GENERATOR",
        ],
      }
    end

    # **Master Table of Contents**: Complete sequential index of all 23 architectural and developer guides (A through W).
    def self.topic_03_table_of_contents : Array(String)
      [
        "A_ARCHITECTURE",
        "B_COMPILATION_AND_BUILD",
        "C_EXPORTS_AND_INSPECTOR",
        "D_NODE_DSL_AND_SIGNALS",
        "E_DOC_COMMENTS_AND_HELP",
        "F_GDSCRIPT_INTEROP",
        "G_CAVEATS_AND_INTERNALS",
        "H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY",
        "I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY",
        "J_FIRST_CLASS_CRYSTAL_SCRIPTS",
        "K_CONCURRENCY_CHANNELS_AND_ERGONOMICS",
        "L_MACRO_DSL_REFERENCE",
        "M_LLDB_NATIVE_DEBUGGING_GUIDE",
        "N_GODOT_UPGRADE_GUIDE",
        "O_LOW_LATENCY_INPUT_GUIDE",
        "P_LAPIS_TOOLCHAIN_AND_PACKAGING",
        "Q_TESTING_FRAMEWORK_AND_EDITOR_SUITES",
        "R_RELEASE_OPTIMIZATION_AND_EDITOR_STRIPPING",
        "S_IDE_INTEGRATION_AND_DEVELOPER_EXPERIENCE",
        "T_BINDINGS_ARCHITECTURE_AND_GENERATOR",
        "U_CODE_CLEANUP_AND_DRY_PATTERNS",
        "V_PERFORMANCE_AND_BENCHMARKS",
        "W_CPP_BRIDGE_ARCHITECTURE",
        "X_ADDONS_AND_PLUGINS_GUIDE",
      ]
    end

    # :nodoc:
    def self.quick_start : String
      topic_01_quick_start
    end

    # :nodoc:
    def self.reading_paths : Hash(String, Array(String))
      topic_02_reading_paths
    end

    # :nodoc:
    def self.table_of_contents : Array(String)
      topic_03_table_of_contents
    end
  end
end

require "./docs/architecture"
require "./docs/compilation"
require "./docs/exports"
require "./docs/node_dsl"
require "./docs/doc_comments"
require "./docs/gdscript_interop"
require "./docs/caveats"
require "./docs/memory_safety"
require "./docs/concurrency"
require "./docs/crystal_scripts"
require "./docs/channels"
require "./docs/macros"
require "./docs/debugging"
require "./docs/upgrade"
require "./docs/input"
require "./docs/toolchain"
require "./docs/testing"
require "./docs/release_optimization"
require "./docs/ide"
require "./docs/generator"
require "./docs/patterns"
require "./docs/benchmarks"
require "./docs/cpp_bridge"
require "./docs/addons_and_plugins"

alias Docs = ::Lapis::Docs

module Godot
  alias Docs = ::Lapis::Docs
end
