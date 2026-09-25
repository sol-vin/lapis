module Lapis
  module Docs
    # # S. IDE Integration & Developer Experience
    #
    # The Lapis toolchain provides first-class developer tooling integration for modern editors
    # through the `lapis ide` command family.
    #
    # 1. **Automated IDE Setup**:
    #    Run `lapis ide setup [editor]` to automatically generate workspace configurations:
    #    - **VS Code / Cursor** (`lapis ide setup vscode`):
    #      Generates `.vscode/settings.json`, `.vscode/tasks.json`, and `.vscode/launch.json`.
    #      Configures Crystalline Language Server Protocol, Crystal build tasks,
    #      and LLDB launch configurations targeting `godot.exe` or standalone games.
    #    - **Zed** (`lapis ide setup zed`):
    #      Generates `.zed/settings.json` and `.zed/tasks.json` configuring Crystalline LSP
    #      and one-click build tasks.
    #    - **Neovim** (`lapis ide setup neovim`):
    #      Generates `.nvim.lua` configuring `nvim-lspconfig` to attach Crystalline LSP
    #      with root directory detection and stdlib discovery.
    #
    # 2. **Supported IDEs**:
    #    <table>
    #      <thead>
    #        <tr>
    #          <th>Editor</th>
    #          <th>Target Configuration</th>
    #          <th>Capabilities</th>
    #        </tr>
    #      </thead>
    #      <tbody>
    #        <tr>
    #          <td>VS Code / Cursor</td>
    #          <td>.vscode/settings.json, tasks.json, launch.json</td>
    #          <td>Crystalline LSP, Build Tasks, LLDB Native Debugging</td>
    #        </tr>
    #        <tr>
    #          <td>Zed</td>
    #          <td>.zed/settings.json, tasks.json</td>
    #          <td>Crystalline LSP, High-Speed Editor Tasks</td>
    #        </tr>
    #        <tr>
    #          <td>Neovim</td>
    #          <td>.nvim.lua</td>
    #          <td>nvim-lspconfig Crystalline integration</td>
    #        </tr>
    #      </tbody>
    #    </table>
    #
    module S_IDE_INTEGRATION_AND_DEVELOPER_EXPERIENCE
      def self.features : Array(String)
        [
          "Automated workspace scaffolding for VS Code, Cursor, Zed, and Neovim",
          "Built-in Crystalline LSP configuration with automatic binary discovery",
          "Pre-configured LLDB launch configurations for in-editor and standalone debugging",
          "Pre-configured task runners for compilation, test suites, and packaging",
        ]
      end
    end
  end
end

