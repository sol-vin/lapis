module Lapis
  module Docs
    # # P. Lapis CLI Toolchain, Packaging Architecture & Release Hygiene
    #
    # The **Lapis CLI** (`lapis` / `lapis.exe`) is the unified developer toolchain for the
    # LibGodot Crystal ecosystem. It replaces ad-hoc shell scripts and brittle build steps
    # with a cohesive, cross-platform CLI for project scaffolding, compilation,
    # synchronization, diagnostics, testing, and production distribution.
    #
    # ---
    #
    # ### Core Command Reference
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Command</th>
    #       <th style="padding: 10px 14px;">Purpose</th>
    #       <th style="padding: 10px 14px;">Key Options</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>lapis doctor</code></td>
    #       <td style="padding: 10px 14px;">Diagnoses toolchain health (Crystal, Godot, C++ compiler, LLDB, packaging tools, and project health).</td>
    #       <td style="padding: 10px 14px;"><code>--verbose</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>lapis init</code></td>
    #       <td style="padding: 10px 14px;">Initializes Crystal integration into an existing Godot project.</td>
    #       <td style="padding: 10px 14px;"><code>-p &lt;path&gt;</code>, <code>-n &lt;name&gt;</code>, <code>--force</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>lapis build</code></td>
    #       <td style="padding: 10px 14px;">Compiles game libraries (<code>game.dll</code> / <code>game.so</code>), plugins, or standalone runners.</td>
    #       <td style="padding: 10px 14px;"><code>game</code>, <code>addons</code>, <code>examples</code>, <code>-r</code> (release), <code>-m</code> (single-module)</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>lapis editor</code></td>
    #       <td style="padding: 10px 14px;">Opens Godot Editor with log monitoring, auto-quit, and LLDB breakpoint sync.</td>
    #       <td style="padding: 10px 14px;"><code>-p &lt;path&gt;</code>, <code>--lldb</code>, <code>--quit-after &lt;sec&gt;</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>lapis run</code></td>
    #       <td style="padding: 10px 14px;">Launches project standalone with crash log monitoring and LLDB debugging.</td>
    #       <td style="padding: 10px 14px;"><code>-p &lt;path&gt;</code>, <code>--lldb</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>lapis test</code></td>
    #       <td style="padding: 10px 14px;">Runs complete multi-tier test suite (specs, tool tests, and standalone test project).</td>
    #       <td style="padding: 10px 14px;"><code>--skip-specs</code>, <code>--skip-runtime-tests</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>lapis clean</code></td>
    #       <td style="padding: 10px 14px;">Prunes intermediate build binaries, shadow DLLs, and logs while safely preserving runtime DLLs.</td>
    #       <td style="padding: 10px 14px;"><code>-d, --dry-run</code>, <code>--all</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>lapis package</code></td>
    #       <td style="padding: 10px 14px;">Generates clean distribution archives, standalone games, or Inno Setup / Debian packages.</td>
    #       <td style="padding: 10px 14px;"><code>game</code>, <code>template</code>, <code>addon</code>, <code>release</code>, <code>windows-installer</code>, <code>deb</code></td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><code>lapis completion</code></td>
    #       <td style="padding: 10px 14px;">Generates native shell autocompletion script.</td>
    #       <td style="padding: 10px 14px;"><code>powershell</code>, <code>bash</code>, <code>zsh</code></td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # ### Clean Release Hygiene & Packaging Invariants
    #
    # To maintain professional distribution standards, Lapis enforces strict packaging hygiene:
    # 1. **Zero Bloat in Starter Templates**:
    #    Starter templates (<code>template-project.zip</code> and <code>template-addon-project.zip</code>)
    #    are packaged without compiled binaries, PDBs, intermediate caches, or shadow files unless
    #    <code>--bundle-binaries</code> is explicitly passed.
    # 2. **Foreign Binary Purging**:
    #    Cross-platform foreign binaries (e.g. Linux <code>.so</code> files on Windows, or Windows <code>.dll</code>
    #    files on Linux) are actively purged before packaging archives or running tests.
    # 3. **Deduplication of Runtime Libraries**:
    #    Packages avoid multiple duplicate copies of <code>libgodot.dll</code> or runtime libraries across
    #    subdirectories, keeping archive sizes minimal and downloads fast.
    # 4. **Storage Reclamation**:
    #    <code>lapis clean --dry-run</code> allows inspecting disk space before deletion, and <code>lapis clean</code>
    #    reports the exact amount of disk space reclaimed.
    #
    module P_LAPIS_TOOLCHAIN_AND_PACKAGING
      def self.features : Array(String)
        [
          "Unified CLI toolchain: doctor, init, dirs, deps, sync, build, test, editor, package, clean",
          "Environment diagnostics with lapis doctor for Crystal, Godot, C++, and LLDB",
          "Instant Crystal adoption in existing Godot projects via lapis init",
          "Clean release packaging with automatic foreign binary purging and PDB exclusion",
          "Interactive storage reclamation tracking with lapis clean --dry-run",
          "Shell autocompletion script generation for PowerShell, Bash, and Zsh",
          "Levenshtein distance typo correction for intuitive CLI navigation",
        ]
      end
    end
  end
end

