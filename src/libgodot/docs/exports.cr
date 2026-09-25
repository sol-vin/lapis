module Lapis
  module Docs
    # # C. Export System & Inspector Properties
    #
    # LibGodot provides a rich property export system matching Godot's native `@export`
    # capabilities. Annotations placed above Crystal properties are analyzed at compile
    # time by the `node` macro, translating them into Godot `PropertyInfo` descriptors
    # registered into `ClassDB`.
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
    #       <td><strong>Pipeline Overview</strong></td>
    #       <td><code>.topic_01_pipeline_overview</code></td>
    #       <td>How the macro extracts property types, hints, and generates getters/setters.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Basic Exports</strong></td>
    #       <td><code>.topic_02_basic_exports</code></td>
    #       <td>Inferred inspector editors for Bool, Int, Float, String, Vector, and Color.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Numeric Ranges</strong></td>
    #       <td><code>.topic_03_numeric_ranges</code></td>
    #       <td>Sliders with min, max, and step using @[ExportRange] or Crystal Range syntax.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Enums & Choices</strong></td>
    #       <td><code>.topic_04_enums_and_choices</code></td>
    #       <td>Dropdown choice lists with string literals or typed Crystal Enum classes.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Files & Directories</strong></td>
    #       <td><code>.topic_05_files_and_directories</code></td>
    #       <td>Native file and directory pickers with project-relative or global paths.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Flags & Bitmasks</strong></td>
    #       <td><code>.topic_06_flags_and_bitmasks</code></td>
    #       <td>2D/3D physics layer flags, navigation layers, and custom bitmask flags.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Colors & NodePaths</strong></td>
    #       <td><code>.topic_07_colors_and_paths</code></td>
    #       <td>Color pickers without alpha and typed scene tree node path selectors.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Groups & Categories</strong></td>
    #       <td><code>.topic_08_groups_and_categories</code></td>
    #       <td>Collapsible accordion sections and category banners in the Inspector dock.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Tool Buttons</strong></td>
    #       <td><code>.topic_09_tool_buttons</code></td>
    #       <td>Clickable action buttons in the Inspector triggering Crystal procs/methods.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Storage Hints</strong></td>
    #       <td><code>.topic_10_storage_hints</code></td>
    #       <td>Excluding properties from the Inspector while preserving scene serialization.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/macros.cr`, `src/libgodot/types.cr`
    # - **Live Specifications**: `spec/suites/test_macros_dsl.cr`, `spec/features_spec.cr`
    # - **Showcase Examples**: `src/main.cr`
    # - **Related Guides**: `Docs::D_NODE_DSL_AND_SIGNALS`, `Docs::L_MACRO_DSL_REFERENCE`
    module C_EXPORTS_AND_INSPECTOR
      # **Supported Export Annotations**: Catalog of all @[Export*] annotations recognized by the macro compiler.
      def self.topic_00_supported_annotations : Array(String)
        [
          "@[Export]",
          "@[ExportRange]",
          "@[ExportEnum]",
          "@[ExportFile]",
          "@[ExportFilePath]",
          "@[ExportDir]",
          "@[ExportGlobalFile]",
          "@[ExportGlobalDir]",
          "@[ExportMultiline]",
          "@[ExportPlaceholder]",
          "@[ExportColorNoAlpha]",
          "@[ExportNodePath]",
          "@[ExportFlags]",
          "@[ExportFlags2DPhysics]",
          "@[ExportFlags3DPhysics]",
          "@[ExportFlags2DRender]",
          "@[ExportFlags3DRender]",
          "@[ExportFlags2DNavigation]",
          "@[ExportFlags3DNavigation]",
          "@[ExportFlagsAvoidance]",
          "@[ExportExpEasing]",
          "@[ExportGroup]",
          "@[ExportSubgroup]",
          "@[ExportCategory]",
          "@[ExportToolButton]",
          "@[ExportStorage]",
        ]
      end

      # **Export Pipeline Overview**: How the node macro extracts property types, hints, and generates getters and setters.
      #
      # 1. At compile time, the `node` macro inspects each `property` declaration inside the block.
      # 2. It reads attached annotations (`@[Export]`, `@[ExportRange]`, `@[ExportFlags]`, etc.).
      # 3. It maps the Crystal type to Godot's `Variant::Type` enum:
      #    - `Bool` -> `BOOL`, `Int32`/`Int64` -> `INT`, `Float32`/`Float64` -> `FLOAT`
      #    - `String` -> `STRING`, `Vector2` -> `VECTOR2`, `Vector3` -> `VECTOR3`, `Color` -> `COLOR`
      # 4. It constructs a `Godot::PropertyInfo` instance specifying name, type, hint, and hint string.
      # 5. It generates typed property getters and setters in the `CrystalClassDesc` structure.
      #
      # See also: `src/libgodot/macros.cr`
      def self.topic_01_pipeline_overview : Nil
      end

      # **Basic Property Exports**: Inferred inspector editors for Bool, Int, Float, String, Vector, and Color types.
      #
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
      # ```
      def self.topic_02_basic_exports : Nil
      end

      # **Numeric Ranges & Sliders**: Inspector sliders with min, max, and step using @[ExportRange] or Crystal Range syntax.
      #
      # Displays a slider with min, max, and step constraints:
      # ```crystal
      # # Explicit arguments: min, max, step
      # @[ExportRange(0.0, 100.0, 0.5)]
      # property health : Float64 = 100.0
      #
      # # Idiomatic Crystal range syntax:
      # @[Export(range: 1..100, step: 1)]
      # property level : Int32 = 1
      # ```
      def self.topic_03_numeric_ranges : Nil
      end

      # **Enums & Dropdown Choices**: Dropdown choice lists with string literals or typed Crystal Enum classes.
      #
      # Displays a dropdown list of options in the Inspector. Supports string choices or Crystal `Enum` types:
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
      # # String choice list:
      # @[ExportEnum("Warrior", "Mage", "Rogue", "Paladin")]
      # property job_title : String = "Warrior"
      # ```
      def self.topic_04_enums_and_choices : Nil
      end

      # **File & Directory Pickers**: Native file dialogs and directory selectors with project-relative or global paths.
      #
      # Opens Godot's native file dialog in the inspector:
      # ```crystal
      # # Project-relative file picker with filter:
      # @[ExportFile("*.png,*.jpg")]
      # property sprite_path : String = ""
      #
      # # Project-relative directory picker:
      # @[ExportDir]
      # property save_dir : String = "user://saves"
      # ```
      def self.topic_05_files_and_directories : Nil
      end

      # **Flags & Bitmasks**: 2D/3D physics layer flags, navigation layers, and custom bitmask flags.
      #
      # Displays multi-select bitmask checkboxes:
      # ```crystal
      # # Custom named flags:
      # @[ExportFlags("Fire", "Water", "Earth", "Air")]
      # property elements : Int32 = 1
      #
      # # Godot 2D Physics layers:
      # @[ExportFlags2DPhysics]
      # property collision_mask : Int32 = 1
      #
      # # Godot 3D Render layers:
      # @[ExportFlags3DRender]
      # property visual_layers : Int32 = 1
      # ```
      def self.topic_06_flags_and_bitmasks : Nil
      end

      # **Colors & NodePaths**: Color pickers without alpha channel and typed scene tree node path selectors.
      #
      # ```crystal
      # # Color picker with alpha channel disabled:
      # @[ExportColorNoAlpha]
      # property background_color : Color = Color::BLACK
      #
      # # NodePath picker filtered to specific node types:
      # @[ExportNodePath(types: [Camera3D, Marker3D])]
      # property camera_target : NodePath = NodePath.new("")
      # ```
      def self.topic_07_colors_and_paths : Nil
      end

      # **Inspector Groups & Categories**: Collapsible accordion sections and category banners in the Inspector dock.
      #
      # Organizes inspector properties into visually grouped accordion sections:
      # ```crystal
      # @[ExportCategory("Combat Stats")]
      # @[Export]
      # property attack_power : Int32 = 25
      #
      # @[ExportGroup("Movement", prefix: "move_")]
      # @[Export]
      # property move_speed : Float32 = 8.0_f32
      # @[Export]
      # property move_acceleration : Float32 = 20.0_f32
      # ```
      def self.topic_08_groups_and_categories : Nil
      end

      # **Inspector Tool Buttons**: Clickable action buttons in the Inspector triggering Crystal procs and methods.
      #
      # Adds interactive clickable buttons to the Inspector:
      # ```crystal
      # @[ExportToolButton("▶ Execute Test Suite", icon: "Play")]
      # property run_button = ->run_tests
      #
      # def run_tests : Void
      #   Godot.print("Executing tests from Inspector button click!")
      # end
      # ```
      #
      # See also: `src/main.cr`
      def self.topic_09_tool_buttons : Nil
      end

      # **Storage Hints & Serialization**: Excluding properties from the Inspector while preserving scene serialization.
      #
      # Serializes a property to disk (`.tscn` / `.tres`) without displaying it in the Godot Inspector dock:
      # ```crystal
      # @[ExportStorage]
      # property internal_cache_id : String = "A7B9"
      # ```
      def self.topic_10_storage_hints : Nil
      end
    end
  end
end
