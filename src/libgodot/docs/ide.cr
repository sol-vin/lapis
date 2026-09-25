module Lapis
  module Docs
    # # S. IDE Integration & Developer Experience
    #
    # The Lapis toolchain provides first-class developer tooling integration for modern external editors
    # through the `lapis ide` command family. It generates workspace configurations, attaches language
    # server daemons (Crystalline), and configures native LLDB launch targets.
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
    #       <td>Key developer tooling features provided by lapis ide.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>VS Code & Cursor</strong></td>
    #       <td><code>.topic_01_vscode_cursor_scaffolding</code></td>
    #       <td>Automated settings.json, tasks.json, and launch.json generation with LLDB debugging.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Zed Editor</strong></td>
    #       <td><code>.topic_02_zed_integration</code></td>
    #       <td>Workspace settings.json and high-speed build tasks for Zed.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Neovim & LSP</strong></td>
    #       <td><code>.topic_03_neovim_lsp_config</code></td>
    #       <td>.nvim.lua setup configuring nvim-lspconfig for Crystalline with stdlib discovery.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Task Runner Bindings</strong></td>
    #       <td><code>.topic_04_task_runner_bindings</code></td>
    #       <td>One-click compilation, test suite execution, and packaging shortcuts.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `tools/lapis/src/commands/ide.cr`
    # - **Live Specifications**: `tools/lapis/spec/commands/ide_spec.cr`
    # - **Related Guides**: `Docs::J_FIRST_CLASS_CRYSTAL_SCRIPTS`, `Docs::M_LLDB_NATIVE_DEBUGGING_GUIDE`
    module S_IDE_INTEGRATION_AND_DEVELOPER_EXPERIENCE
      # **Key Features**: Returns key developer tooling features provided by lapis ide.
      def self.topic_00_key_features : Array(String)
        [
          "Automated workspace scaffolding for VS Code, Cursor, Zed, and Neovim",
          "Built-in Crystalline LSP configuration with automatic binary discovery",
          "Pre-configured LLDB launch configurations for in-editor and standalone debugging",
          "Pre-configured task runners for compilation, test suites, and packaging",
        ]
      end

      # **VS Code & Cursor Scaffolding**: Automated settings.json, tasks.json, and launch.json generation.
      #
      # Run `lapis ide setup vscode` to generate full workspace configuration:
      # - `.vscode/settings.json`: Configures `crystalline.serverPath`, formatting, and file associations.
      # - `.vscode/tasks.json`: Configures `crystal build`, `make all`, and `make test`.
      # - `.vscode/launch.json`: Pre-configures CodeLLDB debugger to attach to `godot.exe` or standalone game binaries.
      #
      # ```bash
      # lapis ide setup vscode
      # ```
      def self.topic_01_vscode_cursor_scaffolding : Nil
      end

      # **Zed Editor Integration**: Workspace settings.json and high-speed build tasks for Zed.
      #
      # Run `lapis ide setup zed` to generate Zed configuration:
      # - `.zed/settings.json`: Configures LSP and syntax formatting for `.cr` files.
      # - `.zed/tasks.json`: Adds fast keyboard shortcuts for building game dynamic libraries.
      #
      # ```bash
      # lapis ide setup zed
      # ```
      def self.topic_02_zed_integration : Nil
      end

      # **Neovim & Crystalline LSP Setup**: Configuring nvim-lspconfig for Crystalline with stdlib discovery.
      #
      # Run `lapis ide setup neovim` to generate `.nvim.lua`:
      # - Configures `nvim-lspconfig` for `crystalline`.
      # - Auto-detects project root directory and Crystal standard library paths.
      #
      # ```bash
      # lapis ide setup neovim
      # ```
      def self.topic_03_neovim_lsp_config : Nil
      end

      # **Task Runner Bindings & Keybindings**: One-click compilation, test suite execution, and packaging shortcuts.
      #
      # All IDE setups provide unified shortcuts matching standard editor conventions:
      # - **Ctrl+Shift+B**: Executes default build task (`make all`).
      # - **F5**: Launches game under LLDB debugger.
      # - **Ctrl+Shift+T**: Executes test suite (`make test`).
      def self.topic_04_task_runner_bindings : Nil
      end
    end
  end
end
