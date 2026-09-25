module Lapis
  module Docs
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
    # ```
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
    # ```
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
    # ```
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
    # ```
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
    # ```
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
    # ```
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
    # ```
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
    # ```
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
    # ```
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
    # ```
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
    # ```
    # # 1. Method pointer tool button (idiomatic Crystal method reference, takes only no-args proc):
    # @[ExportToolButton("Regenerate World", icon: "Play")]
    # property my_button = ->some_method
    #
    # # 2. Lambda tool button:
    # @[ExportToolButton("Reset Counters")]
    # property reset_button = -> {
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
          "String", "Vector2", "Vector3", "Color", "NodePath",
        ]
      end
    end
  end
end

