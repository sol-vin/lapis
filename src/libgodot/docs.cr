# ==============================================================================
# LibGodot Documentation System
# ==============================================================================
#
# This file provides the unified entry point for LibGodot technical documentation.
# Individual architectural guides, topic explanations, and engine caveats are
# split across modular files in `src/libgodot/docs/`.
#
# To browse the generated manual:
# ```bash
# make docs
# ```
# Then open `docs/index.html` in your web browser.
# ==============================================================================

module Lapis
  # The `Lapis::Docs` module provides exhaustive technical reference and architectural
  # documentation for the LibGodot and Lapis toolchains.
  #
  # Topics include:
  # - **Architecture**: Dual-paradigm execution (GDExtension Mode A vs Standalone LibGodot Mode B)
  # - **Compilation & Build**: Multi-consumer DLL synchronization, Windows shadow DLL loading
  # - **Exports & Inspector**: `@export` property macros, type mappings, and inspector metadata
  # - **Node DSL & Signals**: Declarative scene nodes, signals, RPC annotations, and lifecycle
  # - **Doc Comments**: In-editor tooltips and offline F1 Help XML harvesting
  # - **GDScript Interop**: Bidirectional reflection, custom properties, and channel coordination
  # - **Memory Safety**: Dead-pointer protection, monotonic instance IDs, and leak prevention
  # - **Concurrency**: Fibers, actor channels (`Godot::Channel`), and OS worker threads
  # - **Toolchain**: CLI commands, scaffolding, installers, and packaging
  module Docs
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

alias Docs = ::Lapis::Docs

module Godot
  alias Docs = ::Lapis::Docs
end
