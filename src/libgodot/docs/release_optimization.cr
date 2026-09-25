module Lapis
  module Docs
    # # R. Release Optimization & Editor Stripping
    #
    # LibGodot enforces compile-time and runtime isolation between development tooling
    # and shipping binaries. When compiling games for production (`make all RELEASE=1` or
    # `lapis build --release`), editor-only modules and metadata are completely stripped:
    #
    # 1. **Compile-Time Feature Guards**:
    #    The core library entry points (`src/lapis.cr` and `src/libgodot.cr`) wrap editor modules
    #    in compile-time guards (`{% unless flag?(:release) || flag?(:libgodot_addon) || flag?(:no_editor) %}`).
    #    This completely excludes `CrystalIntegrationPlugin`, `CrystalHighlighter`, `CrystalDebuggerPlugin`,
    #    `CrystalPanel`, and `CrystalScript` from the compiled binary.
    #
    # 2. **DocData XML Stripping**:
    #    In development, doc comments on nodes and exported properties are gathered into `EditorDocRegistry`
    #    and registered with Godot's offline help database. In release mode, `EditorDocRegistry.register`
    #    and `load_all` become no-ops, eliminating all XML strings and associated memory allocations.
    #
    # 3. **Native C++ ClassDB Filtering**:
    #    In `src/bridge/classdb_registry.hpp`, when `!is_editor_active()` or in non-editor runtime contexts,
    #    editor-specific classes are discarded prior to registering with the Godot engine `ClassDB`.
    #
    # 4. **Packaging Artifact Cleanliness**:
    #    When invoking `lapis package game --release`, intermediate debug files (`*.pdb`, `*.exp`, `*.lib`,
    #    `plugin.*`) are excluded from the distribution archive, ensuring only the minimal runtime payload
    #    is shipped to end-users.
    #
    module R_RELEASE_OPTIMIZATION_AND_EDITOR_STRIPPING
      def self.features : Array(String)
        [
          "Compile-time exclusion of editor plugins and UI docks via flag?(:release)",
          "Zero XML doc comment bloat in release builds",
          "C++ bridge ClassDB filtering suppressing editor classes in standalone runtime",
          "Automated package pruning of debug PDBs and editor plugin binaries",
        ]
      end
    end
  end
end

