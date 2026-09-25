module Lapis
  module Docs
    # # N. Godot Engine Upgrade Guide
    #
    # LibGodot supports rapid, repeatable upgrading to newer Godot Engine dev and stable releases
    # with single-command API dumps and workspace-wide regeneration.
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
    #       <td>Core features of the engine upgrade automation.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Automated Setup</strong></td>
    #       <td><code>.topic_01_automated_lapis_setup</code></td>
    #       <td>Downloading target engine releases via lapis setup -v &lt;version&gt;.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>API Dumping Protocol</strong></td>
    #       <td><code>.topic_02_api_dumping_protocol</code></td>
    #       <td>Dumping extension_api.json and gdextension_interface.h into rsrc/.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Workspace Rebuilding</strong></td>
    #       <td><code>.topic_03_workspace_rebuilding</code></td>
    #       <td>Regenerating typed Crystal bindings and recompiling the C++ loader bridge.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Verification & Smoke Tests</strong></td>
    #       <td><code>.topic_04_verification_and_smoke_testing</code></td>
    #       <td>Running specs, in-editor tool tests, and leak checks to validate engine compatibility.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `tools/lapis/src/commands/setup.cr`, `tools/api_generator/`
    # - **Config**: `godot-version.yml`
    # - **Related Guides**: `Docs::T_BINDINGS_ARCHITECTURE_AND_GENERATOR`, `Docs::B_COMPILATION_AND_BUILD`
    module N_GODOT_UPGRADE_GUIDE
      # **Key Features**: Returns core features of the engine upgrade automation.
      def self.topic_00_key_features : Array(String)
        [
          "Automated setup tool via lapis setup",
          "Single-source version tracking via godot-version.yml",
          "Automatic GDExtension API and interface header dumping into rsrc/",
          "Workspace-wide synchronization and verification via make all",
        ]
      end

      # **Automated Setup Tooling**: Downloading target engine releases via lapis setup.
      #
      # Upgrading the targeted Godot engine binary is performed in a single command:
      # ```bash
      # lapis setup -v 4.8.0
      # ```
      #
      # This downloads the official engine binary, extracts `godot.exe`, updates `godot-version.yml`,
      # and sets up execution permissions.
      def self.topic_01_automated_lapis_setup : Nil
      end

      # **API Dumping Protocol**: Dumping extension_api.json and gdextension_interface.h into rsrc/.
      #
      # Once the engine binary is in place, dump its GDExtension interface and schema:
      # ```bash
      # make dump_api
      # ```
      #
      # Produces:
      # - `rsrc/extension_api.json`: Complete engine reflection metadata.
      # - `rsrc/gdextension_interface.h`: GDExtension C function pointers.
      def self.topic_02_api_dumping_protocol : Nil
      end

      # **Workspace Rebuilding**: Regenerating typed Crystal bindings and recompiling the bridge.
      #
      # Regenerate typed Crystal classes and recompile the loader bridge:
      # ```bash
      # make generate
      # make all
      # ```
      #
      # Automatically resolves newly added engine classes, updated method hashes, and modified enums.
      def self.topic_03_workspace_rebuilding : Nil
      end

      # **Verification & Smoke Testing**: Validating that no breaking engine changes broke bindings or memory invariants.
      #
      # Validate that no breaking engine changes broke bindings or memory invariants:
      # ```bash
      # make test
      # ```
      #
      # Executes unit specs, `@tool` in-editor smoke tests, and quantitative memory leak monitors.
      def self.topic_04_verification_and_smoke_testing : Nil
      end
    end
  end
end
