---
name: lapis-templates
description: Manage, author, squirrel away, and scaffold modular game templates using Lapis CLI. Use when saving custom templates, managing the global template store, or using the interactive template manager TUI.
---

# Lapis Modular Template System

The Lapis modular template system allows developers to convert any configured game project directory into a packaged, reusable template stored in a global system repository. Developers can browse templates, inspect metadata, export/import archives, and scaffold new games with custom starter configurations.

---

## 1. Global Template Storage Architecture

Templates are packaged into standalone directories containing a compressed `template.zip` and a lightweight `template.json` metadata manifest.

### Storage Locations by Operating System:
<table>
  <thead>
    <tr>
      <th align="left">Operating System</th>
      <th align="left">Global Template Store Path</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Windows</strong></td>
      <td><code>%APPDATA%/lapis/templates/</code> (e.g. <code>C:/Users/&lt;user&gt;/AppData/Roaming/lapis/templates/</code>)</td>
    </tr>
    <tr>
      <td><strong>macOS</strong></td>
      <td><code>~/Library/Application Support/lapis/templates/</code></td>
    </tr>
    <tr>
      <td><strong>Linux / BSD</strong></td>
      <td><code>$XDG_DATA_HOME/lapis/templates/</code> or <code>~/.local/share/lapis/templates/</code></td>
    </tr>
  </tbody>
</table>

### Template Manifest Schema (`template.json`):
```json
{
  "schema_version": 1,
  "name": "pixel_rpg",
  "display_name": "Pixel RPG Starter",
  "description": "2D top-down retro RPG template with grid movement and dialogue",
  "author": "sol-vin",
  "version": "1.0.0",
  "godot_version": "4.4.stable",
  "tags": ["2d", "rpg", "pixel", "retro"],
  "features": {
    "audio": true,
    "dialogue": true,
    "inventory": false
  },
  "addons": ["crystal_integration", "dummy_dialogue"],
  "created_at": "2026-10-01T08:00:00Z",
  "file_count": 42,
  "uncompressed_bytes": 1048576
}
```

### Automatic Exclusion Filter:
When packaging a template, Lapis automatically excludes ephemeral, large, or machine-specific files:
- Engine cache directories: `.godot/`, `.git/`, `.agents/`
- Build output directories: `bin/`, `lib/`
- Compiled binaries: `*.dll`, `*.exe`, `*.so`, `*.dylib`, `*.pdb`
- Lockfiles and overrides: `shard.lock`, `shard.override.yml`, `*.uid`
- Temporary and crash files: `*.tmp`, `*.log`, `_loaded_*.dll`, `crash_dump_*.json`

---

## 2. CLI Command Reference

<table>
  <thead>
    <tr>
      <th align="left">Command</th>
      <th align="left">Description</th>
      <th align="left">Example</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lapis new template [name]</code></td>
      <td>Squirrel away current project directory into global template store</td>
      <td><code>lapis new template pixel_rpg --desc &quot;2D starter&quot;</code></td>
    </tr>
    <tr>
      <td><code>lapis template save &lt;name&gt;</code></td>
      <td>Alias for saving current project as a template</td>
      <td><code>lapis template save topdown_rpg --tags &quot;2d,rpg&quot;</code></td>
    </tr>
    <tr>
      <td><code>lapis template list</code></td>
      <td>List all stored templates with version, file count, and description</td>
      <td><code>lapis template list</code></td>
    </tr>
    <tr>
      <td><code>lapis template info &lt;name&gt;</code></td>
      <td>Display full manifest, author, tags, and complete file tree</td>
      <td><code>lapis template info pixel_rpg</code></td>
    </tr>
    <tr>
      <td><code>lapis template remove &lt;name&gt;</code></td>
      <td>Delete a template from the global store</td>
      <td><code>lapis template remove old_proto</code></td>
    </tr>
    <tr>
      <td><code>lapis template clean [--all]</code></td>
      <td>Purge stored templates with confirmation prompt (or <code>--force</code>)</td>
      <td><code>lapis template clean --all --force</code></td>
    </tr>
    <tr>
      <td><code>lapis template export &lt;name&gt; -o &lt;zip&gt;</code></td>
      <td>Export a template to a redistributable zip archive</td>
      <td><code>lapis template export pixel_rpg -o rpg_v1.zip</code></td>
    </tr>
    <tr>
      <td><code>lapis template import &lt;zip&gt;</code></td>
      <td>Import a packaged template archive into the local store</td>
      <td><code>lapis template import community_fps.zip</code></td>
    </tr>
    <tr>
      <td><code>lapis template manager</code></td>
      <td>Launch full-screen interactive Opal TUI template manager</td>
      <td><code>lapis template manager</code></td>
    </tr>
  </tbody>
</table>

---

## 3. Template Squirrel-Away Workflow

To create and save a new template from an existing project:

1. **Prepare the Project Directory**:
   - Ensure the project has a valid `project.godot`, `shard.yml`, and clean entry scenes.
   - You do NOT need to delete `.godot/` or `bin/`; the exporter filters them automatically.
2. **Execute Save Command**:
   ```powershell
   lapis new template arcade_space \
     --desc "2D arcade space shooter with particles and score tracking" \
     --author "DevTeam" \
     --tags "2d,arcade,space,particles"
   ```
3. **Verify in Global Store**:
   ```powershell
   lapis template info arcade_space
   ```

---

## 4. Scaffolding New Games from Templates

Once saved in the global store, templates can be instantiated anywhere on the system:

### 1. Direct CLI Scaffolding:
```powershell
lapis new my_game --template arcade_space
```

### 2. Interactive Wizard Scaffolding:
Running `lapis new` without arguments launches the Opal interactive setup wizard:
```powershell
lapis new
```
- Step 1: Select project template (Built-in basic template or any custom stored template).
- Step 2: Configure project name and target directory.
- Step 3: Select optional feature addons (audio, inventory, dialogue).
- Step 4: Confirm configuration and scaffold.

### Post-Scaffolding Initialization:
When scaffolding from a template, Lapis automatically:
1. Unpacks `template.zip` into the target directory.
2. Updates `project.godot` with the new project title and main scene.
3. Updates `shard.yml` with the new application name and authors.
4. Generates an initial `crystal_integration.gdextension` manifest.
5. Runs `shards install` to fetch dependencies.
6. Synchronizes runtime libraries (`crystal_bridge.dll`, `gc.dll`).

---

## 5. Interactive Template Manager TUI (`lapis template manager`)

The Template Manager provides a full-screen split-pane TUI powered by Opal:

- **Left Pane**: Filterable list of all installed templates with search query bar (`/`).
- **Right Pane**: Live preview showing template metadata, author, engine version, tags, file counts, and recursive file tree.
- **Keybindings**:
  - `↑` / `↓` or `j` / `k`: Navigate templates.
  - `/`: Search / filter templates in real time.
  - `Enter` or `n`: Scaffold a new project immediately from the selected template.
  - `e`: Export selected template to a `.zip` archive.
  - `d` or `Delete`: Delete template from store with confirmation.
  - `q` or `Esc`: Exit manager.
