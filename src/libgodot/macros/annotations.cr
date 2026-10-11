# Marks an instance variable as an exported property visible in the Godot inspector.
#
# ```
# @[Export]
# property speed : Float32 = 100.0_f32
# ```
annotation Export; end

# Exports a numeric property constrained to a specific range in the Godot inspector.
# Supports min, max, and optional step size.
#
# ```
# @[ExportRange(0.0, 100.0, 0.5)]
# property health : Float64 = 100.0
# ```
annotation ExportRange; end

# Exports a property whose values are constrained to an enumeration or list of string choices.
# Can take a list of string choices, or a Crystal `Enum` type directly (`@[ExportEnum(MyEnum)]`).
#
# ```
# enum CharacterClass
#   Warrior
#   Mage
#   Rogue
# end
#
# # Strongly-typed Crystal enum:
# @[ExportEnum(CharacterClass)]
# property character_class : CharacterClass = CharacterClass::Warrior
#
# # Integer property with enum dropdown:
# @[ExportEnum(CharacterClass)]
# property class_id : Int32 = 0
#
# # String choice list:
# @[ExportEnum("Warrior", "Mage", "Rogue")]
# property class_name : String = "Warrior"
# ```
annotation ExportEnum; end

# Exports a string property as a file picker in the Godot inspector.
# Accepts optional file extension filters (e.g. `"*.png,*.jpg"`).
#
# ```
# @[ExportFile("*.png")]
# property sprite_path : String = ""
# ```
annotation ExportFile; end

# Exports a string property as a file path selector.
annotation ExportFilePath; end

# Exports a string property as a directory picker in the Godot inspector.
#
# ```
# @[ExportDir]
# property assets_dir : String = "res://assets"
# ```
annotation ExportDir; end

# Exports a string property as a global (system-wide filesystem) file picker.
annotation ExportGlobalFile; end

# Exports a string property as a global (system-wide filesystem) directory picker.
annotation ExportGlobalDir; end

# Exports a string property with a multiline text editor in the Godot inspector.
#
# ```
# @[ExportMultiline]
# property dialogue : String = "Hello\nWorld!"
# ```
annotation ExportMultiline; end

# Exports a string property with placeholder ghost text shown when empty.
#
# ```
# @[ExportPlaceholder("Enter player name...")]
# property player_name : String = ""
# ```
annotation ExportPlaceholder; end

# Exports an integer property as a bitmask flag field in the Godot inspector.
# Can take a list of flag names or a Crystal `@[Flags] enum` type directly (`@[ExportFlags(CombatFlags)]`).
#
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
# # Integer bitmask property:
# @[ExportFlags(CombatFlags)]
# property flags_mask : Int32 = 0
#
# # Explicit string flag names:
# @[ExportFlags("Fire", "Water", "Earth", "Air")]
# property elemental_affinities : Int32 = 0
# ```
annotation ExportFlags; end

# Exports an integer property as 2D render layer visibility bitmask flags.
annotation ExportFlags2DRender; end

# Exports an integer property as 2D physics collision layers and masks.
annotation ExportFlags2DPhysics; end

# Exports an integer property as 2D navigation layers.
annotation ExportFlags2DNavigation; end

# Exports an integer property as 3D render layer visibility bitmask flags.
annotation ExportFlags3DRender; end

# Exports an integer property as 3D physics collision layers and masks.
annotation ExportFlags3DPhysics; end

# Exports an integer property as 3D navigation layers.
annotation ExportFlags3DNavigation; end

# Exports an integer property as navigation avoidance obstacle layers.
annotation ExportFlagsAvoidance; end

# Exports a float property with exponential easing curve visualization in the inspector.
annotation ExportExpEasing; end

# Exports a Color property while suppressing the alpha (transparency) channel selector.
#
# ```
# @[ExportColorNoAlpha]
# property team_color : Color = Color::RED
# ```
annotation ExportColorNoAlpha; end

# Exports a NodePath property restricted to specific node types in the scene hierarchy.
#
# ```
# @[ExportNodePath("Camera3D")]
# property camera_path : NodePath = NodePath.new
# ```
annotation ExportNodePath; end

# Exports a property stored within the scene file without displaying in the editor inspector.
annotation ExportStorage; end

# Exposes a method or property as an interactive button in the inspector.
annotation ExportToolButton; end

# Exports a property with custom PropertyHint and hint string parameters.
#
# ```
# @[ExportCustom(hint: 1_u32, hint_string: "0,10,1")]
# property custom_val : Int32 = 5
# ```
annotation ExportCustom; end

# Starts a top-level category header in the Godot inspector.
annotation ExportCategory; end

# Groups subsequent exported properties under a collapsible heading in the inspector.
# An optional prefix strips common prefixes from property names in the group.
#
# ```
# @[ExportGroup("Movement", prefix: "move_")]
# property move_speed : Float32 = 200.0_f32
# ```
annotation ExportGroup; end

# Groups exported properties under a subgroup within an existing group.
annotation ExportSubgroup; end

# Explicitly designates a Crystal class for GDExtension registration.
# (Automatically recognized on classes inheriting from Godot node types).
annotation GodotClass; end

# Marks a script class to execute in the editor as a tool script.
#
# ```
# @[Tool]
# class LevelEditorHelper < Godot::Node3D
# end
# ```
annotation Tool; end

# Specifies a custom editor icon path for the node class.
#
# ```
# @[Icon("res://icons/player.svg")]
# class Player < Godot::CharacterBody3D
# end
# ```
annotation Icon; end

# Marks an extension class as abstract, preventing direct instantiation in the editor.
annotation Abstract; end

# Configures GDExtension library unloading behavior.
annotation StaticUnload; end

# Explicitly sets the source script path for editor script linking.
annotation ScriptPath; end

# Marks a node class as an Autoload singleton, automatically instantiating it,
# registering it with Godot's Engine singleton registry, and mounting it to the SceneTree root.
#
# ```
# @[Autoload]
# node GameManager < Node do
#   property score : Int32 = 0
# end
# ```
annotation Autoload; end

# Automatically initializes a node property when `_ready` is called by querying the scene tree.
#
# ```
# @[OnReady("Sprite2D")]
# property sprite : Godot::Node2D? = nil
# ```
annotation OnReady; end

# Marks a property for automatic typed node resolution during `_ready`.
#
# ```
# @[NodeRef("Sprite2D")]
# property sprite : Godot::Node2D? = nil
#
# @[NodeRef]
# property player : Player? = nil
# ```
annotation NodeRef; end
annotation ChildNode; end

# Marks a property for automatic Scene Unique Node resolution (e.g. `%NodeName`) during `_ready`.
#
# ```
# @[UniqueNode("MainCamera")]
# property camera : Godot::Camera2D? = nil
#
# @[UniqueNode]
# property health_bar : Godot::ProgressBar? = nil
# ```
annotation UniqueNode; end
annotation UniqueNodeRef; end

# Assigns the node to one or more scene tree groups upon `_ready`.
#
# ```
# @[Group("enemies", "flammable")]
# class Enemy < Godot::Node2D
# end
# ```
annotation Group; end

# Configures Remote Procedure Call (RPC) network replication for a method.
# Accepts mode, sync, transfer_mode, and channel parameters.
#
# ```
# @[RPC(mode: :any_peer, call_local: true)]
# def sync_player_position(pos : Vector3) : Void
# end
# ```
annotation RPC; end

# Suppresses specific compiler or engine warnings for a class or member.
annotation WarningIgnore; end

# Starts a warning suppression block.
annotation WarningIgnoreStart; end

# Restores normal warning behavior following a suppression block.
annotation WarningIgnoreRestore; end

# Convenience macro to mark extension library unloading behavior.
macro static_unload
end

# Convenience macro to designate a class as abstract in Godot.
macro abstract_class
end

# Convenience macro to set a custom icon path in the editor.
macro icon(path)
end

# Convenience macro to create a category header in the inspector.
macro export_category(name)
end

# Convenience macro to group properties under a collapsible section in the inspector.
macro export_group(name, prefix = "")
end

# Convenience macro to create a subgroup under an existing inspector group.
macro export_subgroup(name, prefix = "")
end

# Convenience macro to suppress compiler warnings.
macro warning_ignore(name)
end

macro warning_ignore_start(name)
end

macro warning_ignore_restore(name)
end
