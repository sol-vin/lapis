---
name: lapis-ide-lsp
description: >-
  Configure IDE environments, Crystalline Language Server (LSP), and radare2 debugging using lapis ide.
  Use when setting up VS Code, Zed, Cursor, or Neovim for Lapis development, fixing code completion, or configuring launch/task configurations.
---

# Lapis IDE & Language Server (LSP) Configuration Runbook

The `lapis ide` command automates the configuration of modern editors and IDEs (VS Code, Cursor, Zed, Neovim) for full Crystal code intelligence, auto-completion, jump-to-definition, and native radare2 debugging.

---

## 1. Quick Command Reference

```bash
# Configure VS Code / Cursor workspace
lapis ide setup vscode

# Configure Zed workspace
lapis ide setup zed

# Configure Neovim workspace
lapis ide setup neovim
```

---

## 2. Supported IDE Integrations

### 2.1. VS Code & Cursor (`setup vscode`)
Generates `.vscode/` configuration files:
- **`tasks.json`**:
  - `Lapis: Build Game (F5)`: Compiles `game.dll` for rapid hot-reloading.
  - `Lapis: Run Game`: Launches game via `lapis run`.
  - `Lapis: Run Tests`: Launches the unified test suite.
  - `Lapis: Doctor Diagnostics`: Runs `lapis doctor`.
- **`settings.json`**:
  - Sets Crystalline language server executable path (`bin/crystalline.exe`).
  - Configures `CRYSTAL_PATH` to resolve engine bindings in `src/`.
  - Configures formatting on save via `crystal tool format`.
- **`launch.json`**:
  - Native launch and debug targets via `lapis run`, `lapis editor`, and `lapis run --debug` (radare2).

### 2.2. Zed (`setup zed`)
Generates `.zed/settings.json` and tasks configured for Crystalline LSP and terminal builds.

---

## 3. Crystalline Language Server Setup

Lapis bundles and manages **Crystalline**, the high-performance Crystal language server:

1. **Verification**:
   Run `lapis doctor` to check if Crystalline is discovered in your PATH or `bin/`.
2. **Standard Discovery Locations**:
   - `bin/crystalline.exe` (workspace local)
   - `~/.local/bin/crystalline` / `%LOCALAPPDATA%\Programs\Lapis\bin\crystalline.exe`
3. **Features Provided**:
   - Semantic auto-completion for Godot nodes, virtual callbacks (`_ready`, `_process`), and properties.
   - Hover tooltips with parameter types and harvested doc comments.
   - Jump to definition across Crystal engine bindings and custom game nodes.
   - Real-time compiler syntax and type diagnostics.

---

## 4. Native radare2 Debugging Configuration

When you run `lapis ide setup vscode`, the following launch profiles are added to `.vscode/launch.json`:

```json
{
  "name": "Debug Godot Game (radare2)",
  "type": "node-terminal",
  "request": "launch",
  "command": "bin/lapis run --debug",
  "cwd": "${workspaceFolder}"
}
```

---

## 5. Troubleshooting Code Intelligence

If auto-completion or diagnostics fail:
1. **Check `CRYSTAL_PATH`**: Ensure `src/` is in `CRYSTAL_PATH`. Run `lapis doctor` to verify.
2. **Re-generate IDE files**: Run `lapis ide --vscode --force`.
3. **Restart Language Server**: In VS Code, press `Ctrl+Shift+P` -> `Crystal: Restart Language Server`.
4. **Clean Stale Caches**: Run `lapis clean` to purge any stale macro cache files.
