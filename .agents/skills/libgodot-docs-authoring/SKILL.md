---
name: libgodot-docs-authoring
description: >-
  Author, update, and organize technical documentation under Lapis::Docs.
  Use when creating new documentation pages, expanding existing guides,
  formatting section method doc comments, embedding HTML tables and examples,
  or building documentation with crystal docs.
---

# Lapis Documentation Authoring & Style Guide

This runbook defines the authoritative conventions, architectural invariants, and styling standards for authoring documentation under `Lapis::Docs` (located in `src/libgodot/docs/` and `src/libgodot/docs.cr`).

---

## 1. Architectural Invariants of the Documentation System

The documentation system serves a dual purpose:
1. **Offline and Online Static Manual (`crystal docs`)**:
   Running `make docs` compiles `src/lapis.cr` into a searchable, cross-linked HTML manual in `docs/` published to GitHub Pages.
2. **Godot In-Editor Offline Help (`EditorHelp`)**:
   Doc comments harvested from source code are loaded into Godot's F1 Help and Inspector tooltips. Extended architectural guides are browsed under `Lapis::Docs` in the API documentation.

### Directory & File Conventions:
- **Master Entry Point**: `src/libgodot/docs.cr`
  Declares `module Lapis::Docs`, provides the global table of contents and reading tracks, and requires each submodule.
- **Submodule Files**: `src/libgodot/docs/<topic>.cr`
  Each topic has its own dedicated `.cr` file.
- **Module Names**: Prefixed sequentially with single capital letters (`A_ARCHITECTURE`, `B_COMPILATION_AND_BUILD`, ..., `W_CPP_BRIDGE_ARCHITECTURE`) so they sort alphabetically in the Crystal docs sidebar in logical reading order.
- **Aliases**: Re-exported as top-level `Docs` and `Godot::Docs` in `src/libgodot/docs.cr`.

---

## 2. The Method Doc Comment Layout Standard

### The Golden Rule of Section Organization & Method Ordering
> [!IMPORTANT]
> **Always organize substantive sections into dedicated class methods with numerical zero-padded prefixes (`def self.topic_01_<slug> : Nil`) and formatted first-line summaries.**
>
> In Crystal Docs:
> 1. **Alphabetical Method Sorting**: Methods within a class/module are sorted strictly alphabetically. Without zero-padded numerical prefixes (`topic_01_`, `topic_02_`), methods sort out of order, scrambling the reading experience.
> 2. **Summary Sentence Extraction**: Crystal Docs extracts the first sentence of the method doc comment up to the first period followed by whitespace (`. `) to populate the **Method Summary** table. If the first line contains a period after a digit (e.g. `# ### 1. Foo`), Crystal truncates the summary to `1.` and renders broken HTML headings!
>
> When each topic follows the Lapis standard:
> 1. `def self.topic_00_<name>` is reserved for module metadata/helpers (e.g. `topic_00_key_features`).
> 2. Sequential sections use `def self.topic_01_<slug>`, `def self.topic_02_<slug>`, etc., guaranteeing natural chronological ordering in the docs.
> 3. The first doc comment line MUST be formatted as `# **Title**: 1-sentence concise description.` without any periods preceding the final punctuation mark.
> 4. `crystal docs` automatically builds a clean, readable **Method Summary** table with bold titles and complete sentences.
> 5. Each topic gets an independent, deep-linkable section card (`#[method_name]-class-method`).
> 6. Every section title is indexed and searchable in the docs search bar.

### Standard File Template:
```crystal
module Lapis
  module Docs
    # # [Letter]. [Title of Guide]
    #
    # [1-2 paragraph executive summary explaining the purpose, scope, and high-level architecture]
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
    #       <td>Core capabilities and features of this subsystem.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>[Topic 1 Name]</strong></td>
    #       <td><code>.topic_01_[slug]</code></td>
    #       <td>[1-sentence summary of topic 1]</td>
    #     </tr>
    #     <!-- Additional rows -->
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/[file].cr`
    # - **Live Specifications & Tests**: `spec/suites/test_[name].cr`
    # - **Showcase Examples**: `examples/basic_demo/src/main.cr`
    # - **Related Guides**: `Docs::[OTHER_MODULE]`
    module [LETTER]_[MODULE_NAME]
      # **Key Features**: Returns core capabilities and features of this subsystem.
      def self.topic_00_key_features : Array(String)
        [
          "Feature 1 description",
          "Feature 2 description",
        ]
      end

      # **[Topic 1 Title]**: [1-sentence concise description without internal periods].
      #
      # [In-depth conceptual explanation]
      #
      # #### Syntax & Options
      # [Explanation of flags, parameters, or annotations]
      #
      # #### Working Code Example
      # ```crystal
      # require "libgodot"
      #
      # node MyNode < CharacterBody3D do
      #   @[Export]
      #   property speed : Float32 = 10.0_f32
      # end
      # ```
      #
      # #### Key Invariants & Safety
      # - [Invariants, memory rules, or edge cases]
      #
      # See also: `spec/suites/test_[suite].cr`
      def self.topic_01_[slug] : Nil
      end

      # **[Topic 2 Title]**: [1-sentence concise description without internal periods].
      # ...
      def self.topic_02_[slug] : Nil
      end
    end
  end
end
```

---

## 3. Formatting & Styling Mandates

### 1. STRICT: Never Use Markdown Pipe Tables
**Never use Markdown pipe tables (`| Header | ... |`) in doc comments or documentation files.**
Markdown pipe tables frequently break or fail to render across different tools (Crystal compiler, Godot DocData XML parser, terminal output).

**Always use standard semantic HTML tables**:
```html
<table>
  <thead>
    <tr>
      <th>Column A</th>
      <th>Column B</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Item 1</strong></td>
      <td>Description 1</td>
    </tr>
  </tbody>
</table>
```

### 2. Code Block Syntax Highlighting
Always specify the language identifier on fenced code blocks:
- ` ```crystal ` for Crystal code.
- ` ```gdscript ` for GDScript code.
- ` ```cpp ` for C++ bridge code.
- ` ```bash ` or ` ```powershell ` for terminal commands.
- ` ```xml ` for Godot DocData XML.

### 3. Concrete Repository Cross-Linking
Never discuss macros or features purely in the abstract. Always reference and link to:
- **Unit & Suite Tests**: `spec/suites/test_macros_dsl.cr`, `spec/suites/test_concurrency.cr`, etc.
- **Showcase Projects**: `examples/basic_demo/src/main.cr`, `template/src/my_node.cr`.
- **Engine Bindings**: `src/libgodot/macros.cr`, `src/libgodot/channel.cr`, etc.

---

## 4. Step-by-Step Procedures

### How to Create a New Documentation Page:
1. **Choose the Next Available Letter**: Check `src/libgodot/docs.cr` for the current letter sequence (currently `A` through `W`).
2. **Create the File**: Create `src/libgodot/docs/<topic_name>.cr` using the standard template.
3. **Register in `src/libgodot/docs.cr`**:
   - Add `require "./docs/<topic_name>"` in `src/libgodot/docs.cr`.
   - Add the module to the appropriate learning track in `Lapis::Docs.reading_paths` and `table_of_contents`.
4. **Update `README.md`**:
   - Add the new guide to the technical manual table in `README.md`.
5. **Build and Verify**:
   - Run `make docs` (or `bin/lapis docs`).
   - Check `docs/Lapis/Docs/<LETTER>_<MODULE_NAME>.html`.

### How to Expand an Existing Documentation Page:
1. Identify the relevant file in `src/libgodot/docs/<topic>.cr`.
2. Add a new row to the module-level HTML summary table.
3. Add a new class method (`def self.<new_feature> : Nil`) with full doc comments, code snippets, and invariants.
4. Run `make docs` to verify the generated HTML and search index.

---

## 5. Verification Protocol

After creating or modifying documentation files:
1. **Compile Docs**:
   ```bash
   make docs
   ```
2. **Verify HTML Output & Absence of Errors**:
   - Confirm exit code 0.
   - Verify file was generated in `docs/Lapis/Docs/`.
3. **Verify Search Index**:
   - Check that the new method names exist in `docs/search-index.js`.
