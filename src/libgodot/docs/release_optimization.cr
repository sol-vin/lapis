module Lapis
  module Docs
    # # R. Release Optimization & Editor Stripping
    #
    # LibGodot enforces compile-time and runtime isolation between development tooling
    # and shipping binaries. When compiling games for production (`make all RELEASE=1` or
    # `lapis build --release`), editor-only modules and metadata are completely stripped.
    #
    # ### Executive Summary & Key Topics
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Topic</th>
    #       <th>Method / Anchor</th>
    #       <th>Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>Key Features</strong></td>
    #       <td><code>.topic_00_key_features</code></td>
    #       <td>Core features of release optimization.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Compile-Time Guards</strong></td>
    #       <td><code>.topic_01_compile_time_guards</code></td>
    #       <td>Excluding editor UI docks and LSP plugins via flag?(:release) compile macros.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>DocData XML Stripping</strong></td>
    #       <td><code>.topic_02_doc_data_xml_stripping</code></td>
    #       <td>Eliminating in-memory XML doc comment strings in production builds.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>ClassDB Filtering</strong></td>
    #       <td><code>.topic_03_classdb_filtering</code></td>
    #       <td>Suppressing editor tool classes in standalone C++ runtime registrations.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Clean Distribution Payload</strong></td>
    #       <td><code>.topic_04_clean_distribution_payload</code></td>
    #       <td>Excluding debug PDBs, intermediate build caches, and test artifacts.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/lapis.cr`, `src/bridge/classdb_registry.hpp`
    # - **Live Specifications**: `spec/suites/test_release_optimization.cr`
    # - **Related Guides**: `Docs::P_LAPIS_TOOLCHAIN_AND_PACKAGING`, `Docs::B_COMPILATION_AND_BUILD`
    module R_RELEASE_OPTIMIZATION_AND_EDITOR_STRIPPING
      # **Key Features**: Returns core features of release optimization.
      def self.topic_00_key_features : Array(String)
        [
          "Compile-time exclusion of editor plugins and UI docks via flag?(:release)",
          "Zero XML doc comment bloat in release builds",
          "C++ bridge ClassDB filtering suppressing editor classes in standalone runtime",
          "Automated package pruning of debug PDBs and editor plugin binaries",
        ]
      end

      # **Compile-Time Guards**: Excluding editor UI docks and plugins via compile-time flags.
      #
      # The core library entry points (`src/lapis.cr` and `src/libgodot.cr`) wrap editor modules
      # in compile-time guards:
      #
      # ```crystal
      # {% unless flag?(:release) || flag?(:libgodot_addon) || flag?(:no_editor) %}
      #   require "./libgodot/script"
      #   require "./libgodot/debugger/lldb_driver"
      #   require "./libgodot/editor"
      # {% end %}
      # ```
      #
      # This completely strips `CrystalIntegrationPlugin`, `CrystalHighlighter`, `CrystalDebuggerPlugin`,
      # and `CrystalScript` from shipping game executables and dynamic libraries.
      def self.topic_01_compile_time_guards : Nil
      end

      # **DocData XML Stripping**: Eliminating in-memory XML doc comment strings in production builds.
      #
      # In development, doc comments on nodes and exported properties are gathered into `EditorDocRegistry`
      # and registered with Godot's offline help database. In release mode, `EditorDocRegistry.register`
      # and `load_all` become no-ops, eliminating all XML strings and associated memory allocations.
      def self.topic_02_doc_data_xml_stripping : Nil
      end

      # **Native C++ ClassDB Filtering**: Suppressing editor tool classes in standalone C++ runtime registrations.
      #
      # In `src/bridge/classdb_registry.hpp`, when `!is_editor_active()` or in non-editor runtime contexts,
      # editor-specific classes are discarded prior to registering with the Godot engine `ClassDB`.
      def self.topic_03_classdb_filtering : Nil
      end

      # **Clean Distribution Payload**: Packaging minimal shipping payloads without debug symbols or bloat.
      #
      # When invoking `lapis package game --release`:
      # - Intermediate debug files (`*.pdb`, `*.exp`, `*.lib`, `plugin.*`) are excluded.
      # - Foreign platform binaries (e.g. Linux `.so` files on Windows) are purged.
      # - Only the minimal runtime payload is shipped to end-users.
      def self.topic_04_clean_distribution_payload : Nil
      end
    end
  end
end
