module Lapis
  module Docs
    # # P. Lapis CLI Toolchain, Packaging Architecture & Release Hygiene
    #
    # The **Lapis CLI** (`lapis` / `lapis.exe`) is the unified developer toolchain for the
    # LibGodot Crystal ecosystem. It replaces ad-hoc shell scripts and brittle build steps
    # with a cohesive, cross-platform CLI for project scaffolding, compilation,
    # synchronization, diagnostics, testing, and production distribution.
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
    #       <td>Core features provided by the Lapis CLI toolchain.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>CLI Architecture</strong></td>
    #       <td><code>.topic_01_cli_architecture</code></td>
    #       <td>Subcommand hierarchy, baked filesystem assets, and cross-platform design.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Doctor Diagnostics</strong></td>
    #       <td><code>.topic_02_doctor_diagnostics</code></td>
    #       <td>Automated environment auditing: Crystal, Godot, C++ compiler, LLDB, and PATH.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Init Adoption</strong></td>
    #       <td><code>.topic_03_init_adoption</code></td>
    #       <td>Instant Crystal adoption and GDExtension configuration in existing Godot projects.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Build & Sync</strong></td>
    #       <td><code>.topic_04_build_and_sync</code></td>
    #       <td>Multi-target compilation and automated runtime library synchronization.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Packaging Hygiene</strong></td>
    #       <td><code>.topic_05_release_packaging_hygiene</code></td>
    #       <td>Foreign binary purging, PDB exclusion, and minimal distribution payloads.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Storage Reclamation</strong></td>
    #       <td><code>.topic_06_storage_reclamation</code></td>
    #       <td>Inspecting and reclaiming disk space with lapis clean --dry-run and --all.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `tools/lapis/src/`
    # - **Live Specifications**: `tools/lapis/spec/`
    # - **Related Guides**: `Docs::B_COMPILATION_AND_BUILD`, `Docs::N_GODOT_UPGRADE_GUIDE`
    module P_LAPIS_TOOLCHAIN_AND_PACKAGING
      # **Key Features**: Returns core features provided by the Lapis CLI toolchain.
      def self.topic_00_key_features : Array(String)
        [
          "Unified CLI toolchain: doctor, init, dirs, deps, sync, build, test, editor, package, clean",
          "Environment diagnostics with lapis doctor for Crystal, Godot, C++, and LLDB",
          "Instant Crystal adoption in existing Godot projects via lapis init",
          "Clean release packaging with automatic foreign binary purging and PDB exclusion",
          "Interactive storage reclamation tracking with lapis clean --dry-run",
          "Shell autocompletion script generation for PowerShell, Bash, and Zsh",
        ]
      end

      # **CLI Architecture**: Subcommand hierarchy, baked filesystem assets, and cross-platform design.
      #
      # The CLI binary (`bin/lapis` / `bin/lapis.exe`) is compiled independently from the game code:
      # - Embeds starter templates via Crystal's `BakedFileSystem`.
      # - Operates autonomously from any working directory on the developer's system.
      # - Features Levenshtein distance suggestions for mistyped commands.
      #
      # See also: `tools/lapis/src/`
      def self.topic_01_cli_architecture : Nil
      end

      # **Environment Diagnostics**: Automated environment auditing via lapis doctor.
      #
      # Audits the host developer machine for required tools:
      # ```bash
      # lapis doctor --verbose
      # ```
      #
      # Verifies Crystal compiler version, Godot engine executable, MinGW/MSVC C++ compilers,
      # LLDB debugger availability, and project manifest integrity.
      def self.topic_02_doctor_diagnostics : Nil
      end

      # **Project Adoption**: Instant Crystal adoption and GDExtension configuration via lapis init.
      #
      # Adopts an existing Godot project into the Crystal ecosystem:
      # ```bash
      # lapis init -p path/to/godot_project -n MyGame
      # ```
      #
      # Scaffolds `shard.yml`, `src/main.cr`, `Makefile`, and copies the GDExtension manifest.
      def self.topic_03_init_adoption : Nil
      end

      # **Multi-Target Compilation & Synchronization**: Coordinated compilation and runtime DLL propagation.
      #
      # - `lapis build game`: Compiles primary game dynamic library.
      # - `lapis build addons`: Compiles all project addons.
      # - `lapis sync`: Propagates bridge and runtime DLLs across all subprojects.
      def self.topic_04_build_and_sync : Nil
      end

      # **Release Packaging Hygiene**: Foreign binary purging, PDB exclusion, and minimal distribution payloads.
      #
      # To maintain professional distribution standards, Lapis enforces strict packaging hygiene:
      # 1. **Zero Bloat in Starter Templates**:
      #    Starter templates (`template-project.zip` and `template-addon-project.zip`)
      #    are packaged without compiled binaries, PDBs, intermediate caches, or shadow files.
      # 2. **Foreign Binary Purging**:
      #    Cross-platform foreign binaries (e.g. Linux `.so` files on Windows, or Windows `.dll`
      #    files on Linux) are actively purged before packaging archives or running tests.
      # 3. **Deduplication of Runtime Libraries**:
      #    Packages avoid multiple duplicate copies of `libgodot.dll` or runtime libraries across
      #    subdirectories, keeping archive sizes minimal and downloads fast.
      def self.topic_05_release_packaging_hygiene : Nil
      end

      # **Storage Reclamation**: Inspecting and reclaiming disk space with lapis clean.
      #
      # ```bash
      # # Dry run: inspect disk space reclaimable
      # lapis clean --dry-run
      #
      # # Reclaim disk space by purging shadow DLLs and build caches:
      # lapis clean --all
      # ```
      #
      # Reports the exact number of bytes freed while safely preserving `libgodot.dll` and runtime DLLs.
      def self.topic_06_storage_reclamation : Nil
      end
    end
  end
end
