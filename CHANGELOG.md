# Changelog

All notable changes to the Lapis for Crystal framework are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

#### Next-Gen Scene Pipeline, Tweening & Pattern Matching
- **Scene Pipeline Operator (`>`) & Fluent Mounting**:
  - `"res://scenes/enemy.tscn" > Enemy` and `packed_scene > Enemy`: instantiates and downcasts packed scenes directly to concrete wrapper type `T`.
  - `Node#add_child(node : T) : T forall T`: preserves concrete static type of added child nodes instead of returning `Void`, enabling `enemy = add_child("res://scenes/enemy.tscn" > Enemy)`.
  - Inline block configuration for child mounting: `add_child(scene > Enemy) do |e| ... end`.
  - Fluent configuration via `Object#build(&block)` and `Object#configure(&block)`.
  - Sibling pipeline parity: `add_sibling(scene > Enemy)` and `add_sibling(node : T) : T forall T`.
- **Type-Safe Tween Ergonomics & Animations**:
  - `macro tween(property_expr, to: value, in: duration)`: pure compile-time type-checked tweening catching typos (e.g. `boss.positiom.y`) at compile time with zero string allocations.
  - Multi-symbol property paths: `boss.tween_to(:position, :y, 150.0, 0.4.seconds)` and builder `animate :position, :y, to: ...`.
  - Target-omitted `tween_to`: `boss.tween_to("position:y", 150.0, 0.4.seconds)`.
  - Full `Time::Span` duration support across `tween_to`, `animate`, `delay`, and `Tween#tween_property`.
- **Expression-Oriented Pattern Matching (`match`)**:
  - `macro match(target, &block)`: multi-paradigm pattern matching DSL supporting:
    - Polymorphic class downcasting: `is Player do |p| ... end`
    - Variant unboxing: `is Int64 do |i| ... end`, `is String do |s| ... end`, `is Vector2 do |v| ... end`
    - Pattern guards: `is Player, if: p.health < 20 do |p| ... end`
    - Tuple destructuring: `is :jump, true do ... end`
    - Array Rest patterns: `is [first, .., last] do |f, l| ... end` and `is rest(head, _, _, tail) do |h, t| ... end`
    - Partial Dictionary patterns: `is dict(type: "chat", user: u, msg: m) do |_, u, m| ... end`
    - Wildcard patterns: `is _ do ... end` and `default do ... end`
- **Signal Cleanup & First-Class Emission**:
  - Added `TypedSignal#emit(*args : *T)` and `BoundSignal#emit(*args)` for first-class emission on signal accessors.
  - Added `disconnect_all` and `clear` on `TypedSignal`, `BoundSignal`, and `Godot::Object`.

### Removed
- **Synthesized Signal Helper Methods**:
  - Purged synthesized `emit_<signal_name>`, `on_<signal_name>`, and `on_<signal_name>_once` from `macro signal` to prevent namespace pollution and method collisions. Replaced with first-class `node.signal_name.emit(...)`, `node.signal_name.connect { ... }`, and `node.signal_name.once { ... }`.
- **`Node#punch_scale`**:
  - Removed `Node#punch_scale` in favor of declarative `tween` and `animate` builders.

#### Next-Generation Gameplay Usability & Ergonomics
- **Direct Tree Instantiation (`add_child(Class, &block)`, `add_sibling`)**:
  - `Node#add_child(NodeClass, &block)`: instantiates, configures, and adds child nodes in a single call without separate `.new` or boilerplate.
  - `Node#add_child(PackedScene, as: Type, &block)` and `Node#add_child(path, as: Type, &block)`: loads/instantiates packed scenes directly into child hierarchies with typed downcasting.
  - `Node#add_sibling(NodeClass, &block)` and scene overloads: seamlessly mounts sibling nodes under the current node's parent with configuration block and headless standalone fallback.
- **Frictionless Godot Dictionary**:
  - `Dictionary.new(**kwargs)`: initializes Godot dictionaries directly from keyword arguments (`Godot::Dictionary.new(health: 100, speed: 7.5_f32, hero: "Lapis")`).
  - Transparent Symbol key indexing and assignment (`dict[:score] = 500`, `dict[:score]`, `dict.has(:score)`).
  - Generic typed getters with defaults: `dict.get(key, as: Type, default: val)` and nilable safe `dict.get?(key, as: Type)`.
  - Nested dictionary drilling: `dict.dig?(:stats, :attack, :base, as: Int32)`.
  - Seamless conversions: `Hash#to_godot` / `Hash#to_godot_dictionary` and `Array#to_godot`.
- **GodotArray Utilities**:
  - `GodotArray#filter_as(Type)`: downcasts and filters array elements into a concrete `Array(T)`.
  - Bounds-safe utilities: `first?`, `last?`, `sample`, and negative indexing (`arr[-1]`).
- **Positional Type-Filtered Signals & Proc Dispatch**:
  - `on` macro (`on player.equipped, Player, Sword do |p, s| ... end`): declarative signal binding with positional type filtering, automatic downcasting, and wildcard `Any` support.
  - Signal compound assignment (`+=` and `-=`): connects and disconnects typed proc literals (`sig += ->(p : Player, s : Sword) { ... }`, `sig -= handler`).
  - Mass disconnection: `sig.disconnect_all` clearing all active subscribers safely.
- **Direct Space Physics Structures & Queries**:
  - `struct PhysicsHit2D` and `struct PhysicsHit3D`: typed physics raycast hit results with safe downcasting via `collider_as(Type)`.
  - `Node2D#raycast_to(target)` and `Node3D#raycast_to(target)`: direct one-line physics space queries without manual query parameter setup.
- **Lifecycle-Safe Cancellable Timers**:
  - `Godot::TimerHandle`: comprehensive timer controller with `cancel`, `pause`, `resume`, `reset`, `advance`, `running?`, and `paused?`.
  - `Godot.after`, `Godot.every`, `Node#after`, `Node#every`: returns a `TimerHandle` and tracks `node.active?` lifecycle to prevent execution on deallocated nodes.
- **Resource & ConfigFile Ergonomics**:
  - `Resource.load(path, as: Type)` and `resource.save!(path)` with `ResourceSaveError`.
  - `ConfigFile#get(section, key, as: Type, default)` and `ConfigFile#get?(section, key, as: Type)`.
- **SceneTree Scene Operations**:
  - `SceneTree#change_scene!(path | scene)`, `reload_scene!`, and `current_scene_as(Type)` with `SceneChangeError`.
- **Optional Standalone Modules**:
  - `require "lapis/math"`: `Number#approach`, `Number#degrees`, `Number#radians`, and randomized directional vectors (`Vector2.random_dir`, `Vector2.random_in_circle`, `Vector3.random_dir`, `Vector3.random_in_sphere`).
  - `require "lapis/fsm"`: zero-allocation compile-time state machine macro DSL (`fsm :name, initial: :state do state ... end`).
- Comprehensive unit specs in `spec/gameplay_ergonomics_spec.cr` (23 examples), `spec/optional_modules_spec.cr` (6 examples), and engine test runner suite in `spec/suites/test_gameplay_ergonomics.cr`.

#### Signal Compound Operators (`+=` and `-=`)
- **C#-Style Compound Assignment for Signals (`+=` and `-=`)**:
  - `node.signal_name += ->handler`: connects a typed proc (`Proc(*T, R)`), 0-argument proc (`Proc(R)`), or method pointer (`->listener.on_event`) to the signal using C#-style compound addition sugar.
  - `node.signal_name -= ->handler`: disconnects the matching subscriber by proc and closure environment identity.
  - `node.signal_name -= subscription`: disconnects an active `SignalSubscription` instance via subtraction operator.
  - Synthesized identity setter `def <signal>=(val : BoundSignal)` across `macro signal` and `macro godot_signal` allowing Crystal's AST lowerer (`p.sig = p.sig + handler`) to work seamlessly on node properties.
  - Thread-safe and dead-pointer safe: subscriptions track 64-bit ObjectDB instance IDs and self-prune when targets are destroyed, avoiding the delegate memory leaks prevalent in C#.
  - Comprehensive unit test suite in `spec/signal_operators_spec.cr` (12 examples) and engine runner test in `spec/suites/test_callable_signals_advanced.cr`.

#### Scene Tree Glob Queries & Ergonomic Traversal (`get_nodes`, `*`, `**`)
- **Wildcard & Recursive Globstar Query Engine (`Node#get_nodes`)**:
  - `Node#get_nodes(pattern)` (`src/libgodot/extensions/query.cr`): queries scene tree hierarchies with single-tier wildcard `*` (e.g. `Enemy*`, `*Mesh`, `WorldNodes/*/Mesh`) and recursive globstars `**` (e.g. `Enemies/**/Hitbox`, `Spawns/**`).
  - `Node#get_nodes(pattern, Type)`: typed query returning `Array(T)` filtered and safely downcasted to type `T` (e.g. `self.get_nodes("NodePath/SomeDir/*/Mesh", MeshInstance3D)`).
  - Streaming iteration: `Node#each_node(pattern, [type], &block)` and `Node#each_descendant([type], &block)` traversing scene subtrees without intermediate allocations.
  - First-match lookups: `Node#first_node?(pattern, [type])` and `Node#first_node(pattern, [type])` raising `NodeNotFoundError` on missing targets.
  - Wildcard subscript routing: `self["Enemies/*/Hitbox"]?` and `self["Enemies/*/Hitbox", Area2D]?` transparently forward wildcard patterns through `first_node?`.
- **Hierarchy & Family Traversal**:
  - Upward ancestry: `ancestor?(type)`, `ancestor(type)`, `ancestor?(pattern, [type])`, `ancestors([type])`, `topmost_parent`, and `scene_root`.
  - Sibling navigation: `siblings([type])`, `previous_sibling?([type])`, and `next_sibling?([type])`.
  - Child bounds: `first_child?([type])` and `last_child?([type])`.
- **Typed Group Helpers**:
  - `Node#nodes_in_group(group, [type])`, `Node#first_node_in_group?(group, [type])`, and `Node#first_node_in_group(group, [type])`.
  - `Godot.get_nodes_in_group(group, [type])` and `Godot.first_node_in_group?(group, [type])`.
  - Multi-group query: `Node#in_group?(*groups)` returning true if node matches any of the specified groups.
- **Batch Collection Operations on `Array(T)` (`src/libgodot/extensions/node_collection.cr`)**:
  - Node lifecycle: `queue_free_all`, `destroy_all`, and `reparent_all(new_parent, keep_global_transform)`.
  - Broadcast messaging & property assignment: `call_all(method, *args)` and `set_all(prop, value)`.
  - Batch visibility: `show_all` and `hide_all` across CanvasItem 2D and Node3D spatial elements.
  - Batch groups: `add_to_group_all(group)` and `remove_from_group_all(group)`.
  - Filtering and downcasting: `filter_as(Type)` returning a typed `Array(U)` of matching elements.
- Comprehensive test suite in `spec/node_query_and_ergonomics_spec.cr` (17 examples) and engine runner test in `spec/suites/test_hierarchy_ergonomics.cr`.

#### Gameplay Usability Macros & Ergonomic DSL
- **Fluent Instantiation & Property Assignment (`create`, `build`, `.new`)**:
  - `create` and `build` macros (`src/libgodot/macros.cr`): instantiate Godot engine nodes and custom Crystal classes with keyword arguments (`create Sprite2D, position: Vector2.new(10, 20)`) and block property assignments (`create Sprite2D do position = Vector2.new(10, 20); add_to_group("sprites") end`).
  - Class-level `SomeClass.create { ... }` and `SomeClass.build { ... }` macros on all `node` classes.
  - Block-enabled `Godot::Object.new(&block)` with `with self yield self` and `Object#configure(&block)` for fluent in-place configuration.
- **Entity Spawning & Scene Tree Attachment (`spawn_node`, `spawn_child`, `create_child`)**:
  - `spawn_node`, `spawn_child`, and `create_child` top-level macros supporting `under:` parameter (`spawn_node Bullet, under: self, position: pos`).
  - `Node#spawn_child` and `Node#create_child` instance methods for clean child node spawning and mounting.
- **Declarative Signal Connection Sugar (`on`)**:
  - `on` macro (`src/libgodot/macros/signals.cr`): connect blocks directly to first-class typed signals (`on button.pressed { do_something }`) or target/name pairs (`on enemy, "died" { |bounty| add_score(bounty) }`).
- **Scene Instantiation Sugar (`instantiate`, `instantiate_child`)**:
  - `instantiate` and `instantiate_child` macros: preloads, instantiates as typed wrapper, configures properties, and optionally attaches to scene tree in a single call.
- **Fluent Tween & Juice Animation DSL (`tween`, `tween_to`, `punch_scale`)**:
  - `Godot::TweenBuilder` and `Node#tween` (`src/libgodot/extensions/tween.cr`): block-based tween construction with automatic Variant wrapping and type-safe transition/easing enums.
  - `Node#tween_to` for single-property tweening and `Node#punch_scale` for instant juice/rebound animations.
- **Non-Blocking Timer Extensions (`after`, `every`)**:
  - `Godot.after` and `Node#after` (`src/libgodot/extensions/timer.cr`) using SceneTreeTimer non-blockingly without thread stalls.
  - `Godot.every` and `Node#every` for clean recurring interval execution.

#### In-Editor Experience & LSP Diagnostics Integration
- **Real-Time Static Syntax Validator (`src/libgodot/script/validator.cr`)**:
  - Sub-millisecond static analyzer (`Lapis::CrystalValidator`) detecting unclosed blocks (`def`, `class`, `module`, `do`, `begin`, `case`), unmatched delimiters, unclosed strings, and modifier clauses.
  - Integrated into Godot `ScriptLanguageExtension::_validate` via native C++ bridge `ret_dictionary_validate_ex` for live red error and yellow warning squiggles in the Godot script editor gutter.
- **Crystalline LSP Diagnostics & Hover Tooltips (`src/libgodot/script/lsp.cr`)**:
  - Asynchronous JSON-RPC notification pump consuming `textDocument/publishDiagnostics` from Crystalline.
  - `request_hover` and `_lookup_code` integration displaying docstrings and type signatures on F1 / hover in the editor.
- **Built-In Script Templates in "Attach Script" Dialog (`src/libgodot/script/language.cr`)**:
  - Implemented `_get_built_in_templates` providing 6 starter templates: Standard Node, 2D Physics Movement, 3D Physics Movement, Tool Script (`@[Tool]`), Custom Resource, and Empty Class.

#### In-Editor Action Driver ("Selenium for Godot Editor")
- **`Lapis::Editor::ActionDriver` (`src/libgodot/editor/action_driver.cr`)**:
  - Implemented comprehensive automation framework for driving Godot editor controls, viewport nodes, and UI trees.
  - CSS & XPath-style selector engines supporting IDs (`#play_button`), classes (`.Button`, `.ItemList`), hierarchical paths (`Panel > VBoxContainer > Button`), property matchers (`[name="Save"]`, `[text="Run"]`), and wildcard searches (`//Button`).
  - Input synthesis engine supporting `click`, `double_click`, `right_click`, `mouse_down`, `mouse_up`, and `mouse_move`.
  - Full keyboard automation with `type_text`, `press_key`, `key_down`, and `key_up`.
  - Multi-step interpolated `drag_and_drop(from, to, steps: 10)` for smooth UI drag operations.
  - Assertions & synchronization helpers: `wait_for(selector, timeout_sec: 5.0)`, `assert_visible`, `assert_text`, `assert_enabled`, and `assert_exists`.
  - Scene tree inspection: `dump_hierarchy` (formatted text tree) and `dump_json` (structured node metadata with class, name, path, global position, size, and visibility).

#### AI Vision Subsystem
- **`Lapis::Editor::ActionDriverVision` (`src/libgodot/editor/action_driver_vision.cr`)**:
  - Native viewport screenshots and sub-region element cropping via `crop_element(node, file_path)`.
  - Set-of-Marks AI Manifest generator via `capture_ai_manifest(output_dir)`.
  - Captures full viewport image (`full_viewport.png`), extracts individual interactive UI elements into cropped PNGs (`element_<ID>_<NAME>.png`), and generates structured `ui_manifest.json` with pixel-exact bounding boxes (`x`, `y`, `width`, `height`), node hierarchy metadata, and control classes for multimodal LLM visual inspection.

#### Remote Automation IPC Server
- **`Lapis::Editor::DriverServer` (`src/libgodot/editor/action_driver_ipc.cr`)**:
  - Localhost TCP JSON-RPC automation server running inside Godot on port 9223.
  - Exposes remote RPC endpoints: `locate`, `click`, `type`, `drag`, `dump_tree`, `capture_manifest`, and `crop`.
  - Seamlessly bridges CLI tools, test scripts, and external agents to the live running Godot editor.

#### CLI & TUI Action Driver Integration
- **`lapis driver` CLI Command (`tools/lapis/src/commands/driver.cr`)**:
  - CLI subcommands for remote editor manipulation:
    - `lapis driver click <selector>`
    - `lapis driver type <selector> <text>`
    - `lapis driver drag <source> <target>`
    - `lapis driver tree [--json]`
    - `lapis driver manifest [--out <dir>]`
    - `lapis driver repl` — interactive automation REPL with live command execution and autocomplete.
- **Double-Buffered Opal TUI Driver View (`tools/lapis/src/tui/driver_view.cr`)**:
  - Dedicated interactive terminal dashboard integrated into Lapis Hub (`[A] Action Driver Controller`).
  - Real-time connection status monitoring, interactive command prompt, and one-key quick actions:
    - `[1]` Dump Tree, `[2]` AI Manifest, `[3]` Click Inspector, `[4]` Focus Viewport, `[5]` Ping Server.
  - Scrollable activity console with ANSI color-coded status responses.

#### String Preload & Load Operators
- **Ergonomic Preload & Load Operators (`src/libgodot/extensions/resource.cr`)**:
  - `>` operator on `String` for compile-time cached preloading: `"res://scenes/player.tscn" > PackedScene`.
  - `>>` operator on `String` for dynamic runtime resource loading: `"res://assets/theme.tres" >> Theme`.
  - `PreloadCache` thread-safe singleton cache with `Godot.preload(path, T)` helper.

#### Cancellable Timer Handles
- **`TimerHandle` Lifecycle Controller (`src/libgodot/timer.cr`)**:
  - `every` and `after` now return a `TimerHandle` for fine-grained lifecycle management:
    - `handle.cancel` / `handle.stop` — immediately aborts the timer and disconnects signals.
    - `handle.pause` and `handle.resume` — temporarily freezes timer accumulation.
    - `handle.reset` — restarts timer duration from zero.
    - `handle.advance(delta)` — manually steps elapsed time forward (ideal for headless deterministic tests).
    - Status inspection: `handle.finished?`, `handle.paused?`, `handle.elapsed`, `handle.time_left`.
  - Protected callback dispatches with `#alive?` validation to eliminate dangling closures on freed nodes.

#### Hot-Reload State Preserver
- **6-Phase Transactional State Protocol (`src/libgodot/editor/state_preserver.cr`)**:
  - `Lapis::Editor::StatePreserver` preserves game/editor node state during live GDExtension DLL reloads:
    1. Pre-flight node tree validation.
    2. Recursive state snapshot serialization into JSON (`StateSnapshot`).
    3. Shadow DLL rebuild and swap.
    4. Schema drift reconciliation (handles added, removed, or altered properties without crashing).
    5. Silent hydration with signals temporarily blocked to prevent cascading event triggers.
    6. Post-reload state integrity verification.
  - Integrated into editor lifecycle via `Lapis::Editor.save_reload_state` and `Lapis::Editor.restore_reload_state`.

#### Core Engine Bindings & Spec Infrastructure
- **`Object#active?` (`src/libgodot/object.cr`)**: Unified alive-state check compatible with both live engine `ObjectDB` pointers and standalone Crystal unit test nodes.
- **`Variant#as_vector2` & `Variant#as_vector3` (`src/libgodot/variant.cr`)**: Added canonical type-conversion aliases for Vector types.
- **Standalone `Node#get_children` (`src/libgodot/extensions/node.cr`)**: Graceful fallback to `@local_children` when running under pure Crystal headless specs with null native engine pointers.
- **Specification Test Suites**:
  - `spec/preload_operator_spec.cr` — verifies `>` and `>>` operators, preload caching, and type assertions.
  - `spec/timer_handle_spec.cr` — verifies `TimerHandle` cancellation, pausing, stepping, and error suppression.
  - `spec/editor_action_driver_spec.cr` — verifies selector parsing, mouse/keyboard synthesis, tree dumping, and JSON-RPC dispatch.
  - `spec/editor_reload_state_preserver_spec.cr` — verifies 6-phase state snapshotting, schema reconciliation, and silent hydration.
