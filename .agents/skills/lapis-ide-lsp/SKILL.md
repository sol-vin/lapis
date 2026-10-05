---
name: lapis-ide-lsp
description: >-
  Configure IDE environments, Crystalline Language Server (LSP), and radare2 debugging using lapis ide.
  Use when setting up VS Code, Zed, Cursor, or Neovim for Lapis development, fixing code completion, or configuring launch/task configurations.
---

# Lapis IDE & Language Server (LSP) Configuration Runbook

This skill is the authoritative engineering manual for configuring modern IDEs (VS Code, Cursor, Zed, Neovim) for full Crystal code intelligence, auto-completion, hover tooltips, jump-to-definition, and integrated radare2 debugging.

---

## Table of Contents
<table>
  <thead>
    <tr>
      <th align="left">Section</th>
      <th align="left">Description</th>
      <th align="center">Lines</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="#1-quick-command-reference"><strong>1. Quick Command Reference</strong></a></td>
      <td># Configure VS Code / Cursor workspace (.vscode/tasks.json, launch.json, settings.json)</td>
      <td align="center"><code>L54–L74</code></td>
    </tr>
    <tr>
      <td><a href="#2-vs-code-cursor-full-workspace-integration"><strong>2. VS Code & Cursor Full Workspace Integration</strong></a></td>
      <td>Running lapis ide setup vscode automatically generates 4 production-ready configuration files in .vscode/:</td>
      <td align="center"><code>L75–L179</code></td>
    </tr>
    <tr>
      <td><a href="#3-zed-editor-configuration"><strong>3. Zed Editor Configuration</strong></a></td>
      <td>Running lapis ide setup zed generates .zed/settings.json:</td>
      <td align="center"><code>L180–L203</code></td>
    </tr>
    <tr>
      <td><a href="#4-neovim-configuration-initlua"><strong>4. Neovim Configuration (`init.lua`)</strong></a></td>
      <td>Add the following to your Neovim lspconfig setup:</td>
      <td align="center"><code>L204–L234</code></td>
    </tr>
    <tr>
      <td><a href="#5-crystalline-language-server-setup-troubleshooting"><strong>5. Crystalline Language Server Setup & Troubleshooting</strong></a></td>
      <td>Lapis bundles and manages Crystalline, the high-performance Crystal language server.</td>
      <td align="center"><code>L235–L271</code></td>
    </tr>
  </tbody>
</table>

---

## 1. Quick Command Reference

```bash
# Configure VS Code / Cursor workspace (.vscode/tasks.json, launch.json, settings.json)
lapis ide setup vscode

# Configure Cursor IDE workspace (includes .cursorrules tailored for Lapis)
lapis ide setup cursor

# Configure Zed editor (.zed/settings.json with crystalline LSP)
lapis ide setup zed

# Configure Neovim workspace (outputs init.lua snippet for lspconfig)
lapis ide setup neovim

# Force overwrite existing IDE configuration files
lapis ide setup vscode --force
```

---

## 2. VS Code & Cursor Full Workspace Integration

Running `lapis ide setup vscode` automatically generates 4 production-ready configuration files in `.vscode/`:

### 2.1. Tasks Configuration (`.vscode/tasks.json`)
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Lapis: Build Game (F5 Hot Reload)",
      "type": "shell",
      "command": "bin/lapis",
      "args": ["build"],
      "group": { "kind": "build", "isDefault": true },
      "problemMatcher": ["$crystal"]
    },
    {
      "label": "Lapis: Run Game",
      "type": "shell",
      "command": "bin/lapis",
      "args": ["run"],
      "group": "test"
    },
    {
      "label": "Lapis: Run All Tests",
      "type": "shell",
      "command": "bin/lapis",
      "args": ["test", "--tui"],
      "group": "test"
    },
    {
      "label": "Lapis: Doctor Diagnostics",
      "type": "shell",
      "command": "bin/lapis",
      "args": ["doctor"],
      "problemMatcher": []
    }
  ]
}
```

### 2.2. Launch Configuration (`.vscode/launch.json`)
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Lapis: Launch Game in Godot",
      "type": "node-terminal",
      "request": "launch",
      "command": "bin/lapis run",
      "cwd": "${workspaceFolder}"
    },
    {
      "name": "Lapis: Debug with radare2",
      "type": "node-terminal",
      "request": "launch",
      "command": "bin/lapis run --debug",
      "cwd": "${workspaceFolder}"
    },
    {
      "name": "Lapis: Launch Godot Editor",
      "type": "node-terminal",
      "request": "launch",
      "command": "bin/lapis editor",
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

### 2.3. Workspace Settings (`.vscode/settings.json`)
```json
{
  "crystal-lang.server": "bin/crystalline.exe",
  "crystal-lang.serverArguments": ["--log-level=warning"],
  "crystal-lang.compiler": "crystal",
  "editor.formatOnSave": true,
  "[crystal]": {
    "editor.defaultFormatter": "crystal-lang-tools.crystal-lang",
    "editor.tabSize": 2,
    "editor.insertSpaces": true
  },
  "files.associations": {
    "*.cr": "crystal",
    "*.gdextension": "ini",
    "*.tscn": "ini",
    "*.tres": "ini"
  }
}
```

### 2.4. Recommended Extensions (`.vscode/extensions.json`)
```json
{
  "recommendations": [
    "crystal-lang-tools.crystal-lang",
    "geequlim.godot-tools"
  ]
}
```

---

## 3. Zed Editor Configuration

Running `lapis ide setup zed` generates `.zed/settings.json`:
```json
{
  "languages": {
    "Crystal": {
      "language_servers": ["crystalline"],
      "format_on_save": "on"
    }
  },
  "lsp": {
    "crystalline": {
      "binary": {
        "path": "bin/crystalline",
        "arguments": ["--log-level=warning"]
      }
    }
  }
}
```

---

## 4. Neovim Configuration (`init.lua`)

Add the following to your Neovim `lspconfig` setup:
```lua
local lspconfig = require('lspconfig')
local configs = require('lspconfig.configs')

if not configs.crystalline then
  configs.crystalline = {
    default_config = {
      cmd = { "bin/crystalline", "--log-level=warning" },
      filetypes = { "crystal" },
      root_dir = lspconfig.util.root_pattern("shard.yml", ".git"),
      single_file_support = true,
    },
  }
end

lspconfig.crystalline.setup({
  on_attach = function(client, bufnr)
    -- Enable completion, hover, and definition keymaps
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  end,
})
```

---

## 5. Crystalline Language Server Setup & Troubleshooting

Lapis bundles and manages **Crystalline**, the high-performance Crystal language server.

### Verification Checklist:
1. Run `lapis doctor` to verify that Crystalline is installed and discovered.
2. Ensure `src/` is in `CRYSTAL_PATH`.
3. If code completion hangs on complex macro expansions (`node`, `match`, `@[Export]`), increase Crystalline cache limits or clean stale caches via `lapis clean`.

### Troubleshooting Matrix:
<table>
  <thead>
    <tr>
      <th align="left">Issue / Symptom</th>
      <th align="left">Underlying Cause</th>
      <th align="left">Resolution</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>"Language server not found"</strong></td>
      <td><code>crystalline.exe</code> missing from PATH and <code>bin/</code></td>
      <td>Run <code>lapis deps</code> or <code>lapis setup</code> to pull the bundled binary.</td>
    </tr>
    <tr>
      <td><strong>No auto-completion for Godot nodes</strong></td>
      <td><code>CRYSTAL_PATH</code> does not include engine bindings in <code>src/</code></td>
      <td>Re-run <code>lapis ide setup vscode --force</code> to refresh <code>settings.json</code>.</td>
    </tr>
    <tr>
      <td><strong>High memory usage by Crystalline</strong></td>
      <td>Large macro expansions caching entire AST</td>
      <td>Pass <code>--cache-dir=.crystalline</code> and restart language server.</td>
    </tr>
  </tbody>
</table>
