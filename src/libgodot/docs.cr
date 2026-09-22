# ==============================================================================
# LibGodot Documentation System
# ==============================================================================
#
# This file provides in-depth technical documentation modules for LibGodot.
# The modules are organized alphabetically (A through G) so that generating
# HTML documentation via `crystal docs` (or `make docs`) creates an exhaustive,
# well-ordered manual covering architecture, compilation, exports, node DSL,
# doc comments, GDScript interop, and low-level engine caveats.
#
# To browse the generated manual:
# ```bash
# make docs
# ```
# Then open `docs/index.html` in your web browser.
# ==============================================================================

module Lapis
  module Docs
  # # A. Dual-Paradigm Architecture
  #
  # LibGodot for Crystal is designed around a **dual-paradigm architecture** that
  # provides both rapid, hot-reloading in-editor game development and lean,
  # standalone native executable production shipping:
  #
  # 1. **Mode A: GDExtension In-Editor / Runner Paradigm** (`game.dll` + `crystal_bridge.dll`)
  # 2. **Mode B: Standalone LibGodot Host Paradigm** (`game.exe` + `libgodot.dll`)
  #
  # ---
  #
  # ### Mode A: GDExtension In-Editor Workflow
  #
  # Used when creating games inside the **Godot Editor 4.8+** (`make editor`) or running
  # via the Godot engine binary (`make run`).
  #
  # In this mode:
  # - Godot is the parent host process (`godot.exe`).
  # - Godot discovers `addons/crystal_integration/crystal.gdextension` at startup.
  # - The manifest directs Godot to load `bin/crystal_bridge.dll` (a lightweight native C++ bridge).
  # - During library initialization (`crystal_library_init`):
  #   1. Godot passes its C-API function table pointer (`GDExtensionInterfaceGetProcAddress`).
  #   2. The bridge initializes the Boehm Garbage Collector (`GC_init()`) for Crystal.
  #   3. In development mode, the bridge creates a timestamped shadow copy of `game.dll`
  #      (`game_loaded_<PID>_<timestamp>.dll`) to prevent Windows OS file lock collisions.
  #   4. The bridge dynamically loads the shadow DLL via `LoadLibraryA` (or `dlopen` on Linux).
  #   5. The bridge resolves `crystal_godot_init` inside `game.dll` and hands over the
  #      `BridgeAPI` function table.
  #   6. Crystal registers custom nodes, signals, exported properties, and doc comments
  #      into Godot's `ClassDB` and `EditorHelp` subsystems.
  # - Pressing **Play (F5)** or **Play Scene (F6)** in the Godot editor invokes the
  #   `EditorPlugin._build()` hook in `addons/crystal_integration/crystal_integration.gd`,
  #   automatically recompiling `game.dll` and reloading without restarting Godot.
  #
  # ---
  #
  # ### Mode B: Standalone LibGodot Host Paradigm
  #
  # Used for standalone shipping builds (`make game_exe`), embedded deployments, or CI test runners.
  #
  # In this mode:
  # - Crystal compiles as a standalone Windows PE executable (`bin/game.exe`).
  # - Crystal owns the `main()` entry point, boots its runtime, and configures GC natively.
  # - Godot is compiled as a shared library (`bin/libgodot.dll`).
  # - Crystal loads `libgodot.dll` in-memory using `LibGodot::DynamicLoader`.
  # - Crystal invokes `libgodot_create_godot_instance(argc, argv, init_callback)`, passing
  #   its own command-line arguments and an initialization callback.
  # - Godot boots in-memory and invokes Crystal's `Scene`-level initialization callback,
  #   registering all nodes and scene hooks directly.
  # - Crystal steps the main loop, controls window initialization, and manages shutdown.
  #
  # ---
  #
  # ### Comparison Table
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Feature</th>
  #       <th style="padding: 10px 14px;">Mode A (GDExtension Bridge)</th>
  #       <th style="padding: 10px 14px;">Mode B (Standalone LibGodot)</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Host Process</strong></td>
  #       <td style="padding: 10px 14px;">Godot Engine (<code>godot.exe</code>)</td>
  #       <td style="padding: 10px 14px;">Crystal Executable (<code>game.exe</code>)</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Shared Libraries</strong></td>
  #       <td style="padding: 10px 14px;"><code>crystal_bridge.dll</code>, <code>game.dll</code></td>
  #       <td style="padding: 10px 14px;"><code>libgodot.dll</code></td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Godot Editor</strong></td>
  #       <td style="padding: 10px 14px;">Full support (Inspector, Node tree, F1 Help)</td>
  #       <td style="padding: 10px 14px;">Headless or embedded window</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Hot Reloading</strong></td>
  #       <td style="padding: 10px 14px;">Live shadow reload on F5 / F6</td>
  #       <td style="padding: 10px 14px;">Recompilation of executable required</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>GC Bootstrapping</strong></td>
  #       <td style="padding: 10px 14px;">Initialized by C++ bridge (<code>GC_init</code>)</td>
  #       <td style="padding: 10px 14px;">Initialized natively by Crystal CRT</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Target Use-Case</strong></td>
  #       <td style="padding: 10px 14px;">Development, editing, prototyping</td>
  #       <td style="padding: 10px 14px;">Standalone production distribution</td>
  #     </tr>
  #   </tbody>
  # </table>
  module A_ARCHITECTURE
    # Dummy method for documentation visibility
    def self.overview : String
      "Mode A (GDExtension) for editor iteration; Mode B (Standalone LibGodot) for production shipping."
    end
  end

  # # B. Compilation, Linking & Build System
  #
  # LibGodot connects three different compilation layers into a unified build system:
  # 1. **C++ GDExtension Loader Bridge** (`src/bridge/crystal_bridge.cpp`)
  # 2. **Crystal Game / Test / Example DLLs** (`game.dll`)
  # 3. **Godot Engine Dynamic Library** (`libgodot.dll`)
  #
  # ---
  #
  # ### 1. Compiling the C++ Loader Bridge (`crystal_bridge.dll`)
  #
  # The bridge is compiled with MinGW-w64 `g++` (or MSVC / clang) into `bin/crystal_bridge.dll`:
  # ```bash
  # g++ -shared -O3 src/bridge/crystal_bridge.cpp -o bin/crystal_bridge.dll -lgc
  # ```
  #
  # Why is a separate loader bridge required?
  # - **Boehm GC Bootstrapping**: Crystal DLLs dynamically loaded into an external host
  #   process (like `godot.exe`) do not run Crystal's native executable CRT initialization.
  #   The bridge explicitly calls `GC_init()` before invoking any Crystal exported symbol.
  # - **Zero C++ Headers in Crystal**: The bridge maps Godot's complex C++ GDExtension
  #   API and function pointers into a clean, flat C-ABI structure (`BridgeAPI`), allowing
  #   Crystal to interact with Godot without any C++ header dependencies.
  # - **Exception & Crash Guarding**: The bridge wraps instance dispatches in structured
  #   guards, preventing unhandled engine crashes when user scripts fail.
  #
  # ---
  #
  # ### 2. The Shadow Copying Reload Mechanism
  #
  # Under Windows, when a process loads a DLL via `LoadLibraryA`, the operating system
  # places an exclusive shared-read lock on the file. Any attempt by the Crystal compiler
  # to overwrite `game.dll` while Godot is open results in:
  # ```
  # Error: Access is denied. (ERROR_SHARING_VIOLATION / Windows error 32)
  # ```
  #
  # To solve this, `crystal_bridge.cpp` implements **Shadow Copy Loading** in development mode:
  # 1. When `crystal_bridge.dll` initializes, it checks for `LIBGODOT_RELEASE`. If absent,
  #    shadow loading is enabled.
  # 2. Before loading `bin/game.dll`, the bridge copies `bin/game.dll` to:
  #    `bin/game_loaded_<PID>_<TIMESTAMP>.dll`
  # 3. The bridge calls `LoadLibraryA` on the shadow copy, leaving `bin/game.dll` unlocked!
  # 4. The Crystal compiler can now freely rebuild `bin/game.dll` at any time while the
  #    Godot editor is still running.
  # 5. Old shadow copies from terminated processes are automatically pruned at startup.
  #
  # In release builds (`LIBGODOT_RELEASE=1`), shadow copying is disabled to eliminate disk I/O.
  #
  # ---
  #
  # ### 3. Compiling Crystal Game Code (`game.dll`)
  #
  # Crystal compiles user nodes into a dynamic library via:
  # ```bash
  # crystal build --cross-compile --link-flags="-shared" src/main.cr -o bin/game.dll
  # ```
  #
  # Crystal exports two primary C-ABI entry points:
  # - `crystal_godot_init(api : LibBridge::BridgeAPI*) : Int32`:
  #   Called by the loader bridge immediately after loading. Crystal stores the `BridgeAPI`
  #   pointer, iterates over `ClassRegistry`, registers all custom classes, properties,
  #   and signals with `ClassDB`, and registers offline XML documentation with `EditorHelp`.
  # - `crystal_godot_cleanup : Void`:
  #   Called when the library unloads during engine shutdown.
  #
  # ---
  #
  # ### 4. Editor Build Hook (`EditorPlugin._build`)
  #
  # The Godot editor plugin located at `addons/crystal_integration/crystal_integration.gd`
  # intercepts Godot's build pipeline:
  # - It overrides `EditorPlugin._build()`.
  # - Whenever the developer presses **F5** (Play Project) or **F6** (Play Scene), the
  #   plugin executes `crystal build` in the background.
  # - If compilation succeeds, Godot continues launching the scene with the updated DLL.
  # - If compilation fails, the output is printed directly to the Godot Editor Output Dock,
  #   and scene launching is cleanly halted.
  #
  # ---
  #
  # ### 5. Build System Synchronization (`make all`)
  #
  # The root `Makefile` orchestrates compilation across the entire workspace:
  # - `make bridge`: Builds `bin/crystal_bridge.dll`.
  # - `make test_project`: Builds `test/bin/game.dll`.
  # - `make examples`: Builds all showcase projects in `examples/`.
  # - `make template`: Builds `template/bin/game.dll`.
  # - `make sync`: Synchronizes `crystal_bridge.dll`, runtime DLLs (`gc.dll`, `iconv-2.dll`,
  #   `pcre2-8.dll`), and `crystal.gdextension` across `bin/`, `test/bin/`, `template/bin/`,
  #   and `examples/*/bin/`.
  #
  # > **Rule**: Always execute `make all` rather than partial builds to guarantee all consumer
  # > directories and bridge DLLs remain synchronized.
  module B_COMPILATION_AND_BUILD
    # Dummy method for documentation visibility
    def self.rules : Array(String)
      [
        "Always use 'make all' to keep consumer DLLs in sync",
        "Bridge performs shadow copy loading on Windows to prevent file locking",
        "GC_init() is called by the bridge before Crystal code executes",
        "F5 in Godot Editor triggers addons/crystal_integration build hook"
      ]
    end
  end

  # # C. Export System & Inspector Properties
  #
  # LibGodot provides a rich property export system matching Godot's native `@export`
  # capabilities. Annotations placed above Crystal properties are analyzed at compile
  # time by the `node` macro, translating them into Godot `PropertyInfo` descriptors
  # registered into `ClassDB`.
  #
  # ---
  #
  # ### How the Export Macro Pipeline Operates
  #
  # 1. At compile time, the `node` macro inspects each `property` declaration inside the block.
  # 2. It reads attached annotations (`@[Export]`, `@[ExportRange]`, `@[ExportFlags]`, etc.).
  # 3. It maps the Crystal type to Godot's `Variant::Type` enum:
  #    - `Bool` -> `Variant::Type::BOOL` (1)
  #    - `Int32`, `Int64` -> `Variant::Type::INT` (2)
  #    - `Float32`, `Float64` -> `Variant::Type::FLOAT` (3)
  #    - `String` -> `Variant::Type::STRING` (4)
  #    - `Vector2` -> `Variant::Type::VECTOR2` (5)
  #    - `Vector3` -> `Variant::Type::VECTOR3` (9)
  #    - `Color` -> `Variant::Type::COLOR` (20)
  #    - `NodePath` -> `Variant::Type::NODE_PATH` (22)
  # 4. It constructs a `Godot::PropertyInfo` instance specifying:
  #    - `name`: Property name in snake_case (e.g. `"movement_speed"`)
  #    - `variant_type`: The integer Godot Variant type
  #    - `hint`: `PropertyHint` enum value (e.g. `RANGE`, `ENUM`, `FILE`, `FLAGS`)
  #    - `hint_string`: Formatted hint string (e.g. `"0.0,100.0,0.5"`, `"Warrior,Mage,Rogue"`)
  #    - `usage`: `PROPERTY_USAGE_DEFAULT` (6) or `PROPERTY_USAGE_STORAGE` (64)
  # 5. It generates typed property getters and setters in the `CrystalClassDesc` structure:
  #    - `get_property`: Casts the instance pointer, reads the Crystal property, and writes
  #      it into Godot's uninitialized Variant buffer.
  #    - `set_property`: Reads the incoming Variant value, unmarshals it to the target
  #      Crystal type, and invokes the Crystal property setter.
  #
  # ---
  #
  # ### Complete Annotation Reference
  #
  # #### 1. General Export (`@[Export]`)
  # Exports the property with default inspector editor controls inferred from type:
  # ```crystal
  # @[Export]
  # property speed : Float32 = 10.0_f32
  #
  # @[Export]
  # property player_name : String = "Hero"
  #
  # @[Export]
  # property is_alive : Bool = true
  #
  # @[Export]
  # property tint : Color = Color::WHITE
  #
  # @[Export]
  # property target_position : Vector3 = Vector3.new(0, 1, 0)
  # ```
  #
  # #### 2. Numeric Ranges (`@[ExportRange]` or `@[Export(range: ...)]`)
  # Displays a slider with min, max, and step constraints:
  # ```crystal
  # # Min 0.0, max 100.0, step 0.5
  # @[ExportRange(0.0, 100.0, 0.5)]
  # property health : Float64 = 100.0
  #
  # # Crystal range syntax
  # @[Export(range: 1..100, step: 1)]
  # property level : Int32 = 1
  # ```
  #
  # #### 3. Enumerations & Choices (`@[ExportEnum]`)
  # Displays a dropdown list of options in the Inspector. Supports string choices or Crystal `Enum` types directly:
  # ```crystal
  # enum CharacterClass
  #   Warrior = 0
  #   Mage    = 1
  #   Rogue   = 5
  # end
  #
  # # Direct strongly-typed Crystal enum:
  # @[ExportEnum(CharacterClass)]
  # property character_class : CharacterClass = CharacterClass::Warrior
  #
  # # Integer property with enum dropdown:
  # @[ExportEnum(CharacterClass)]
  # property class_id : Int32 = 0
  #
  # # String choice list:
  # @[ExportEnum("Warrior", "Mage", "Rogue", "Paladin")]
  # property character_class_name : String = "Warrior"
  # ```
  #
  # #### 4. File & Directory Selectors
  # Opens Godot's native file dialog in the inspector:
  # ```crystal
  # # Project-relative file picker with filter
  # @[ExportFile("*.png,*.jpg")]
  # property sprite_path : String = ""
  #
  # # Project-relative file selector
  # @[ExportFilePath]
  # property script_file : String = ""
  #
  # # Project-relative directory picker
  # @[ExportDir]
  # property assets_folder : String = "res://assets"
  #
  # # Absolute OS filesystem file selector
  # @[ExportGlobalFile("*.txt")]
  # property log_file : String = ""
  #
  # # Absolute OS filesystem directory selector
  # @[ExportGlobalDir]
  # property backup_dir : String = ""
  # ```
  #
  # #### 5. Text Input Variations
  # ```crystal
  # # Multiline text editor area
  # @[ExportMultiline]
  # property dialogue_text : String = "Welcome adventurer!\nPrepare for battle."
  #
  # # Placeholder ghost text shown when empty
  # @[ExportPlaceholder("Enter character name...")]
  # property custom_name : String = ""
  # ```
  #
  # #### 6. Bitmask Flags (`@[ExportFlags]`)
  # Renders multiple checkbox toggles representing an integer bitmask. Supports string flags or Crystal `@[Flags] enum` types directly:
  # ```crystal
  # @[Flags]
  # enum CombatFlags
  #   Melee
  #   Ranged
  #   Magic
  # end
  #
  # # Strongly-typed flag enum:
  # @[ExportFlags(CombatFlags)]
  # property flags : CombatFlags = CombatFlags::Melee
  #
  # # Integer bitmask property with enum flags:
  # @[ExportFlags(CombatFlags)]
  # property flags_mask : Int32 = 0
  #
  # # Custom named flags:
  # @[ExportFlags("Fire", "Water", "Earth", "Air")]
  # property elemental_affinities : Int32 = 0
  #
  # # Godot 2D / 3D physics and render layer masks
  # @[ExportFlags2DPhysics]
  # property collision_mask_2d : Int32 = 1
  #
  # @[ExportFlags3DPhysics]
  # property collision_mask_3d : Int32 = 1
  #
  # @[ExportFlags2DRender]
  # property render_layers_2d : Int32 = 1
  #
  # @[ExportFlags3DRender]
  # property render_layers_3d : Int32 = 1
  #
  # @[ExportFlags3DNavigation]
  # property nav_layers_3d : Int32 = 1
  #
  # @[ExportFlagsAvoidance]
  # property avoidance_layers : Int32 = 1
  # ```
  #
  # #### 7. Visual & Specialized Controls
  # ```crystal
  # # Exponential easing curve editor widget
  # @[ExportExpEasing]
  # property camera_curve : Float32 = 1.0_f32
  #
  # # Color picker suppressing alpha channel
  # @[ExportColorNoAlpha]
  # property base_color : Color = Color::RED
  #
  # # NodePath selector restricted to specific scene node types
  # @[ExportNodePath("Camera3D")]
  # property target_camera : NodePath = NodePath.new
  # ```
  #
  # ##### Strongly-Typed NodePath Filtering (`@[ExportNodePath]`)
  #
  # Godot allows `NodePath` properties to restrict user selection in the editor scene tree
  # inspector to specific node classes. LibGodot supports string names, direct Godot class
  # types, union types, and type aliases with compile-time type validation:
  #
  # ```crystal
  # alias CameraTarget = Godot::Camera3D | Godot::Camera2D
  #
  # node PlayerFollowCam < Node3D do
  #   # 1. Direct Godot class reference:
  #   @[ExportNodePath(Godot::Camera3D)]
  #   property primary_cam : NodePath = NodePath.new
  #
  #   # 2. Union types (allows selecting Camera3D OR Camera2D in inspector):
  #   @[ExportNodePath(Godot::Camera3D | Godot::Camera2D)]
  #   property secondary_cam : NodePath = NodePath.new
  #
  #   # 3. Type alias representing a union or single class:
  #   @[ExportNodePath(CameraTarget)]
  #   property tertiary_cam : NodePath = NodePath.new
  #
  #   # 4. Classical string literal or array of strings:
  #   @[ExportNodePath("Camera3D", "Camera2D")]
  #   property fallback_cam : NodePath = NodePath.new
  # end
  # ```
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Annotation Variant</th>
  #       <th>Example Syntax</th>
  #       <th>Godot Hint String</th>
  #       <th>Compile-Time Validation</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><strong>Direct Class</strong></td>
  #       <td><code>@[ExportNodePath(Godot::Camera3D)]</code></td>
  #       <td><code>"Camera3D"</code></td>
  #       <td>Verified against Crystal type system; typo raises compiler error</td>
  #     </tr>
  #     <tr>
  #       <td><strong>Union Type</strong></td>
  #       <td><code>@[ExportNodePath(Godot::Camera3D | Godot::Camera2D)]</code></td>
  #       <td><code>"Camera3D,Camera2D"</code></td>
  #       <td>Each union branch is checked for existence at compile time</td>
  #     </tr>
  #     <tr>
  #       <td><strong>Type Alias</strong></td>
  #       <td><code>@[ExportNodePath(CameraTarget)]</code></td>
  #       <td><code>"Camera3D,Camera2D"</code></td>
  #       <td>Resolved alias types are checked and stripped into engine class names</td>
  #     </tr>
  #     <tr>
  #       <td><strong>String Literal</strong></td>
  #       <td><code>@[ExportNodePath("Camera3D")]</code></td>
  #       <td><code>"Camera3D"</code></td>
  #       <td>Permits arbitrary custom GDExtension or script class names</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # #### 8. Storage Without Inspector Display (`@[ExportStorage]`)
  # Serializes the property into the scene `.tscn` file without displaying it in the inspector:
  # ```crystal
  # @[ExportStorage]
  # property internal_guid : String = ""
  # ```
  #
  # #### 9. Inspector Groups, Subgroups, and Categories
  #
  # Godot's inspector supports organizing properties into collapsible groups, nested subgroups,
  # and top-level category headers. LibGodot supports both block-scoped DSL declarations and
  # sequential macro / annotation directives.
  #
  # ##### Block-Scoped Grouping DSL (Recommended)
  #
  # Wrapping exported properties inside `export_group`, `export_subgroup`, or `export_category`
  # blocks automatically scopes properties and **enforces boundary closure**:
  #
  # ```crystal
  # node Player < CharacterBody3D do
  #   # Top-level category tab:
  #   export_category "Player Systems" do
  #     # Primary collapsible group:
  #     export_group "Locomotion", prefix: "move_" do
  #       @[Export] property move_speed : Float32 = 5.0_f32
  #       @[Export] property move_acceleration : Float32 = 20.0_f32
  #
  #       # Nested subgroup with its own prefix:
  #       export_subgroup "Jump Mechanics", prefix: "jump_" do
  #         @[Export] property jump_velocity : Float32 = 8.0_f32
  #         @[Export] property jump_cut_multiplier : Float32 = 0.5_f32
  #       end
  #
  #       # Properties here are automatically back in the "Locomotion" group!
  #       @[Export] property move_friction : Float32 = 0.1_f32
  #     end
  #
  #     # Properties outside the block are cleanly un-grouped (sentinel emitted):
  #     @[Export] property active_state : String = "idle"
  #   end
  # end
  # ```
  #
  # ##### Boundary Scoping & Sentinel Emittance
  #
  # When Godot encounters a property group in `ClassDB`, all subsequent exported properties are
  # placed into that group until another group or an empty terminator is encountered.
  # LibGodot's block DSL automatically emits boundary termination sentinels (properties with empty
  # `name: ""` and `usage: 64` for groups or `usage: 256` for subgroups) upon exiting blocks,
  # ensuring that enclosing scopes and following properties are never accidentally grouped.
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Construct</th>
  #       <th>Block Syntax</th>
  #       <th>Sequential / Annotation Syntax</th>
  #       <th>Boundary Behavior</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><strong>Category</strong></td>
  #       <td><code>export_category "Name" do ... end</code></td>
  #       <td><code>export_category "Name"</code> or <code>@[ExportCategory("Name")]</code></td>
  #       <td>Emits <code>PROPERTY_USAGE_CATEGORY</code> (128). Groups following properties until next category.</td>
  #     </tr>
  #     <tr>
  #       <td><strong>Group</strong></td>
  #       <td><code>export_group "Name", prefix: "pfx_" do ... end</code></td>
  #       <td><code>export_group "Name", "pfx_"</code> or <code>@[ExportGroup("Name", "pfx_")]</code></td>
  #       <td>Emits <code>PROPERTY_USAGE_GROUP</code> (64). Block closure emits empty sentinel to restore scope.</td>
  #     </tr>
  #     <tr>
  #       <td><strong>Subgroup</strong></td>
  #       <td><code>export_subgroup "Name", prefix: "pfx_" do ... end</code></td>
  #       <td><code>export_subgroup "Name", "pfx_"</code> or <code>@[ExportSubgroup("Name", "pfx_")]</code></td>
  #       <td>Emits <code>PROPERTY_USAGE_SUBGROUP</code> (256). Block closure restores enclosing group scope.</td>
  #     </tr>
  #   </tbody>
  # </table>

  #
  # #### 10. Interactive Inspector Tool Buttons (`@[ExportToolButton]`)
  # Creates a clickable button in the Godot inspector that triggers a method or proc when pressed:
  # ```crystal
  # # 1. Method pointer tool button (idiomatic Crystal method reference, takes only no-args proc):
  # @[ExportToolButton("Regenerate World", icon: "Play")]
  # property my_button = ->some_method
  #
  # # 2. Lambda tool button:
  # @[ExportToolButton("Reset Counters")]
  # property reset_button = ->{
  #   self.health = 100
  # }
  #
  # # 3. Dynamic runtime assignable tool button:
  # @[ExportToolButton("Custom Action")]
  # property dynamic_button : Proc(Void)? = nil
  #
  # # 4. Method-based tool button (directly decorates an instance method):
  # @[ExportToolButton("Regenerate Voxel Terrain", icon: "Play")]
  # def some_method : Void
  #   Godot.print("Regenerating voxel terrain...")
  # end
  #
  # # 5. Boolean property tool button (sets property to true when pressed):
  # @[ExportToolButton("Toggle Mode")]
  # property toggle_flag : Bool = false
  # ```
  #
  # > **Note on Syntax:** In Crystal, taking a method reference is written with the arrow operator
  # > `->some_method` (or `->{ some_method }`), rather than `&some_method` (which in Crystal grammar
  # > is reserved for block arguments). Tool button procs must take no arguments (`Proc(Void)`).
  module C_EXPORTS_AND_INSPECTOR
    # Dummy method for documentation visibility
    def self.supported_types : Array(String)
      [
        "Bool", "Int32", "Int64", "Float32", "Float64",
        "String", "Vector2", "Vector3", "Color", "NodePath"
      ]
    end
  end

  # # D. Node DSL, Lifecycle & Signals
  #
  # The `node` macro is the central declarative building block in LibGodot.
  # It provides a clean, expressive DSL for authoring Godot classes in Crystal.
  #
  # ---
  #
  # ### 1. The `node` Macro Syntax
  #
  # ```crystal
  # require "libgodot"
  #
  # # Inherits from Godot::Node by default:
  # node CameraRig do
  #   # ...
  # end
  #
  # # Inherits from a specific Godot class:
  # node Player < CharacterBody3D do
  #   # ...
  # end
  #
  # # Subclassing another custom Crystal node:
  # node Warrior < Player do
  #   # ...
  # end
  # ```
  #
  # ---
  #
  # ### 2. Lifecycle Callback Dispatch
  #
  # Godot nodes execute lifecycle methods at specific stages in the frame lifecycle.
  # LibGodot automatically detects these methods at compile time and registers virtual
  # function pointers with the GDExtension bridge:
  #
  # - `def _ready : Void`
  #   Called once when the node and all of its children have entered the active scene tree.
  # - `def _process(delta : Float64) : Void`
  #   Called every visual frame. `delta` is elapsed time in seconds since previous frame.
  # - `def _physics_process(delta : Float64) : Void`
  #   Called every fixed physics step (typically 60 Hz). Used for physics movement and simulation.
  #
  # Virtual method calls are dispatched directly from the C++ bridge via `call_virtual`,
  # bypassing Variant reflection for maximum execution speed.
  #
  # ---
  #
  # ### 3. Type-Safe Signal System
  #
  # Signals allow nodes to notify observers when state changes occur, decoupled from listeners:
  #
  # ```crystal
  # node BossEnemy < CharacterBody3D do
  #   # Define signals with typed arguments:
  #   signal phase_changed(new_phase : Int32)
  #   signal health_updated(current : Int32, max_health : Int32)
  #   signal defeated
  #
  #   def take_damage(amount : Int32) : Void
  #     @health -= amount
  #     emit_health_updated(@health, @max_health)
  #     if @health <= 0
  #       emit_defeated
  #     end
  #   end
  # end
  # ```
  #
  # Under the hood:
  # 1. The `signal` declaration is harvested at compile time.
  # 2. A `CrystalSignalDesc` entry is registered into Godot's `ClassDB`.
  # 3. A type-safe emission helper method (`emit_<signal_name>(...)`) is generated.
  # 4. Arguments are converted into `CrystalSignalArg` buffers and dispatched via
  #    `Bridge.object_emit_signal`.
  # 5. GDScript, C#, and other Crystal nodes can connect to these signals natively.
  #
  # ---
  #
  # ### 4. Scene Tree APIs
  #
  # Custom nodes have access to Godot's scene tree hierarchy methods:
  # - `add_child(node, force_readable_name = false, internal = 0)`: Adds child to this node.
  # - `remove_child(node)`: Removes a child node without freeing it.
  # - `reparent(new_parent, keep_global_transform = true)`: Moves node to a new parent in one call.
  # - `get_parent : Node` / `get_parent? : Node?`: Returns parent or nil if orphan.
  # - `get_child_count : Int64`: Returns the count of child nodes.
  # - `get_child(idx) : Node` / `get_child?(idx) : Node?`: Retrieves child by index.
  # - `find_child(pattern, recursive = true, owned = false) : Node?`: Searches hierarchy by name.
  # - `queue_free : Void`: Queues the node for clean deletion at the end of the frame.
  # - `is_inside_tree : Bool`: Checks if the node is in the active scene tree.
  # - `instantiate : Node`: Unpacks a `PackedScene` into an active node hierarchy.
  #
  # ---
  #
  # ### 5. In-Editor Tool Scripts (`@[Tool]` or `tool`)
  #
  # Adding `@[Tool]` or invoking `tool` inside a node instructs Godot to run the node
  # inside the **Godot Editor** in real time:
  # ```crystal
  # @[Tool]
  # node ProceduralArchway < Node3D do
  #   @[Export]
  #   property radius : Float32 = 5.0_f32
  #
  #   def _process(delta : Float64) : Void
  #     # Runs inside Godot Editor! Updates visual mesh when radius changes.
  #   end
  # end
  # ```
  #
  # ---
  #
  # ### 6. Network Replication (`@[RPC]`)
  #
  # Methods marked with `@[RPC]` configure multiplayer network replication:
  # ```crystal
  # @[RPC(mode: :any_peer, call_local: true)]
  # def sync_position(pos : Vector3) : Void
  #   self.position = pos
  # end
  # ```
  module D_NODE_DSL_AND_SIGNALS
    # Dummy method for documentation visibility
    def self.lifecycle_methods : Array(String)
      ["_ready", "_process(delta : Float64)", "_physics_process(delta : Float64)"]
    end
  end

  # # E. Doc Comments & Editor Help XML Generation
  #
  # One of the most powerful features of LibGodot is its **automated compile-time
  # documentation harvesting system**. Standard Crystal doc comments (`# ...`) written
  # above classes, properties, signals, and methods are automatically parsed and registered
  # into Godot's offline `EditorHelp` documentation subsystem.
  #
  # ---
  #
  # ### How Doc Comments Flow from Crystal to Godot
  #
  # ```
  # Crystal Source Code (# Comments)
  #          │
  #          ▼ (Compile time: node macro read_file)
  # Dynamic XML Generation (<class>, <members>, <signals>)
  #          │
  #          ▼ (crystal_godot_init)
  # EditorDocRegistry.load_all
  #          │
  #          ▼ (Bridge: GDExtensionEditorHelp::load_xml_buffer)
  # Godot Editor Inspector Tooltips & F1 Help Page
  # ```
  #
  # 1. At compile time, the `node` macro executes `read_file(block.filename)`.
  # 2. It scans lines immediately preceding:
  #    - The `node ClassName` definition (class brief & full description)
  #    - Each `property` declaration (property doc comment)
  #    - Each `signal` declaration (signal description)
  #    - Each `def` method (method description)
  # 3. An in-memory XML string matching Godot's official `DocData` specification is synthesized:
  #    ```xml
  #    <?xml version="1.0" encoding="UTF-8" ?>
  #    <class name="SpinningCrystal" inherits="Area3D">
  #      <brief_description>Collectible item that rotates in 3D space</brief_description>
  #      <description>Collectible item that rotates in 3D space</description>
  #      <members>
  #        <member name="rotation_speed" type="float">Rotation rate in rad/s</member>
  #      </members>
  #      <signals>
  #        <signal name="collected">
  #          <description>Emitted when a character collects this item</description>
  #        </signal>
  #      </signals>
  #    </class>
  #    ```
  # 4. During library initialization (`crystal_godot_init`), `EditorDocRegistry.load_all`
  #    hands each XML document to `Bridge.load_editor_help(xml)`.
  # 5. The bridge invokes Godot's `GDExtensionEditorHelp::load_xml_buffer`.
  # 6. Inside the Godot Editor:
  #    - Hovering over a property in the **Inspector** displays the exact Crystal doc comment.
  #    - Pressing **F1** (Search Help) lists your custom Crystal classes alongside native Godot nodes.
  #
  # ---
  #
  # ### Example Code
  #
  # ```crystal
  # # Floating power-up item that rotates and restores player health
  # node HealthPotion < Area3D do
  #   # Amount of health points restored upon pickup
  #   @[Export(range: 5..100, step: 5)]
  #   property heal_amount : Int32 = 25
  #
  #   # Emitted when a player body consumes this potion
  #   signal consumed(player : Node3D)
  #
  #   # Triggers consumption of the health potion
  #   def consume!(player : Node3D) : Void
  #     emit_consumed(player)
  #     queue_free
  #   end
  # end
  # ```
  module E_DOC_COMMENTS_AND_HELP
    # Dummy method for documentation visibility
    def self.schema : String
      "Godot DocData XML format (<class>, <brief_description>, <members>, <signals>, <methods>)"
    end
  end

  # # F. GDScript Interoperability & Automated Project Bindings
  #
  # LibGodot includes automated compile-time interoperability with GDScript, generating strongly
  # typed Crystal wrapper classes directly from your project's custom GDScript nodes and scenes.
  #
  # ---
  #
  # ### Automated Compile-Time Binding (`make project_bindings`)
  #
  # Custom GDScript nodes (declared with `class_name` and extending Godot node types) are automatically
  # introspected at compile time by Godot in headless mode (`dump_project_nodes.gd`). The binding generator
  # (`generate_project_bindings.cr`) creates typed Crystal classes in `src/generated/project_nodes/`:
  #
  # ```crystal
  # # Automatically generated wrapper:
  # # module Godot
  # #   class QuestTracker < Godot::Node
  # #     def self.from(node : Godot::Object) : self
  # #     def award_experience(points : Int64) : Int64
  # #     def get_current_quest_title : String
  # #     def active_quest_id : String
  # #     def active_quest_id=(val : String) : Void
  # #     def quest_completed : Godot::BoundSignal
  # #   end
  # # end
  #
  # # Crystal usage:
  # tracker = Godot::QuestTracker.from(quest_node)
  # tracker.award_experience(500_i64)
  # Godot.print("Active Quest: #{tracker.active_quest_id}")
  # tracker.active_quest_id = "QUEST_002"
  # ```
  #
  # ---
  #
  # ### How Variant Marshaling Works
  #
  # 1. When calling an auto-bound GDScript method, Crystal passes typed arguments through the GDExtension
  #    bridge argument marshaller.
  # 2. It dispatches the call through Godot's `object_call` / `object_call_ret_*` C-API.
  # 3. Return values are unmarshaled back into native Crystal types (`String`, `Int64`, `Float64`,
  #    `Bool`, `Godot::Object`).
  # 4. Native variant resources are automatically lifecycle-managed to prevent memory leaks.
  module F_GDSCRIPT_INTEROP
    # Dummy method for documentation visibility
    def self.features : Array(String)
      ["automated_ast_introspection", "typed_project_bindings", "typed_properties", "typed_signals", "variant_marshaling"]
    end
  end

  # # G. Engine Caveats, Memory & Internals
  #
  # When building high-performance games with LibGodot, developers should be aware of several
  # critical architectural nuances spanning garbage collection, memory ownership, and threading.
  #
  # ---
  #
  # ### 1. Memory Ownership: Boehm GC vs. Godot Reference Counting
  #
  # LibGodot bridges two distinct memory models:
  # - **Crystal's Boehm GC**: Manages memory allocated on the Crystal heap (strings, arrays,
  #   class instances, fibers).
  # - **Godot Engine C++ Heap**: Manages engine nodes, resources, and scenes using manual
  #   lifecycle (`Node` with `queue_free`) or reference counting (`RefCounted` / `Resource`).
  #
  # #### Critical Rules:
  # 1. **Never store raw pointers to freed Godot nodes**: When a node is destroyed in Godot
  #    (e.g. via `queue_free`), its underlying C++ memory is deallocated. A Crystal wrapper
  #    object (`Godot::Node`) holding that pointer will become invalid. Check `is_queued_for_deletion`
  #    or null pointers before dereferencing cached node references.
  # 2. **GC Roots in Shared Libraries**: On Windows, when `game.dll` is dynamically loaded
  #    by Godot, static Crystal variables and method bindings are registered as GC roots.
  #    Always ensure large static data structures are cleared during `crystal_godot_cleanup`.
  #
  # ---
  #
  # ### 2. Thread Safety & Thread Affinity
  #
  # Godot executes rendering, physics, and main loop processing on different threads:
  # - **Main Thread**: Scene tree operations (`add_child`, `remove_child`, UI updates)
  #   **MUST** occur on the main thread. Attempting to modify the active scene tree from a
  #   background Crystal fiber will cause race conditions inside Godot's internal node lists.
  # - **Physics Thread**: `_physics_process(delta)` is invoked during the fixed physics tick.
  #   Safe for kinematic movement (`move_and_slide`, velocity calculation), but avoid
  #   instantiating full scene trees here unless synchronized.
  # - **Deferred Calls**: Use `Godot.call_deferred` to safely marshal background fiber
  #   work back onto Godot's main event thread.
  #
  # ---
  #
  # ### 3. Method Bind Pointer Caching (`@@mb_*`)
  #
  # Invoking Godot methods through `Variant` reflection (`Object.call`) involves string hash lookups
  # and boxing/unboxing overhead.
  #
  # To achieve near-native C++ performance:
  # - LibGodot retrieves the raw method bind pointer via `Bridge.get_method_bind(class, method, hash)`
  #   and caches it inside a class variable (`@@mb_node_add_child`).
  # - Subsequent calls use `Bridge.ptrcall`, which executes a direct C function pointer call with
  #   arguments passed as an array of raw pointers (`Void**`), incurring zero reflection overhead.
  #
  # ---
  #
  # ### 4. Windows Toolchain & Runtime Nuances
  #
  # - **Compiler Consistency**: The loader bridge is compiled with MinGW-w64 `g++` on Windows.
  #   Crystal's LLVM toolchain targets MSVCRT / UCRT. The bridge exposes a pure C-ABI table
  #   (`extern "C"`), eliminating C++ name mangling or standard library incompatibility issues.
  # - **DLL Export Tables**: Exported functions (`crystal_library_init`, `crystal_godot_init`)
  #   are explicitly decorated with `__declspec(dllexport)` on Windows and `visibility("default")`
  #   on Linux.
  # - **Shadow Copies**: When testing or modifying game code in the editor, never manually delete
  #   active `game_loaded_*.dll` files while Godot is open; the OS will release them when Godot
  #   terminates, and the bridge will automatically clean them up.
  module G_CAVEATS_AND_INTERNALS
    # Dummy method for documentation visibility
    def self.caveats : Array(String)
      [
        "Scene tree modifications must stay on the main thread",
        "Godot Node queue_free invalidates C++ pointers; check validity before reuse",
        "Method binds are cached statically for zero-cost ptrcall dispatch",
        "Never delete active shadow copies while Godot is running"
      ]
    end
  end

  # # H. Lifecycle, Memory Management & Dead-Pointer Safety
  #
  # In a modern multi-language game engine architecture where GDScript, C++, and Crystal interact
  # dynamically, object lifecycles can be terminated unpredictably from any environment.
  # LibGodot provides a robust, defense-in-depth safety architecture designed to guarantee
  # zero memory leaks and eliminate catastrophic segmentation faults caused by dangling pointers.
  #
  # ---
  #
  # ### 1. Dual Memory Architecture
  #
  # LibGodot bridges two completely independent memory management models operating simultaneously:
  #
  # 1. **Crystal's Boehm Garbage Collector (GC)**:
  #    - Allocates and manages all Crystal memory (class wrappers, structs, strings, arrays, fibers).
  #    - Periodically scans the Crystal stack and heap to collect unreferenced Crystal objects.
  #    - Crystal `Godot::Object` instances hold a raw C++ memory pointer (`@pointer : Void*`) and
  #      a cached 64-bit instance ID (`@instance_id : UInt64`) pointing to the underlying Godot instance.
  #    - When a Crystal wrapper becomes unreachable, Boehm GC frees the wrapper object. However,
  #      garbage collection of the wrapper does **not** deallocate the underlying Godot engine object,
  #      because the engine entity may still be active in the scene tree or referenced by GDScript!
  #
  # 2. **Godot Engine's Native Memory & ObjectDB**:
  #    - Native Godot objects are allocated on the engine C++ heap via `memnew(T)`.
  #    - Every living `Godot::Object` receives a unique, globally monotonic 64-bit ID
  #      assigned by Godot's internal `ObjectDB`.
  #    - `Node` instances follow a scene-tree ownership lifecycle: parent nodes own children,
  #      and deletion occurs either immediately via `node.free()` / `memdelete(node)` or deferred
  #      at the end of the current frame via `node.queue_free()`.
  #    - `RefCounted` and `Resource` instances follow atomic reference counting (`reference()`,
  #      `unreference()`) and are deallocated automatically by the engine when their reference count
  #      drops to zero.
  #
  # ---
  #
  # ### 2. The "Dangling Pointer / Disposed Object" Hazard
  #
  # In unshielded GDExtension or C-API language bindings, a critical hazard arises when an object
  # is deleted outside of Crystal's direct knowledge:
  #
  # ```text
  # [ Crystal Runtime ]                          [ Godot Engine / GDScript ]
  #   enemy = get_node("Enemy")
  #   enemy.@pointer = 0x7FFE_1234  -------->     Node instance at 0x7FFE_1234
  #                                                   |
  #                                                   | GDScript: enemy.queue_free()
  #                                                   v
  #                                                ObjectDB destroys Node & frees memory!
  #                                                0x7FFE_1234 is now DEAD / UNMAPPED!
  #   enemy.position = Vector2.new(...)
  #         |
  #         v
  #   Dereferences 0x7FFE_1234
  #   ==> ACCESS_VIOLATION / SIGSEGV
  #   ==> TOTAL CRASH (Process Killed)
  # ```
  #
  # In unshielded bindings, the next time Crystal tries to access that object (e.g. reading
  # `enemy.position`, calling `enemy.name`, or invoking a method), the CPU dereferences a
  # dead memory address, resulting in an immediate, fatal **segmentation fault (ACCESS_VIOLATION)**
  # that crashes the entire game process with zero diagnostic traceback.
  #
  # ---
  #
  # ### 3. How LibGodot Prevents Crashes: Instance ID & ObjectDB Validation
  #
  # To make LibGodot completely resilient against cross-language deletion hazards:
  #
  # 1. **Automatic Instance ID Registration**:
  #    Whenever a `Godot::Object` wrapper is instantiated in Crystal (via `Godot.create`,
  #    `get_node`, reflection, or callback parameters), Crystal queries the native engine:
  #    ```crystal
  #    @instance_id = Bridge.object_get_instance_id(@pointer)
  #    ```
  # 2. **ObjectDB Liveness Verification**:
  #    Before executing any reflection, method call, or ptrcall dispatch, LibGodot calls `#check_alive!`.
  #    This helper queries Godot's internal `ObjectDB` via `Bridge.is_instance_valid(@instance_id)`.
  #    Because `ObjectDB` assigns monotonically increasing 64-bit IDs, even if newly allocated memory
  #    happens to share the old memory address on the C++ heap, the instance ID will **never** collide.
  # 3. **The `DisposedObjectError` Exception**:
  #    If the native Godot object was destroyed on the GDScript side, in the engine, or via
  #    a prior `queue_free()`, `check_alive!` immediately marks the wrapper dead (`@pointer = Pointer(Void).null`)
  #    and raises a clean, catchable Crystal exception:
  #    ```crystal
  #    raise Godot::DisposedObjectError.new(@instance_id)
  #    ```
  #    This transforms what would have been an unavoidable process crash into a standard,
  #    traceable Crystal exception that developers can catch, log, or handle gracefully!
  #
  # ---
  #
  # ### 4. Concrete Implications & Developer Guidelines
  #
  # Understanding this architecture is critical for writing robust Godot games and extensions in Crystal:
  #
  # #### A. Performance Implications of ObjectDB Checks
  # - Godot's `ObjectDB::get_instance(id)` is an extremely fast O(1) hash lookup with spinlock protection.
  # - LibGodot's `#check_alive!` executes this check only when invoking method dispatches and hierarchy
  #   operations on Godot objects.
  # - The minuscule overhead (~5-10 nanoseconds) pays dividends by completely eliminating native crashes
  #   in production games and during hot-reloading in the editor.
  #
  # #### B. Defensive Programming: Checking `alive?` and `is_valid?`
  # When caching references to transient entities (such as projectiles, enemies, or UI dialogs),
  # check `#alive?` before operating on them:
  #
  # ```crystal
  # if target_node.alive?
  #   target_node.position = new_pos
  # else
  #   # Cleanly prune target from our tracking list without raising an exception
  #   active_targets.delete(target_node)
  # end
  # ```
  #
  # #### C. Nil-Coalescing with `if_alive` & Safe Collider Queries
  # To avoid explicit boilerplate checks, use `#if_alive` or typed queries like `get_collider?`:
  #
  # ```crystal
  # # Returns self if alive in ObjectDB, or nil if uninitialized, null, or destroyed:
  # if live_target = maybe_target.if_alive
  #   live_target.position = new_pos
  # end
  #
  # # RayCast3D / ShapeCast3D return Godot::Object? directly:
  # if col = shapecast.get_collider?
  #   Godot.print("Hit collider: #{col}")
  # end
  # ```
  #
  # #### D. Engine Value Equality (`==`) and Hashing (`hash`)
  # `Godot::Object` implements value equality based on Godot's 64-bit instance ID (or native pointer).
  # Distinct Crystal wrapper instances representing the same engine object compare equal:
  #
  # ```crystal
  # obj_a == obj_b      # => true if both refer to the same Godot entity
  # null_obj == nil     # => true if underlying engine pointer is null
  # nil == null_obj     # => true (symmetric nil equality)
  # set = Set(Godot::Object).new
  # set.add(obj_a)
  # set.add(obj_b)
  # set.size            # => 1 (properly deduplicated)
  # ```
  #
  # #### E. Handling Disposed Objects with `rescue`
  # If code interacts with arbitrary or external nodes passed from GDScript, you can catch
  # `Godot::DisposedObjectError` at system boundaries:
  #
  # ```crystal
  # begin
  #   untrusted_node.do_something
  # rescue ex : Godot::DisposedObjectError
  #   Godot.print_warn "Encountered dead node (ID: #{ex.instance_id}); skipping operation."
  # end
  # ```
  #
  # #### D. Lifecycle Rules for Nodes vs RefCounted
  # - **Nodes Added to the Scene Tree**: Owned by the scene tree. Do **NOT** call `.destroy` manually
  #   on a parented node; use `node.queue_free` to let Godot safely deallocate it at the end of the frame.
  # - **Standalone Nodes**: If you create a node via `Godot.create(Godot::Node2D)` and never add it
  #   to the scene tree, you **MUST** call `node.destroy` when done with it to prevent a native memory leak!
  # - **RefCounted & Resources**: Managed automatically by Godot's reference counter. If you create a
  #   `Resource` or `RefCounted` object and keep it in Crystal, call `ref_counted.reference` and
  #   `ref_counted.unreference` to participate in reference counting, or allow LibGodot's built-in
  #   lifecycle helpers to manage it.
  #
  # #### E. Quantitative Memory Leak Prevention
  # To verify that Crystal and Godot properly deallocate memory across all operations:
  # - Godot exposes the `Performance` singleton monitors:
  #   - `Performance::OBJECT_COUNT` (Total active engine objects)
  #   - `Performance::OBJECT_NODE_COUNT` (Total active nodes in memory)
  #   - `Performance::MEMORY_STATIC` (Total static engine heap memory in bytes)
  # - In the LibGodot test suite, thousands of nodes and resources are spawned, linked,
  #   unlinked, and destroyed, followed by explicit calls to `GC.collect` in Crystal.
  #   The monitors verify that object counts and static memory return to baseline,
  #   proving zero memory leaks.
  module H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY
    def self.features : Array(String)
      [
        "Monotonic 64-bit ObjectDB instance ID tracking",
        "Zero-crash DisposedObjectError on access to freed engine objects",
        "O(1) alive? and is_valid? inspection helpers",
        "Atomic RefCounted reference tracking with zero leaks",
        "Quantitative Performance monitor leak verification"
      ]
    end
  end

  # # I. Concurrency, Threading & Memory Architecture
  #
  # This section provides a comprehensive architectural guide on Crystal's concurrency models
  # (Fibers, Channels, Mutexes, and Multi-Threading) and how they integrate safely with the Godot Engine 4.x runtime.
  #
  # ---
  #
  # ### 1. Executive Summary & Core Rules
  #
  # 1. **SceneTree is Strictly Single-Threaded**:
  #    Never invoke `add_child`, `remove_child`, `reparent`, or `queue_free` from a background thread or fiber.
  #    Modifying the active scene hierarchy outside Godot's Main Thread causes memory corruption and engine crashes.
  # 2. **Cooperative Fibers Require Yield Points**:
  #    Godot controls the OS main loop. Spawned fibers (`spawn do ... end`) will not execute unless the main
  #    thread cooperatively yields via `Fiber.yield` in `_process(delta)`.
  # 3. **Avoid Blocking Sleep in Fibers**:
  #    Standard `sleep(duration)` relies on Crystal's event loop (LibEvent / IOCP), which is not pumped by
  #    Godot's host process. Use Godot's `get_tree.create_timer(duration)` or delta accumulators instead.
  # 4. **Use `Channel(T)` for Background Processing (Actor Pattern)**:
  #    Offload CPU-intensive tasks to background worker threads (`Thread.new`). Workers push results to a
  #    `Channel(T)`, and the Main Thread drains the channel non-blockingly during `_process(delta)`.
  # 5. **Cross-Thread Method Dispatch**:
  #    When background threads need to notify Godot nodes, use `node.call_deferred("method_name", *args)`.
  #    Godot buffers deferred calls into its thread-safe `MessageQueue` and dispatches them on the main thread
  #    during the next frame.
  #
  # ---
  #
  # ### 2. Crystal Concurrency Models vs. Godot Engine Architecture
  #
  # #### Concurrency Matrix
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Feature</th>
  #       <th>Crystal Mechanism</th>
  #       <th>Godot Threading Model</th>
  #       <th>Potential Hazard</th>
  #       <th>Solution / Best Practice</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><strong>Fibers</strong></td>
  #       <td>M:1 cooperative coroutines; lightweight stacks.</td>
  #       <td>Godot Main Thread runs engine iterations.</td>
  #       <td>Fibers starve if main loop never yields; blocking <code>sleep</code> hangs.</td>
  #       <td>Call <code>Fiber.yield</code> in <code>_process</code>; use frame deltas instead of <code>sleep</code>.</td>
  #     </tr>
  #     <tr>
  #       <td><strong>OS Threads (<code>Thread.new</code>)</strong></td>
  #       <td>1:1 kernel threads; registered with Boehm GC.</td>
  #       <td>Godot spawns Server &amp; Worker threads.</td>
  #       <td>Race conditions in Crystal data structures; off-thread Node access.</td>
  #       <td>Protect shared state with <code>::Thread::Mutex</code>; pass data via <code>Channel(T)</code>.</td>
  #     </tr>
  #     <tr>
  #       <td><strong>Multi-Threading (<code>-Dpreview_mt</code>)</strong></td>
  #       <td>M:N fibers across <code>CRYSTAL_WORKERS</code> threads; work stealing.</td>
  #       <td>Godot multithreaded rendering/physics.</td>
  #       <td>Concurrent access to <code>@@alive_instances</code> or global caches.</td>
  #       <td>Bridge uses <code>::Thread::Mutex</code> for <code>alive_instances</code>; confine SceneTree to Main Thread.</td>
  #     </tr>
  #     <tr>
  #       <td><strong>Channels (<code>Channel(T)</code>)</strong></td>
  #       <td>CSP message passing with thread-safe mutex and queue.</td>
  #       <td>Single-threaded Main Loop.</td>
  #       <td>Deadlock if blocking <code>receive</code> is called on the Main Thread.</td>
  #       <td>Use non-blocking <code>receive?</code> or select polling in <code>_process</code>.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # ### 3. Execution Contexts & Thread-Local Storage (TLS)
  #
  # #### Main Thread vs. Foreign Engine Threads
  # - **Main Thread Initialization**:
  #   When Godot loads `game.dll`, Godot invokes `crystal_godot_init` on the **Main Thread**. Crystal
  #   initializes its runtime (`Crystal.init_runtime`), sets up main thread TLS (`Thread.current`,
  #   `Fiber.current`), and boots the Boehm GC (`GC.init`).
  # - **Foreign Engine Threads (WorkerThreadPool / Audio / Physics)**:
  #   Godot creates worker threads natively in C++.
  #   - If a foreign engine thread directly calls an exported Crystal C callback, Crystal's TLS
  #     (`Thread.current`, `Fiber.current`) is uninitialized.
  #   - Raising an exception or attempting fiber operations on an unregistered foreign thread can
  #     trigger an immediate **Access Violation / Segmentation Fault (0xC0000005 / SIGSEGV)**.
  #   - **Rule**: All GDExtension class lifecycle methods (`_ready`, `_process`, exported properties)
  #     must be dispatched from the Main Thread.
  #
  # ---
  #
  # ### 4. Boehm Garbage Collector (BDWGC) Under Concurrency
  #
  # #### 1. Stack Scanning & Thread Registration
  # - Boehm GC stops the world and scans the call stacks of all registered threads to identify root pointers.
  # - Threads created through Crystal's `Thread.new` are automatically registered with BDWGC.
  # - If an unregistered thread executes Crystal code and allocates heap memory (e.g. strings, arrays, objects),
  #   BDWGC cannot scan its stack. Live objects held only on that stack could be prematurely freed, resulting
  #   in **silent heap corruption or use-after-free**.
  #
  # #### 2. Stop-The-World (STW) Pauses
  # - During a GC collection, BDWGC halts all registered threads (using `SuspendThread` on Windows or signals on POSIX).
  # - To minimize GC pause times in 60 FPS / 120 FPS games:
  #   - Avoid allocating temporary heap objects inside `_process` or `_physics_process`.
  #   - Use value types (`struct Vector2`, `struct Vector3`, `struct Transform3D`).
  #   - Pre-allocate arrays and reuse object pools.
  #
  # #### 3. Instance Rooting & Thread-Safe Registry
  # In `src/libgodot/bridge.cr`, the bridge maintains `@@alive_instances` (`Hash(Void*, Godot::Object)`) to root
  # active Crystal nodes and prevent premature GC deallocation.
  # - `Bridge.alive_instances` is protected by `Bridge.alive_mutex` (`Thread::Mutex.new`).
  # - Registration (`register_alive_instance`) and unregistration (`unregister_alive_instance`) are 100%
  #   thread-safe against concurrent scene deserialization or background worker instantiations.
  #
  # ---
  #
  # ### 5. Recommended Architecture: The 3-Tier Concurrency Model
  #
  # #### Tier 1: Cooperative Main-Thread Fibers (Gameplay & UI)
  # Best for gameplay scripts, cutscenes, state machines, and dialog systems.
  #
  # ```crystal
  # class QuestManager < Godot::Node
  #   def _ready
  #     # Spawn a cooperative gameplay sequence
  #     spawn do
  #       Godot.print "Quest started!"
  #       # Wait 3 seconds using Godot SceneTreeTimer
  #       get_tree.create_timer(3.0)
  #       Godot.print "3 seconds elapsed, advancing quest!"
  #     end
  #   end
  #
  #   def _process(delta : Float64)
  #     # Grant cooperative execution slices to spawned fibers
  #     Fiber.yield
  #   end
  # end
  # ```
  #
  # #### Tier 2: Background Workers + Channel Message Passing (Actor Pattern)
  # Best for procedural generation, pathfinding grids, network requests, and heavy math.
  #
  # ```crystal
  # class WorldGenerator < Godot::Node
  #   @result_channel = Channel(Array(Godot::Vector3)).new(1)
  #   @worker : Thread? = nil
  #
  #   def start_generation
  #     @worker = Thread.new do
  #       # Heavy background computation off-thread
  #       points = Array(Godot::Vector3).new
  #       100_000.times do |i|
  #         points << Godot::Vector3.new(i.to_f32, 0.0_f32, i.to_f32)
  #       end
  #       # Send immutable data back to main thread
  #       @result_channel.send(points)
  #     end
  #   end
  #
  #   def _process(delta : Float64)
  #     # Non-blocking poll on main thread
  #     select
  #     when points = @result_channel.receive
  #       apply_world_mesh(points)
  #     else
  #       # Work still in progress
  #     end
  #   end
  #
  #   private def apply_world_mesh(points : Array(Godot::Vector3))
  #     # Safe to mutate SceneTree here on Main Thread!
  #     Godot.print "Received #{points.size} points from background worker!"
  #   end
  # end
  # ```
  #
  # #### Tier 3: Thread-Safe Deferred Dispatch (`call_deferred`)
  # Best for fire-and-forget notifications from background threads to engine objects.
  #
  # ```crystal
  # Thread.new do
  #   # Do background work...
  #   result = compute_heavy_score()
  #
  #   # Safely marshal back to Godot Main Thread via MessageQueue
  #   hud_node.call_deferred("update_score", result)
  # end
  # ```
  #
  # ---
  #
  # ### 6. Anti-Patterns & Common Pitfalls
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Anti-Pattern</th>
  #       <th>Why It Fails</th>
  #       <th>Correct Approach</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>node.add_child(c)</code> inside <code>Thread.new</code></td>
  #       <td>SceneTree is not thread-safe. Causes race condition in Godot child list.</td>
  #       <td>Marshal to main thread using <code>Channel(T)</code> or <code>call_deferred</code>.</td>
  #     </tr>
  #     <tr>
  #       <td><code>sleep(1.second)</code> inside a <code>spawn</code> fiber</td>
  #       <td>Crystal event loop is not pumped by Godot; fiber sleeps indefinitely.</td>
  #       <td>Use <code>get_tree.create_timer(1.0)</code> or frame delta accumulators.</td>
  #     </tr>
  #     <tr>
  #       <td><code>sleep(duration)</code> inside <code>Thread.new</code></td>
  #       <td>Top-level <code>sleep</code> yields a fiber to an <code>ExecutionContext</code>; raw threads lack context, raising <code>NilAssertionError: Fiber#execution_context cannot be nil</code>.</td>
  #       <td>Use <code>Crystal::System::Thread.sleep(duration)</code> for true OS thread sleeps.</td>
  #     </tr>
  #     <tr>
  #       <td>Unsynchronized global state (<code>@@my_cache[k] = v</code>)</td>
  #       <td>Crystal <code>Hash</code> and <code>Array</code> are not thread-safe under concurrent writes.</td>
  #       <td>Wrap access in <code>::Thread::Mutex.new</code> (<code>mutex.synchronize { ... }</code>).</td>
  #     </tr>
  #     <tr>
  #       <td>Keeping raw pointers to freed objects</td>
  #       <td>Accessing deleted C++ memory causes undefined behavior.</td>
  #       <td>Use monotonic instance IDs and check <code>is_valid?</code> or catch <code>DisposedObjectError</code>.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # #### Anti-Pattern 1: SceneTree Mutation from Background Threads
  #
  # Modifying Godot's active scene hierarchy (`add_child`, `remove_child`, `reparent`, `queue_free`)
  # from a background thread or fiber causes memory corruption in engine child vectors.
  #
  # ##### Bad Code:
  # ```crystal
  # # BAD: Calling add_child directly from an OS background thread
  # Thread.new do
  #   new_enemy = Godot.create(Godot::Node2D)
  #   new_enemy.name = "OffThreadEnemy"
  #   parent_node.add_child(new_enemy) # CRASH: SceneTree race condition in engine child list!
  # end
  # ```
  #
  # ##### Good Code (Approach A — Channel to Main Thread):
  # ```crystal
  # # GOOD: Compute off-thread, instantiate and add on Main Thread via Channel
  # class Spawner < Godot::Node
  #   @spawn_channel = Channel(String).new(10)
  #
  #   def spawn_async
  #     Thread.new do
  #       enemy_data = compute_enemy_stats()
  #       @spawn_channel.send(enemy_data)
  #     end
  #   end
  #
  #   def _process(delta : Float64)
  #     select
  #     when enemy_data = @spawn_channel.receive
  #       enemy = Godot.create(Godot::Node2D)
  #       enemy.name = enemy_data
  #       add_child(enemy) # SAFE: Executed on Godot Main Thread!
  #     else
  #       # No new spawn events this frame
  #     end
  #   end
  # end
  # ```
  #
  # ##### Good Code (Approach B — `call_deferred`):
  # ```crystal
  # # GOOD: Use call_deferred to safely marshal node attachment to the Main Thread
  # Thread.new do
  #   new_enemy = Godot.create(Godot::Node2D)
  #   new_enemy.name = "DeferredEnemy"
  #   parent_node.call_deferred("add_child", new_enemy) # SAFE: Routed through thread-safe MessageQueue!
  # end
  # ```
  #
  # ---
  #
  # #### Anti-Pattern 2: Blocking `sleep` Inside a `spawn` Cooperative Fiber
  #
  # In standard standalone Crystal programs, `sleep` registers with the event loop. In Godot GDExtension,
  # Godot owns the main loop and does not pump Crystal's event loop. Calling `sleep(1.second)` inside a
  # fiber on the main thread causes the fiber to suspend indefinitely.
  #
  # ##### Bad Code:
  # ```crystal
  # # BAD: Calling sleep inside a spawned fiber in GDExtension
  # spawn do
  #   Godot.print "Quest Step 1"
  #   sleep 2.seconds # HANG: Crystal event loop is not pumped by Godot!
  #   Godot.print "Quest Step 2" # NEVER REACHED!
  # end
  # ```
  #
  # ##### Good Code:
  # ```crystal
  # # GOOD: Use Godot's SceneTreeTimer or delta accumulators with Fiber.yield
  # class QuestSequencer < Godot::Node
  #   def start_quest
  #     spawn do
  #       Godot.print "Quest Step 1"
  #       timer = get_tree.create_timer(2.0)
  #       while timer.time_left > 0.0
  #         Fiber.yield # Cooperatively yield execution slices
  #       end
  #       Godot.print "Quest Step 2 reached safely!"
  #     end
  #   end
  #
  #   def _process(delta : Float64)
  #     Fiber.yield # Grant execution slices to spawned fibers each frame
  #   end
  # end
  # ```
  #
  # ---
  #
  # #### Anti-Pattern 3: Calling Fiber `sleep` Inside a Raw OS `Thread.new`
  #
  # In Crystal 1.20+, top-level `sleep` yields the current fiber to an `ExecutionContext`.
  # Raw OS threads created with `Thread.new` do not run inside an `ExecutionContext`, causing an
  # immediate runtime exception: `NilAssertionError: Fiber#execution_context cannot be nil`.
  #
  # ##### Bad Code:
  # ```crystal
  # # BAD: Calling top-level sleep inside an OS thread
  # Thread.new do
  #   10.times do
  #     sleep 10.milliseconds # CRASH: NilAssertionError: Fiber#execution_context cannot be nil!
  #   end
  # end
  # ```
  #
  # ##### Good Code:
  # ```crystal
  # # GOOD: Use Crystal::System::Thread.sleep for genuine OS thread sleeps
  # Thread.new do
  #   10.times do
  #     Crystal::System::Thread.sleep 10.milliseconds # SAFE: Native OS kernel sleep!
  #   end
  # end
  # ```
  #
  # ---
  #
  # #### Anti-Pattern 4: Unsynchronized Shared Mutable State Across Threads
  #
  # Crystal's standard `Hash` and `Array` collections are not thread-safe. Concurrent mutations
  # corrupt internal hash buckets, cause infinite loops, or trigger memory access violations.
  # Furthermore, using Crystal's standard `Mutex` alias (`Sync::Mutex`) from a raw thread fails under
  # contention because `Sync::Mutex` suspends fibers via `ExecutionContext`. Always use `::Thread::Mutex`.
  #
  # ##### Bad Code:
  # ```crystal
  # # BAD: Modifying shared Hash from multiple threads without synchronization
  # class ScoreCache
  #   @@scores = Hash(String, Int32).new
  #
  #   def self.record(player_id : String, score : Int32)
  #     Thread.new do
  #       @@scores[player_id] = score # CORRUPTION: Data race on Hash buckets!
  #     end
  #   end
  # end
  # ```
  #
  # ##### Good Code:
  # ```crystal
  # # GOOD: Protect shared mutable collections with ::Thread::Mutex
  # class ScoreCache
  #   @@scores = Hash(String, Int32).new
  #   @@mutex = ::Thread::Mutex.new # OS kernel mutex (CRITICAL_SECTION / pthread_mutex)
  #
  #   def self.record(player_id : String, score : Int32)
  #     Thread.new do
  #       @@mutex.synchronize do
  #         @@scores[player_id] = score # SAFE: Atomic and thread-safe!
  #       end
  #     end
  #   end
  #
  #   def self.get(player_id : String) : Int32?
  #     @@mutex.synchronize do
  #       @@scores[player_id]?
  #     end
  #   end
  # end
  # ```
  #
  # ---
  #
  # #### Anti-Pattern 5: Retaining Raw Pointers to Freed Engine Objects
  #
  # When a Godot object is destroyed (via GDScript `queue_free()`, `target.free()`, or engine scene reload),
  # the underlying C++ heap memory is deallocated. Calling methods on an unvalidated wrapper invokes
  # undefined behavior and native crashes (`0xC0000005`).
  #
  # ##### Bad Code:
  # ```crystal
  # # BAD: Holding node references without checking engine liveness
  # class CombatTracker
  #   property cached_target : Godot::Node2D? = nil
  #
  #   def attack_target
  #     if target = @cached_target
  #       # If target was freed by GDScript via queue_free(), calling methods crashes!
  #       target.call("apply_damage", 25) # CRASH: ACCESS_VIOLATION / SIGSEGV!
  #     end
  #   end
  # end
  # ```
  #
  # ##### Good Code:
  # ```crystal
  # # GOOD: Validate engine liveness with alive? or catch DisposedObjectError
  # class CombatTracker
  #   property cached_target : Godot::Node2D? = nil
  #
  #   def attack_target
  #     if target = @cached_target
  #       if target.alive? # Checks ObjectDB 64-bit instance validity in O(1)
  #         target.call("apply_damage", 25)
  #       else
  #         @cached_target = nil # Clean up dead reference
  #       end
  #     end
  #   rescue ex : Godot::DisposedObjectError
  #     Godot.print_warn "Target was disposed: #{ex.message}"
  #     @cached_target = nil
  #   end
  # end
  # ```
  #
  # ---
  #
  # ### 7. Awaiting Signals and Timers: The `await` Pattern
  #
  # In Godot, asynchronous sequencing for cutscenes, dialogue, animations, and cooldowns
  # is customarily performed using GDScript's `await` keyword.
  #
  # LibGodot provides a first-class, type-safe **`await`** system designed for Crystal's
  # cooperative fibers. It provides two fully supported signal awaiting styles:
  # 1. **First-Class Bound Signals (`await(enemy.died)` or `enemy.died.await`)**:
  #    Synthesized automatically by the `signal` macro and `Godot::Object#signal`. Provides compile-time checking,
  #    IDE auto-completion, and direct `.connect` / `.emit` methods.
  # 2. **Classic Target & String Identifier (`await(enemy, "died")` or `enemy.await_signal("died")`)**:
  #    The traditional Godot pattern. Indispensable when signal names are computed dynamically at runtime
  #    (e.g., from network RPC packets, configuration files, or GDScript dynamic events).
  # 3. **SceneTreeTimers (`await(timer.timeout)` or `await(timer)`)**.
  # 4. **Cooperative Durations (`await(2.5)` or `await(3.seconds)`)**.
  #
  # #### Comparison: GDScript vs. LibGodot Crystal
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Operation</th>
  #       <th>GDScript</th>
  #       <th>LibGodot Crystal</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><strong>Await Signal (Bound)</strong></td>
  #       <td><code>await target.died</code></td>
  #       <td><code>await(target.died)</code> or <code>target.died.await</code></td>
  #     </tr>
  #     <tr>
  #       <td><strong>Await Signal (Classic String)</strong></td>
  #       <td><code>await target.died</code></td>
  #       <td><code>await(target, "died")</code> or <code>target.await_signal("died")</code></td>
  #     </tr>
  #     <tr>
  #       <td><strong>Await with Arguments</strong></td>
  #       <td><code>var health = await player.health_changed</code></td>
  #       <td><code>args = await(player.health_changed)</code> or <code>await(player, "health_changed")</code></td>
  #     </tr>
  #     <tr>
  #       <td><strong>Await Timer</strong></td>
  #       <td><code>await get_tree().create_timer(2.0).timeout</code></td>
  #       <td><code>await(get_tree.create_timer(2.0).timeout)</code> or <code>await(timer)</code></td>
  #     </tr>
  #     <tr>
  #       <td><strong>Await Duration</strong></td>
  #       <td><code>await get_tree().create_timer(1.5).timeout</code></td>
  #       <td><code>await(1.5)</code> or <code>await(1.5.seconds)</code></td>
  #     </tr>
  #     <tr>
  #       <td><strong>Await with Timeout</strong></td>
  #       <td>Manual timer racing</td>
  #       <td><code>await(target.died, timeout_sec: 5.0)</code> or <code>await(target, "event", timeout_sec: 5.0)</code></td>
  #     </tr>
  #     <tr>
  #       <td><strong>Connect Directly</strong></td>
  #       <td><code>target.died.connect(...)</code></td>
  #       <td><code>target.died.connect { |args| ... }</code> or <code>target.connect("died", callback)</code></td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # #### Comprehensive Cutscene & Gameplay Example
  #
  # The following example demonstrates a Boss battle cinematic sequence authoring
  # cooperative fibers, signal emissions, timer awaits, and dead-pointer safety:
  #
  # ```crystal
  # node BossFightController < Godot::Node do
  #   @[Export]
  #   property cutscene_speed : Float32 = 1.0_f32
  #
  #   signal battle_started
  #   signal battle_won
  #
  #   def _ready : Void
  #     # Launch cutscene sequence in a cooperative fiber
  #     spawn do
  #       run_intro_cinematic
  #     end
  #   end
  #
  #   def _process(delta : Float64) : Void
  #     # CRITICAL: Cooperatively yield execution slices each frame to advance awaiting fibers!
  #     Fiber.yield
  #   end
  #
  #   private def run_intro_cinematic : Void
  #     Godot.print("Cinematic starting: Camera pan...")
  #     # 1. Non-blocking delay: wait 2.0 seconds for camera transition
  #     await(2.0)
  #
  #     Godot.print("Spawn Boss entity...")
  #     boss = get_node_as(Godot::CharacterBody3D, "Boss")
  #
  #     # 2. Await a SceneTreeTimer via .timeout bound signal
  #     await(get_tree.create_timer(1.5).timeout)
  #     Godot.print("Boss roaring animation finished!")
  #
  #     emit_battle_started
  #
  #     # 3. Await custom signal on boss using first-class BoundSignal syntax
  #     begin
  #       Godot.print("Awaiting boss defeat signal...")
  #       # Returns Array(String) of signal arguments (e.g. loot drop ID, score)
  #       args = await(boss.boss_defeated, timeout_sec: 120.0)
  #       Godot.print("Victory! Boss dropped rewards: #{args}")
  #       emit_battle_won
  #     rescue ex : Godot::DisposedObjectError
  #       Godot.print_warn("Boss was prematurely destroyed: #{ex.message}")
  #     end
  #   end
  # end
  # ```
  #
  # ---
  #
  # #### Dead-Pointer Safety During `await`
  #
  # In dynamic multi-language games, an entity being awaited could be freed prematurely
  # by GDScript (e.g. `enemy.queue_free()`) or engine level unloading.
  #
  # LibGodot's `await` validates `#alive?` on every frame slice:
  # - If the target is destroyed while a fiber is awaiting its signal, `await` immediately raises
  #   `Godot::DisposedObjectError.new(target.instance_id)`.
  # - This guarantees that awaiting fibers **never hang indefinitely** on dead objects and cannot
  #   trigger native segmentation faults.
  #
  #
  module I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY
    def self.best_practices : Array(String)
      [
        "Yield cooperatively (Fiber.yield) in _process to advance background fibers",
        "Use Channel(T) to marshal data from background worker threads to the main thread",
        "Never mutate SceneTree nodes (add_child/remove_child) from background threads",
        "Use call_deferred for cross-thread method dispatch to engine objects",
        "Avoid blocking sleep in fibers; prefer Godot SceneTreeTimer or delta accumulators",
        "Use Crystal::System::Thread.sleep for true OS thread sleeps inside Thread.new",
        "Protect shared Crystal state across threads with ::Thread::Mutex or Atomic primitives"
      ]
    end
  end

  # ### J. First-Class Crystal Scripts (.cr) in Godot
  #
  # LibGodot establishes `.cr` (Crystal) script files as **first-class citizens** in the Godot 4 Editor,
  # matching the native workflow of GDScript and C#.
  #
  # #### Architecture Overview
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Component</th>
  #       <th>Implementation</th>
  #       <th>Purpose</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><strong>CrystalLanguage</strong></td>
  #       <td><code>Godot::CrystalLanguage &lt; ScriptLanguageExtension</code></td>
  #       <td>Registers language name, extension, templates, and code completion in <code>ScriptServer</code></td>
  #     </tr>
  #     <tr>
  #       <td><strong>CrystalScript</strong></td>
  #       <td><code>Godot::CrystalScript &lt; ScriptExtension</code></td>
  #       <td>Represents <code>.cr</code> files as Godot Script resources, exposing Inspector properties</td>
  #     </tr>
  #     <tr>
  #       <td><strong>ResourceFormatLoader</strong></td>
  #       <td><code>Godot::ResourceFormatLoaderCrystal</code></td>
  #       <td>Enables Godot's FileSystem dock and ResourceLoader to load <code>.cr</code> files directly</td>
  #     </tr>
  #     <tr>
  #       <td><strong>ResourceFormatSaver</strong></td>
  #       <td><code>Godot::ResourceFormatSaverCrystal</code></td>
  #       <td>Persists modifications in the Godot Script Editor back to <code>.cr</code> files on disk (Ctrl+S)</td>
  #     </tr>
  #     <tr>
  #       <td><strong>CrystalSyntaxHighlighter</strong></td>
  #       <td><code>Godot::CrystalHighlighter &lt; EditorSyntaxHighlighter</code></td>
  #       <td>High-performance, zero-dependency tokenizer coloring keywords, types, annotations, symbols, and comments</td>
  #     </tr>
  #     <tr>
  #       <td><strong>LSP Worker</strong></td>
  #       <td><code>Godot::CrystalLSP</code></td>
  #       <td>Sandboxed background bridge for optional Crystalline language server diagnostics</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # #### 1. Built-in Script Editor Tab
  #
  # Double-clicking any `.cr` file in the Godot FileSystem dock opens the file directly inside
  # the engine's built-in **Script** workspace tab.
  # - **Zero External Dependencies**: Syntax highlighting operates independently of external daemons.
  # - **Theme Integration**: Highlights match the active Godot Editor theme colors.
  # - **Instant Save**: Pressing **Ctrl+S** in the script editor invokes `ResourceFormatSaverCrystal`, saving the file to disk.
  # - **F5 Fast Build**: Pressing **F5** automatically compiles Crystal source code into `game.dll` and reloads.
  #
  # ---
  #
  # #### 2. Inspector Property Reflection
  #
  # Nodes with attached `.cr` scripts display exported properties directly inside the Godot Inspector dock:
  # ```crystal
  # require "libgodot"
  #
  # node Player < CharacterBody2D do
  #   @[Export(range: 50.0_f32..1000.0_f32, step: 10.0_f32)]
  #   property speed : Float32 = 300.0_f32
  #
  #   @[Export(range: 10..500, step: 5)]
  #   property max_health : Int32 = 100
  #
  #   signal health_changed(current : Int32, max_health : Int32)
  #   signal died
  # end
  # ```
  #
  # When selected in the scene tree:
  # - `speed` renders as a numeric slider clamped between 50 and 1000 with step 10.
  # - `max_health` renders as an integer spinner.
  # - `health_changed` and `died` appear in the Node Signals dock.
  #
  # ---
  #
  # #### 3. Sandboxed Language Server (Crystalline)
  #
  # While built-in code completion and syntax highlighting function out-of-the-box,
  # LibGodot integrates the official `crystalline` Language Server Protocol daemon:
  # - Auto-detects `crystalline` binary in `PATH`, local `bin/`, or Lapis install directory.
  # - Bundled directly into `{app}\bin` via the Windows installer (`lapis-setup-windows-x86_64.exe`).
  # - Available via GitHub releases or automatically downloaded via `lapis setup --lsp` and `scripts/windows/install_deps.ps1`.
  # - Sandboxed in a protected background worker; if Crystalline crashes or errors, it fails gracefully without interrupting the editor.
  #
  module J_FIRST_CLASS_CRYSTAL_SCRIPTS
    def self.features : Array(String)
      [
        "Direct .cr file opening in Godot built-in Script Editor tab",
        "Pure-Crystal high-performance syntax highlighter (EditorSyntaxHighlighter)",
        "Zero-compile AST reflection for immediate Inspector property display",
        "ResourceFormatLoader and ResourceFormatSaver for seamless FileSystem and save integration",
        "Built-in code completion and symbol lookup via ScriptLanguageExtension",
        "Guarded, fail-safe Crystalline LSP daemon integration",
        "F5 / Play automatic build and shadow DLL hot reload"
      ]
    end
  end

  # # K. Concurrency, Channels & Engine Ergonomics
  #
  # LibGodot bridges Crystal's fiber and thread models with Godot's multi-threaded
  # engine architecture. This module details the actor concurrency primitives,
  # thread safety invariants, and language ergonomics available to developers.
  #
  # ---
  #
  # ### 1. GodotChannel (Actor Concurrency)
  #
  # `Godot::Channel` (registered in Godot's `ClassDB` as `GodotChannel`) is a
  # thread-safe, bounded or unbounded actor channel that can be passed between
  # Crystal and Godot/GDScript:
  #
  # ```crystal
  # # Inside Crystal:
  # channel = Godot::Channel.new(capacity: 16)
  #
  # # Spawn OS worker thread to crunch math:
  # Thread.new do
  #   result = compute_heavy_simulation()
  #   channel.send(result)
  # end
  #
  # # In Crystal fiber or _process:
  # if item = channel.try_receive
  #   apply_simulation(item)
  # end
  # ```
  #
  # In GDScript, `GodotChannel` emits `signal received` when data is sent,
  # allowing non-blocking reactive awaits:
  #
  # ```gdscript
  # # Inside GDScript:
  # func _ready():
  #     var channel = GodotChannel.new(16)
  #     # Asynchronously wait for data from Crystal worker
  #     var data = await channel.received
  #     print("Worker returned: ", data)
  # ```
  #
  # ---
  #
  # ### 2. Concurrency Safety Rules
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Runtime Context</th>
  #       <th>Allowed Operations</th>
  #       <th>Forbidden Operations</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><strong>Godot Main Thread</strong></td>
  #       <td>SceneTree mutations, node creation/destruction, <code>try_receive</code>, <code>await_receive</code></td>
  #       <td>Blocking <code>receive()</code> (freezes window message pumping)</td>
  #     </tr>
  #     <tr>
  #       <td><strong>Crystal Fibers (spawn)</strong></td>
  #       <td><code>await(signal)</code>, <code>await(timer)</code>, <code>delay(sec)</code>, <code>next_frame</code></td>
  #       <td>Top-level blocking <code>sleep(sec)</code></td>
  #     </tr>
  #     <tr>
  #       <td><strong>Background OS Threads</strong></td>
  #       <td>Heavy computation, <code>channel.send</code>, <code>call_deferred</code>, blocking <code>receive</code></td>
  #       <td>Direct SceneTree manipulation (<code>add_child</code>, <code>queue_free</code>)</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # ### 3. Resource & RefCounted DSL
  #
  # In addition to the `node` macro, developers can declare custom Godot Resources
  # and RefCounted objects with `@export` properties:
  #
  # ```crystal
  # resource ItemStats < Resource do
  #   @[Export]
  #   property damage : Int32 = 10
  #
  #   @[Export]
  #   property rarity : String = "Legendary"
  # end
  #
  # gdclass StateMachine < RefCounted do
  #   @[Export]
  #   property current_state : String = "idle"
  # end
  # ```
  #
  # ---
  #
  # ### 4. Engine Async Helpers
  #
  # - `Godot.next_frame`: Cooperatively yields execution until the next render/process frame.
  # - `Godot.physics_frame`: Cooperatively yields execution until the next physics step.
  # - `Godot.delay(seconds)`: Pauses execution for the given duration without halting the engine.
  # - `Godot.spawn(&block)`: Spawns an exception-guarded cooperative fiber.
  #
  # ---
  #
  # ### 5. Collections Interoperability
  #
  # - `Godot::Dictionary` wraps Godot dictionaries and converts to/from Crystal `Hash` via `hash.to_godot_dict` and `dict.to_h`.
  # - `Godot::Array(T)` wraps Godot arrays with full `Enumerable` support and converts via `array.to_godot_array` and `arr.to_a`.
  #
  module K_CONCURRENCY_CHANNELS_AND_ERGONOMICS
    def self.features : Array(String)
      [
        "Thread-safe GodotChannel exposed to GDScript as RefCounted",
        "Reactive signal received emission on Main Thread via call_deferred",
        "Non-blocking try_receive and cooperative fiber await_receive",
        "resource and gdclass DSL macros for custom Resources and RefCounted objects",
        "Engine async helpers: Godot.next_frame, Godot.physics_frame, Godot.delay, Godot.spawn",
        "Godot::Dictionary and Godot::Array wrappers with Enumerable and Crystal conversions"
      ]
    end
  end

  # ## Macro DSL Reference & In-Editor Reflection Manual
  #
  # LibGodot provides a expressive, compile-time checked Domain Specific Language (DSL)
  # for declaring Godot engine classes, resources, refcounted objects, inspector exports,
  # signals, RPC endpoints, and editor tools.
  #
  # All macros expand into native Godot `ClassDB` registrations during library initialization
  # without runtime reflection overhead.
  #
  # ---
  #
  # ### 1. Class Declaration Macros
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Macro</th>
  #       <th>Default Superclass</th>
  #       <th>Zero-Block Syntax</th>
  #       <th>Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>node Name &lt; Parent do ... end</code></td>
  #       <td><code>Godot::Node</code></td>
  #       <td><code>node Name</code> or <code>node Name &lt; Parent</code></td>
  #       <td>Declares a scene graph Node class exposed to Godot's ClassDB.</td>
  #     </tr>
  #     <tr>
  #       <td><code>resource Name &lt; Parent do ... end</code></td>
  #       <td><code>Resource</code></td>
  #       <td><code>resource Name</code> or <code>resource Name &lt; Parent</code></td>
  #       <td>Declares a serializable Godot Resource class (.tres / .res).</td>
  #     </tr>
  #     <tr>
  #       <td><code>gdclass Name &lt; Parent do ... end</code></td>
  #       <td><code>RefCounted</code></td>
  #       <td><code>gdclass Name</code> or <code>gdclass Name &lt; Parent</code></td>
  #       <td>Declares a reference-counted engine class managed by ObjectDB.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # #### Syntax Examples
  #
  # ```crystal
  # require "libgodot"
  #
  # # 1. Node with explicit parent and block
  # node PlayerController < CharacterBody3D do
  #   @[Export]
  #   property speed : Float32 = 7.5_f32
  #
  #   def _physics_process(delta : Float64) : Void
  #     # Movement code
  #   end
  # end
  #
  # # 2. Zero-block node inheriting default Godot::Node
  # node WorldManager
  #
  # # 3. Zero-block node with explicit parent
  # node CustomCamera < Camera3D
  #
  # # 4. Resource inheriting default Resource
  # resource InventoryItem do
  #   @[Export]
  #   property item_name : String = "Health Potion"
  #
  #   @[Export]
  #   property power : Int32 = 50
  # end
  #
  # # 5. Zero-block resource defaulting to Resource
  # resource QuestData
  #
  # # 6. RefCounted class using gdclass
  # gdclass StateMachine do
  #   property state : String = "idle"
  # end
  #
  # # 7. RefCounted class using gdclass (zero-block)
  # gdclass DataPacket
  # ```
  #
  # ---
  #
  # ### 2. Property Export Annotations
  #
  # Export annotations configure how Crystal properties are presented in the Godot Inspector,
  # serialized to disk (.tscn / .tres), and exposed to GDScript.
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Annotation</th>
  #       <th>Arguments</th>
  #       <th>Inspector Widget</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>@[Export]</code></td>
  #       <td>None</td>
  #       <td>Standard typed editor (number, string, color, vector)</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportRange]</code></td>
  #       <td><code>min..max, step: n, or_greater: bool, or_less: bool</code></td>
  #       <td>Numeric slider bar with bounds and step increments</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportEnum]</code></td>
  #       <td><code>EnumType</code></td>
  #       <td>Dropdown selection list of named enum values</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportFile]</code></td>
  #       <td><code>filter: "*.png,*.jpg"</code></td>
  #       <td>File system picker dialog with extension filter</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportDir]</code></td>
  #       <td>None</td>
  #       <td>Directory path picker dialog</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportMultiline]</code></td>
  #       <td>None</td>
  #       <td>Multi-line expandable text area</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportPlaceholder]</code></td>
  #       <td><code>text: "Placeholder..."</code></td>
  #       <td>Text field with gray placeholder text when empty</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportColorNoAlpha]</code></td>
  #       <td>None</td>
  #       <td>Color picker with alpha/opacity channel locked at 1.0</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportExpEasing]</code></td>
  #       <td><code>attenuation: bool, positive_only: bool</code></td>
  #       <td>Interactive exponential easing curve visualization widget</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportNodePath]</code></td>
  #       <td><code>type: "Camera3D"</code></td>
  #       <td>NodePath picker constrained to matching node types in scene</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportFlags]</code></td>
  #       <td><code>FlagEnumType</code></td>
  #       <td>Multi-select checkbox list for bitfield flags</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportFlags2DRender]</code></td>
  #       <td>None</td>
  #       <td>Godot 2D render layer visibility bitmask checkboxes</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportFlags2DPhysics]</code></td>
  #       <td>None</td>
  #       <td>Godot 2D physics collision layer bitmask checkboxes</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportFlags3DPhysics]</code></td>
  #       <td>None</td>
  #       <td>Godot 3D physics collision layer bitmask checkboxes</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportGroup]</code></td>
  #       <td><code>name: "Combat", prefix: "combat_"</code></td>
  #       <td>Collapsible category grouping header in Inspector</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportSubgroup]</code></td>
  #       <td><code>name: "Defenses", prefix: "combat_def_"</code></td>
  #       <td>Nested subcategory header within an inspector group</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportStorage]</code></td>
  #       <td>None</td>
  #       <td>Serialized with scene/resource but hidden from the Inspector</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[ExportToolButton]</code></td>
  #       <td><code>text: "Execute Action", icon: "res://icon.png"</code></td>
  #       <td>Clickable push button rendered directly in the Inspector</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # #### Export Example
  #
  # ```crystal
  # enum CharacterClass
  #   Warrior = 1
  #   Mage    = 2
  #   Rogue   = 4
  # end
  #
  # node Hero < CharacterBody2D do
  #   @[ExportGroup("Attributes", prefix: "attr_")]
  #   @[ExportRange(1..100, step: 1)]
  #   property attr_level : Int32 = 1
  #
  #   @[ExportEnum(CharacterClass)]
  #   property attr_hero_class : CharacterClass = CharacterClass::Warrior
  #
  #   @[ExportGroup("Media", prefix: "media_")]
  #   @[ExportFile("*.png,*.tres")]
  #   property media_avatar : String = "res://avatar.png"
  #
  #   @[ExportColorNoAlpha]
  #   property theme_color : Godot::Color = Godot::Color.new(0.2, 0.6, 1.0, 1.0)
  #
  #   @[ExportToolButton("Recalculate Stats")]
  #   def recalculate_stats : Void
  #     Godot.print("Recalculating stats for level #{attr_level}...")
  #   end
  # end
  # ```
  #
  # ---
  #
  # ### 3. Signal Declaration & Ergonomic Listeners
  #
  # Signals connect nodes loosely across Crystal, GDScript, and C++.
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Declaration</th>
  #       <th>Generated Emission Method</th>
  #       <th>Generated Listener</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>signal died</code></td>
  #       <td><code>emit_died</code></td>
  #       <td><code>on_died { ... }</code>, <code>on_died_once { ... }</code></td>
  #     </tr>
  #     <tr>
  #       <td><code>signal damage_taken(amount : Int32, source : String)</code></td>
  #       <td><code>emit_damage_taken(amount, source)</code></td>
  #       <td><code>on_damage_taken { |amt, src| ... }</code></td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # #### First-Class Signal Awaiting
  #
  # ```crystal
  # # Await bound signal directly:
  # await(hero.died, timeout_sec: 10.0)
  # hero.died.await(timeout_sec: 10.0)
  #
  # # Await by string name:
  # await(hero, "damage_taken", timeout_sec: 5.0)
  # hero.await_signal("damage_taken", timeout_sec: 5.0)
  # ```
  #
  # ---
  #
  # ### 4. Behavioral & Execution Directives
  #
  # <table>
  #   <thead>
  #     <tr>
  #       <th>Directive</th>
  #       <th>Scope</th>
  #       <th>Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr>
  #       <td><code>@[Tool]</code> or <code>tool</code></td>
  #       <td>Class level</td>
  #       <td>Enables execution inside the Godot Editor in real time (for gizmos, previews, tool buttons).</td>
  #     </tr>
  #     <tr>
  #       <td><code>@[RPC]</code></td>
  #       <td>Method level</td>
  #       <td>Configures multiplayer network replication (call_local, mode, channel).</td>
  #     </tr>
  #     <tr>
  #       <td><code>onready name : Type = path</code></td>
  #       <td>Property level</td>
  #       <td>Lazy node lookup evaluated during <code>_ready</code>.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  module L_MACRO_DSL_REFERENCE
    def self.features : Array(String)
      [
        "node macro for scene nodes defaulting to Godot::Node",
        "resource macro for custom resources defaulting to Resource",
        "gdclass macro for RefCounted engine classes",
        "Complete @[Export] annotations: ranges, enums, files, flags, groups, buttons",
        "Type-safe signal emission, ergonomic on_<signal> listeners, and first-class await",
        "@[Tool] in-editor execution, @[RPC] networking, and onready lazy node binding"
      ]
    end
  end

  # ===========================================================================
  # Guide M: Native LLDB In-Editor Debugging, Tool Scripts & Multiplayer Sessions
  # ===========================================================================
  #
  # LibGodot integrates **LLDB** directly into the Godot Editor's native Debugger dock,
  # enabling in-editor breakpoints, interactive command consoles, stack traces,
  # multiplayer multi-session coordination, and guidance for debugging live tool scripts.
  #
  # ---
  #
  # ### 1. Prerequisite Tooling
  #
  # Because Crystal's compiler is built directly on **LLVM**, LLDB natively parses
  # both Microsoft `.pdb` (Program Database) files on Windows and DWARF debug info
  # on Linux and macOS without external symbol converters.
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Platform</th>
  #       <th style="padding: 10px 14px;">Package Manager</th>
  #       <th style="padding: 10px 14px;">Installation Command</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Windows</strong></td>
  #       <td style="padding: 10px 14px;">Scoop / WinGet</td>
  #       <td style="padding: 10px 14px;"><code>scoop install llvm</code> or <code>winget install LLVM.LLVM</code></td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Ubuntu / Debian</strong></td>
  #       <td style="padding: 10px 14px;">APT</td>
  #       <td style="padding: 10px 14px;"><code>sudo apt install lldb</code></td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Arch Linux</strong></td>
  #       <td style="padding: 10px 14px;">Pacman</td>
  #       <td style="padding: 10px 14px;"><code>sudo pacman -S lldb</code></td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>macOS</strong></td>
  #       <td style="padding: 10px 14px;">Homebrew / Xcode</td>
  #       <td style="padding: 10px 14px;"><code>brew install llvm</code> or <code>xcode-select --install</code></td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # Verify installation from your terminal:
  # ```bash
  # lldb --version
  # ```
  #
  # ---
  #
  # ### 2. Native Debug Symbols & Compilation
  #
  # When compiling in development mode (`make all` or pressing **F5** in the editor),
  # Crystal emits full debug symbols (`--debug`):
  # - **Windows**: Produces `bin/game.pdb` (Microsoft Program Database). LLDB reads this
  #   directly to map machine instructions to Crystal source files and line numbers.
  # - **Linux / macOS**: Produces standard DWARF debug info embedded within `game.so` or `game.dylib`.
  #
  # ---
  #
  # ### 3. In-Editor Breakpoint Synchronization & Navigation
  #
  # 1. Open any Crystal source file (e.g. `src/player.cr`) in Godot's Script Editor.
  # 2. Click the gutter next to any line number to set a red breakpoint marker.
  # 3. Godot's <code>EditorDebuggerPlugin._breakpoint_set_in_tree</code> intercepts the event,
  #    translates <code>res://</code> paths to absolute filesystem paths, and pushes
  #    <code>breakpoint set --file &lt;file&gt; --line &lt;line&gt;</code> to all active LLDB sessions.
  # 4. When execution hits the breakpoint, the Godot Script Editor automatically navigates
  #    to the file and line, highlighting the current execution frame.
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Control</th>
  #       <th style="padding: 10px 14px;">Shortcut</th>
  #       <th style="padding: 10px 14px;">Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Continue</strong></td>
  #       <td style="padding: 10px 14px;"><code>F5</code></td>
  #       <td style="padding: 10px 14px;">Resumes process execution until the next breakpoint or signal.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Step Over</strong></td>
  #       <td style="padding: 10px 14px;"><code>F10</code></td>
  #       <td style="padding: 10px 14px;">Executes the current line without stepping inside function calls.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Step Into</strong></td>
  #       <td style="padding: 10px 14px;"><code>F11</code></td>
  #       <td style="padding: 10px 14px;">Steps into the method or function called on the current line.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Step Out</strong></td>
  #       <td style="padding: 10px 14px;"><code>Shift + F11</code></td>
  #       <td style="padding: 10px 14px;">Finishes executing the current function and returns to the caller.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Pause</strong></td>
  #       <td style="padding: 10px 14px;">—</td>
  #       <td style="padding: 10px 14px;">Interrupts execution immediately via <code>process interrupt</code>.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # ### 4. Multiplayer Multi-Session Coordination & Lockstep Break Mode
  #
  # When running multiple game instances simultaneously in the Godot Editor (via
  # <strong>Debug &gt; Run Multiple Instances</strong>):
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Feature</th>
  #       <th style="padding: 10px 14px;">Mechanic</th>
  #       <th style="padding: 10px 14px;">Multiplayer Benefit</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Per-Session Isolation</strong></td>
  #       <td style="padding: 10px 14px;">Each instance connects to its own independent LLDB controller bound to that child PID.</td>
  #       <td style="padding: 10px 14px;">Prevents breakpoints or inspect commands in Client 1 from interfering with Server or Client 2.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Role Badging</strong></td>
  #       <td style="padding: 10px 14px;">Instances report their multiplayer role (<code>Server</code>, <code>Client 1</code>, etc.) on startup.</td>
  #       <td style="padding: 10px 14px;">Developers immediately know which debugger tab corresponds to which game window.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Lockstep Break Mode</strong></td>
  #       <td style="padding: 10px 14px;">When any peer hits a breakpoint, all other peers are cooperatively interrupted via <code>process interrupt</code>.</td>
  #       <td style="padding: 10px 14px;">Eliminates network heartbeat timeout disconnections and physics state desynchronization.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # ### 5. Tool Scripts (`@[Tool]`) Debugging Architecture
  #
  # Developers frequently ask: *"If I set a breakpoint in a tool script, will it trigger?"*
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Context</th>
  #       <th style="padding: 10px 14px;">Will Breakpoint Trigger in Editor Tab?</th>
  #       <th style="padding: 10px 14px;">Reason</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Running Game Project</strong> (F5 / F6)</td>
  #       <td style="padding: 10px 14px;"><strong>YES</strong></td>
  #       <td style="padding: 10px 14px;">The tool script runs inside the spawned child game process where LLDB is actively attached.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Live In-Editor Viewport / Inspector</strong></td>
  #       <td style="padding: 10px 14px;"><strong>NO</strong></td>
  #       <td style="padding: 10px 14px;">The script executes inside the parent Godot Editor process, not a child game process.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # #### Why In-Editor Execution Does Not Trigger in the In-Editor Tab:
  #
  # 1. **Target Process Boundary**:
  #    When working inside the editor (e.g. custom docks, inspectors, editor gizmos, or `_process` running in the 2D/3D viewport),
  #    that code executes **inside the host Godot Editor process itself** (`godot.exe`), rather than in a child game process.
  #    Godot's `EditorDebuggerPlugin` only opens debug sessions when you launch game scenes.
  #
  # 2. **The Host Deadlock Paradox (Native vs Interpreted Execution)**:
  #    Unlike GDScript, which runs in an interpreted virtual machine and can pause execution within its own bytecode loop,
  #    Crystal compiles to native machine code. Native breakpoints trigger OS-level interrupts (`SIGTRAP` / `int 3`).
  #    Because the in-editor debugger tab and UI controls run on the Godot Editor's own GUI thread:
  #    - If the in-editor LLDB attached to the editor process itself, hitting a breakpoint would freeze the entire Godot Editor window.
  #    - The editor would be unable to process mouse clicks or keyboard events, making it impossible to click **Continue**, **Step**, or view the call stack in the debugger panel!
  #
  # ---
  #
  # ### 6. How to Debug Live Tool Scripts with an External Debugger
  #
  # If you need to step through a `@[Tool]` script executing inside the editor itself (such as a custom inspector plugin,
  # dock UI, or tool script logic running in the editor viewport), attach an **external debugger** to the Godot Editor process.
  #
  # #### Option A: External Terminal LLDB
  # Launch the Godot Editor directly under LLDB in an independent terminal window:
  # ```bash
  # lldb -- godot.exe --editor --path test
  # (lldb) breakpoint set -f tool_tester_2d.cr -l 42
  # (lldb) run
  # ```
  # Or attach to an already-running editor instance by its Process ID:
  # ```bash
  # lldb -p <godot_editor_pid>
  # ```
  #
  # #### Option B: VS Code with CodeLLDB Extension
  # Add a launch target to `.vscode/launch.json` in your project root:
  # ```json
  # {
  #   "version": "0.2.0",
  #   "configurations": [
  #     {
  #       "name": "Debug Live Editor Tool Scripts",
  #       "type": "lldb",
  #       "request": "launch",
  #       "program": "${workspaceFolder}/godot.exe",
  #       "args": ["--editor", "--path", "${workspaceFolder}/test"],
  #       "cwd": "${workspaceFolder}"
  #     },
  #     {
  #       "name": "Attach to Godot Editor (PID)",
  #       "type": "lldb",
  #       "request": "attach",
  #       "pid": "${command:pickProcess}"
  #     }
  #   ]
  # }
  # ```
  # In this workflow, the external VS Code or terminal window maintains control while the Godot Editor window is safely paused.
  #
  # ---
  #
  # ### 7. Interactive LLDB Console Commands Reference
  #
  # Inside the in-editor **Crystal LLDB** tab console, you can enter native LLDB commands directly:
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Command</th>
  #       <th style="padding: 10px 14px;">Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>thread backtrace</code> (or <code>bt</code>)</td>
  #       <td style="padding: 10px 14px;">Prints the entire call stack for the current thread.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>frame variable</code> (or <code>v</code>)</td>
  #       <td style="padding: 10px 14px;">Displays all local variables in the current stack frame.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>expression &lt;expr&gt;</code> (or <code>p</code>)</td>
  #       <td style="padding: 10px 14px;">Evaluates an arbitrary expression or inspects memory.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>breakpoint list</code></td>
  #       <td style="padding: 10px 14px;">Lists all active breakpoints and hit counts.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>process status</code></td>
  #       <td style="padding: 10px 14px;">Shows the current execution state, stop reason, and thread ID.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  module M_LLDB_NATIVE_DEBUGGING_GUIDE
    def self.features : Array(String)
      [
        "First-class LLDB native debugger integration via EditorDebuggerPlugin",
        "Direct PDB symbol parsing on Windows and DWARF on Linux/macOS",
        "Gutter breakpoint synchronization from Godot Script Editor",
        "Interactive LLDB command console inside Godot Debugger dock",
        "Multiplayer multi-session tabs with Server/Client role identification",
        "Multiplayer Lockstep Break mode to prevent network heartbeat timeouts"
      ]
    end
  end

  # # N. Godot Engine Upgrade Guide
  #
  # LibGodot supports rapid updating to newer Godot Engine dev and stable releases.
  #
  # ---
  #
  # ### Upgrade Steps
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Step</th>
  #       <th style="padding: 10px 14px;">Command / Action</th>
  #       <th style="padding: 10px 14px;">Description</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>1. Execute Setup</strong></td>
  #       <td style="padding: 10px 14px;"><code>lapis setup -v &lt;ver&gt;</code></td>
  #       <td style="padding: 10px 14px;">Downloads binary, replaces <code>godot.exe</code>, dumps <code>extension_api.json</code> and <code>gdextension_interface.h</code>.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>2. Rebuild All</strong></td>
  #       <td style="padding: 10px 14px;"><code>make all</code></td>
  #       <td style="padding: 10px 14px;">Recompiles GDExtension bridge, test suite, templates, examples, and synchronizes all binaries.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>3. Verify Tests</strong></td>
  #       <td style="padding: 10px 14px;"><code>lapis test</code></td>
  #       <td style="padding: 10px 14px;">Runs headless unit specs, in-editor tool tests, and quantitative memory leak verification.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  module N_GODOT_UPGRADE_GUIDE
    def self.features : Array(String)
      [
        "Automated setup tool via lapis setup",
        "Single-source version tracking via godot-version.yml",
        "Automatic GDExtension API and interface header dumping into rsrc/",
        "Workspace-wide synchronization and verification via make all"
      ]
    end
  end

  # # O. Low-Latency Input & Responsive Controls Guide
  #
  # LibGodot provides zero-overhead, highly responsive input handling across both event-driven
  # virtual callbacks and high-frequency polling APIs.
  #
  # ---
  #
  # ### 1. Event-Driven Input vs. Polling
  #
  # For high-frequency, responsive inputs like mouse look and twitch keypresses, rely on
  # virtual event callbacks (`_unhandled_input` or `_input`) rather than polling in `_process`:
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Paradigm</th>
  #       <th style="padding: 10px 14px;">Method / API</th>
  #       <th style="padding: 10px 14px;">Latency &amp; Characteristics</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Event Dispatch (Recommended for Mouse)</strong></td>
  #       <td style="padding: 10px 14px;"><code>def _unhandled_input(event : Godot::InputEvent)</code></td>
  #       <td style="padding: 10px 14px;">Sub-millisecond immediate dispatch. Delivers raw mouse relative delta without filtering or frame delays.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Vector Polling (Recommended for Movement)</strong></td>
  #       <td style="padding: 10px 14px;"><code>Godot::Input.get_vector(neg_x, pos_x, neg_y, pos_y)</code></td>
  #       <td style="padding: 10px 14px;">Runs single native engine dispatch with deadzone handling. Zero allocations per frame.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><strong>Velocity Polling (Avoid for Mouse Look)</strong></td>
  #       <td style="padding: 10px 14px;"><code>Godot.input.get_last_mouse_velocity * delta</code></td>
  #       <td style="padding: 10px 14px;"><strong>Warning:</strong> Godot applies an internal low-pass decay filter, introducing 2-3 frames of perceptible inertia and lag.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # ### 2. First-Class Virtual Input Callbacks
  #
  # Declare input callbacks inside any `node` class. LibGodot automatically registers
  # the virtual call table entries and wraps native pointers into typed `InputEvent` subclasses:
  #
  # ```crystal
  # node PlayerController < CharacterBody3D do
  #   property mouse_sensitivity : Float32 = 0.002_f32
  #
  #   def _unhandled_input(event : Godot::InputEvent) : Void
  #     if motion = event.as?(Godot::InputEventMouseMotion)
  #       # Instantaneous mouse look delta with zero inertia
  #       rotate_y(-motion.relative.x * @mouse_sensitivity)
  #     elsif key = event.as?(Godot::InputEventKey)
  #       if key.pressed? && !key.echo? && key.keycode == Godot::Key::Escape
  #         Godot::Input.mouse_mode = Godot::Input::MouseMode::Visible
  #       end
  #     end
  #   end
  # end
  # ```
  #
  # ---
  #
  # ### 3. Disabling Accumulated Input for Ultra-Low Latency
  #
  # By default, Godot batches input events to match the OS display refresh rate.
  # For competitive games or high-polling-rate mice (500Hz - 8000Hz), disable accumulation:
  #
  # ```crystal
  # def _ready : Void
  #   # Disable frame batching to receive unbuffered sub-frame mouse events immediately
  #   Godot::Input.use_accumulated_input = false
  # end
  # ```
  #
  # ---
  #
  # ### 4. Zero-Allocation Action & Button Queries
  #
  # `Godot::Input` action queries use process-wide thread-safe `StringName` caching and
  # stack-allocated argument buffers, guaranteeing zero GC heap allocations in `_physics_process`:
  #
  # ```crystal
  # def _physics_process(delta : Float64) : Void
  #   # Zero-allocation 2D composite input vector with circular deadzone
  #   input_dir = Godot::Input.get_vector("move_left", "move_right", "move_forward", "move_back")
  #
  #   # Zero-allocation button press checks
  #   if Godot::Input.is_action_just_pressed("jump") && is_on_floor
  #     velocity = Godot::Vector3.new(velocity.x, jump_velocity, velocity.z)
  #   end
  # end
  # ```
  #
  module O_LOW_LATENCY_INPUT_GUIDE
    def self.features : Array(String)
      [
        "Direct virtual method dispatch for _input, _unhandled_input, _unhandled_key_input, and _gui_input",
        "Typed event unwrapping to InputEventMouseMotion, InputEventKey, InputEventMouseButton",
        "Stack-allocated argument buffers and StringName caching for zero heap allocation polling",
        "Direct C-API get_vector and mouse button state queries",
        "use_accumulated_input control for sub-frame raw input streaming"
      ]
    end
  end

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
        "Levenshtein distance typo correction for intuitive CLI navigation"
      ]
    end
  end

  # ===========================================================================
  # Guide Q: Testing Apparatus, Frame-Stepping, Signal Timeouts & In-Editor Suites
  # ===========================================================================
  #
  # LibGodot provides a reusable, first-class **Testing Apparatus** (`Lapis::Test`, accessible via `include Lapis::Test`)
  # designed for game developers, addon authors, and engine engineers.
  # It unifies standard assertion matchers, cooperative async frame-stepping,
  # signal awaiting with configurable timeout failure guarantees, and live in-editor
  # test execution docked directly inside the Godot Editor.
  #
  # ---
  #
  # ### 1. Assertion Matchers Reference
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Assertion Method</th>
  #       <th style="padding: 10px 14px;">Signature / Parameters</th>
  #       <th style="padding: 10px 14px;">Description &amp; Behavior</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_true</code></td>
  #       <td style="padding: 10px 14px;"><code>cond : Bool, msg = ""</code></td>
  #       <td style="padding: 10px 14px;">Fails if <code>cond</code> is false.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_false</code></td>
  #       <td style="padding: 10px 14px;"><code>cond : Bool, msg = ""</code></td>
  #       <td style="padding: 10px 14px;">Fails if <code>cond</code> is true.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_eq</code></td>
  #       <td style="padding: 10px 14px;"><code>actual, expected, msg = ""</code></td>
  #       <td style="padding: 10px 14px;">Fails if <code>actual != expected</code>. Outputs formatted inspected values.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_approx_eq</code></td>
  #       <td style="padding: 10px 14px;"><code>actual, expected, epsilon = 0.001, msg = ""</code></td>
  #       <td style="padding: 10px 14px;">Fails if floating-point difference exceeds <code>epsilon</code>.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_nil</code> / <code>assert_not_nil</code></td>
  #       <td style="padding: 10px 14px;"><code>val, msg = ""</code></td>
  #       <td style="padding: 10px 14px;">Asserts nil or non-nil reference.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_raises</code></td>
  #       <td style="padding: 10px 14px;"><code>klass : T.class, msg = "", &amp;block</code></td>
  #       <td style="padding: 10px 14px;">Asserts block raises exception of type <code>T</code>. Returns the caught exception.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_includes</code></td>
  #       <td style="padding: 10px 14px;"><code>collection, item, msg = ""</code></td>
  #       <td style="padding: 10px 14px;">Fails if collection does not contain <code>item</code>.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_in_delta</code></td>
  #       <td style="padding: 10px 14px;"><code>actual, expected, delta, msg = ""</code></td>
  #       <td style="padding: 10px 14px;">Fails if difference between numbers exceeds <code>delta</code>.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_between</code></td>
  #       <td style="padding: 10px 14px;"><code>actual, min, max, msg = ""</code></td>
  #       <td style="padding: 10px 14px;">Fails if number is outside the inclusive range <code>[min, max]</code>.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # ### 2. Async Frame-Stepping & Physics Ticks
  #
  # In game testing, verifying state mutations often requires advancing simulation frames
  # without blocking the OS thread or freezing the engine:
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Async Helper</th>
  #       <th style="padding: 10px 14px;">Signature</th>
  #       <th style="padding: 10px 14px;">Mechanics &amp; Usage</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>skip_frames</code></td>
  #       <td style="padding: 10px 14px;"><code>count : Int32 = 1</code></td>
  #       <td style="padding: 10px 14px;">Cooperatively yields execution across <code>count</code> process (render/idle) frames using <code>Godot.next_frame</code>.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>skip_physics_frames</code></td>
  #       <td style="padding: 10px 14px;"><code>count : Int32 = 1</code></td>
  #       <td style="padding: 10px 14px;">Cooperatively yields execution across <code>count</code> fixed physics ticks using <code>Godot.physics_frame</code>. Ideal for testing collisions and rigid body movements.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ```crystal
  # test_physics "Player jump acceleration" do
  #   player = Godot.create(PlayerNode)
  #   root.call("add_child", player)
  #   player.velocity = Godot::Vector3.new(0.0, 10.0, 0.0)
  #
  #   # Step 5 physics ticks
  #   skip_physics_frames(5)
  #   assert_true player.position.y > 0.0_f32
  # end
  # ```
  #
  # ---
  #
  # ### 3. Signal Awaiting with Configurable Timeouts
  #
  # Unbounded signal awaits are a common cause of stalled test suites and hanging CI jobs.
  # LibGodot solves this with guaranteed timeout watchdogs:
  #
  # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
  #   <thead>
  #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
  #       <th style="padding: 10px 14px;">Signal Testing Method</th>
  #       <th style="padding: 10px 14px;">Signature</th>
  #       <th style="padding: 10px 14px;">Timeout Failure Behavior</th>
  #     </tr>
  #   </thead>
  #   <tbody>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>await_signal</code></td>
  #       <td style="padding: 10px 14px;"><code>emitter, signal_name, timeout_sec = 2.0</code></td>
  #       <td style="padding: 10px 14px;">Awaits signal emission. If <code>timeout_sec</code> expires, raises <code>Lapis::Test::TimeoutError</code> with full emitter and signal details.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_emits</code></td>
  #       <td style="padding: 10px 14px;"><code>emitter, signal_name, timeout_sec = 2.0, &amp;block</code></td>
  #       <td style="padding: 10px 14px;">Yields block and verifies signal is emitted within timeout window. Raises <code>Lapis::Test::AssertionError</code> on timeout.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>assert_no_emit</code></td>
  #       <td style="padding: 10px 14px;"><code>emitter, signal_name, duration_sec = 0.5, &amp;block</code></td>
  #       <td style="padding: 10px 14px;">Yields block and verifies signal is NOT emitted during the observation window.</td>
  #     </tr>
  #     <tr style="border-bottom: 1px solid #2d3748;">
  #       <td style="padding: 10px 14px;"><code>with_timeout</code></td>
  #       <td style="padding: 10px 14px;"><code>timeout_sec = 5.0, operation_name = "Operation", &amp;block</code></td>
  #       <td style="padding: 10px 14px;">Guarded watchdog that executes a block in a fiber and aborts with <code>TimeoutError</code> if stalled.</td>
  #     </tr>
  #   </tbody>
  # </table>
  #
  # ---
  #
  # ### 4. Signal Spies & History Inspection
  #
  # Use `SignalSpy` to intercept and assert on signal parameters:
  # ```crystal
  # spy = SignalSpy.new(enemy, "health_changed")
  # enemy.take_damage(25)
  #
  # assert_true spy.emitted?
  # assert_eq spy.count, 1
  # assert_eq spy.first_args.not_nil!, ["75", "100"]
  # spy.disconnect
  # ```
  #
  # ---
  #
  # ### 5. In-Editor Test Execution & Editor Plugin Dock
  #
  # Tests registered via declarative macros (`test_2d`, `test_3d`, `test_shader`, etc.)
  # are accessible directly inside the Godot Editor:
  # 1. **Crystal Engine Hub Dock**:
  #    Open the **Crystal** main screen dock in the editor and click the **Unit Test Runner** tab.
  #    All registered suites and categories appear in the test tree with status indicators (`[⚪ Ready]`).
  # 2. **Execution Modes**:
  #    - **▶ Run All Specs**: Runs headless Crystal specs via `crystal spec`.
  #    - **▶ Run In-Editor Tests**: Executes all registered `Lapis::Test` suites directly within the live engine instance.
  #    - **Run Selected Test**: Executes only the clicked test or category.
  # 3. **Live Inspector Tool Buttons**:
  #    Adding `ToolTester2D` or `ToolTester3D` nodes to any editor scene provides clickable **▶ Run 2D Tool Tests**
  #    buttons in the Inspector for instant feedback.
  #
  module Q_TESTING_FRAMEWORK_AND_EDITOR_SUITES
    def self.features : Array(String)
      [
        "Reusable Lapis::Test framework with full assertion matchers (assert_eq, assert_raises, assert_between)",
        "Cooperative frame-stepping with skip_frames and skip_physics_frames",
        "Deterministic signal awaiting with configurable timeout failure (Lapis::Test::TimeoutError)",
        "Signal emission assertions (assert_emits, assert_no_emit, with_timeout watchdog)",
        "SignalSpy for recording emission counts, call histories, and parameter payloads",
        "Declarative DSL macros: test_2d, test_3d, test_shader, test_material, test_physics, test_audio",
        "Godot Editor integration via CrystalPanel dock and ToolTester2D/3D Inspector buttons"
      ]
    end
  end

  # # R. Release Optimization & Editor Stripping
  #
  # LibGodot enforces compile-time and runtime isolation between development tooling
  # and shipping binaries. When compiling games for production (`make all RELEASE=1` or
  # `lapis build --release`), editor-only modules and metadata are completely stripped:
  #
  # 1. **Compile-Time Feature Guards**:
  #    The core library entry points (`src/lapis.cr` and `src/libgodot.cr`) wrap editor modules
  #    in compile-time guards (`{% unless flag?(:release) || flag?(:libgodot_addon) || flag?(:no_editor) %}`).
  #    This completely excludes `CrystalIntegrationPlugin`, `CrystalHighlighter`, `CrystalDebuggerPlugin`,
  #    `CrystalPanel`, and `CrystalScript` from the compiled binary.
  #
  # 2. **DocData XML Stripping**:
  #    In development, doc comments on nodes and exported properties are gathered into `EditorDocRegistry`
  #    and registered with Godot's offline help database. In release mode, `EditorDocRegistry.register`
  #    and `load_all` become no-ops, eliminating all XML strings and associated memory allocations.
  #
  # 3. **Native C++ ClassDB Filtering**:
  #    In `src/bridge/classdb_registry.hpp`, when `!is_editor_active()` or in non-editor runtime contexts,
  #    editor-specific classes are discarded prior to registering with the Godot engine `ClassDB`.
  #
  # 4. **Packaging Artifact Cleanliness**:
  #    When invoking `lapis package game --release`, intermediate debug files (`*.pdb`, `*.exp`, `*.lib`,
  #    `plugin.*`) are excluded from the distribution archive, ensuring only the minimal runtime payload
  #    is shipped to end-users.
  #
  module R_RELEASE_OPTIMIZATION_AND_EDITOR_STRIPPING
    def self.features : Array(String)
      [
        "Compile-time exclusion of editor plugins and UI docks via flag?(:release)",
        "Zero XML doc comment bloat in release builds",
        "C++ bridge ClassDB filtering suppressing editor classes in standalone runtime",
        "Automated package pruning of debug PDBs and editor plugin binaries"
      ]
    end
  end

  # # S. IDE Integration & Developer Experience
  #
  # The Lapis toolchain provides first-class developer tooling integration for modern editors
  # through the `lapis ide` command family.
  #
  # 1. **Automated IDE Setup**:
  #    Run `lapis ide setup [editor]` to automatically generate workspace configurations:
  #    - **VS Code / Cursor** (`lapis ide setup vscode`):
  #      Generates `.vscode/settings.json`, `.vscode/tasks.json`, and `.vscode/launch.json`.
  #      Configures Crystalline Language Server Protocol (`bin/crystalline.exe`), Crystal build tasks,
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
        "Pre-configured task runners for compilation, test suites, and packaging"
      ]
    end
  end
  end
end

require "./docs/cpp_bridge"

alias Docs = ::Lapis::Docs

module Godot
  alias Docs = ::Lapis::Docs
end




