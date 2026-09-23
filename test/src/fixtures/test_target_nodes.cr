# =============================================================================
# LibGodot Test Target Fixtures & Verification Nodes
# =============================================================================
#
# Dedicated target nodes exercising all GDExtension ClassDB reflection features:
# properties, typed exports, export hints, property groups/subgroups, custom
# getters/setters, tool buttons, custom signals, and GDScript interop.
# =============================================================================

require "../../../src/lapis"

@[Tool]
@[Icon("res://addons/crystal_integration/crystal.gdextension")]
node PropertyTestTarget < Godot::Node do
  # 1. Standard Property Exports
  @[Export]
  property float32_val : Float32 = 1.25_f32

  @[Export]
  property float64_val : Float64 = 9.87654

  @[Export]
  property int32_val : Int32 = 42

  @[Export]
  property int64_val : Int64 = 10000000000_i64

  @[Export]
  property bool_val : Bool = true

  @[Export]
  property string_val : String = "LibGodot"

  @[Export]
  property vec2_val : Godot::Vector2 = Godot::Vector2.new(3.0, 4.0)

  @[Export]
  property vec2i_val : Godot::Vector2i = Godot::Vector2i.new(7, 8)

  @[Export]
  property vec3_val : Godot::Vector3 = Godot::Vector3.new(1.0, 2.0, 3.0)

  @[Export]
  property vec3i_val : Godot::Vector3i = Godot::Vector3i.new(4, 5, 6)

  @[Export]
  property color_val : Godot::Color = Godot::Color.new(1.0, 0.5, 0.25, 1.0)

  @[Export]
  property rect2_val : Godot::Rect2 = Godot::Rect2.new(10.0, 20.0, 100.0, 200.0)

  # 2. Custom Getters & Setters
  @raw_health : Float32 = 100.0_f32
  @dirty_counter : Int32 = 0
  @tool_action_fired : Bool = false

  def health_percentage : Float32
    (@raw_health / 100.0_f32) * 100.0_f32
  end

  def clamped_health=(val : Float32)
    @raw_health = val.clamp(0.0_f32, 100.0_f32)
  end

  def clamped_health : Float32
    @raw_health
  end

  def dirty_trigger=(val : Int32)
    @dirty_counter += val
  end

  def dirty_trigger : Int32
    @dirty_counter
  end

  def tool_button_trigger=(val : Bool)
    if val
      @tool_action_fired = true
    end
  end

  def tool_button_trigger : Bool
    @tool_action_fired
  end

  # 3. Export Property Hints
  @[ExportRange(0..100, 5)]
  property range_hint_prop : Int32 = 25

  @[ExportEnum("Low", "Medium", "High")]
  property enum_hint_prop : String = "Medium"

  @[ExportFile("*.tscn")]
  property file_hint_prop : String = "res://scenes/test_dummy_2d.tscn"

  @[ExportMultiline]
  property multiline_hint_prop : String = "First Line\nSecond Line"

  @[ExportColorNoAlpha]
  property color_no_alpha_prop : Godot::Color = Godot::Color.new(1.0, 0.0, 0.0)

  @[ExportNodePath("Child")]
  property nodepath_hint_prop : Godot::NodePath = Godot::NodePath.new("Child")

  @[ExportStorage]
  property storage_only_prop : Int32 = 999

  @[ExportToolButton("Click Here")]
  property tool_btn_prop = -> {
    @tool_btn_fired = true
  }

  property tool_btn_fired : Bool = false

  @[ExportToolButton("Proc Method Pointer Button", icon: "Action")]
  property proc_btn_ptr = ->tool_proc_method

  @[ExportToolButton("Proc Lambda Button")]
  property proc_btn_lambda = -> {
    @proc_action_fired = true
  }

  @[ExportToolButton("Proc Dynamic Button")]
  property proc_btn_dyn : Proc(Void)? = nil

  property proc_action_fired : Bool = false

  def tool_proc_method : Void
    @proc_action_fired = true
  end

  @[ExportToolButton("Method Action", icon: "Play")]
  def test_method_action : Void
    @tool_action_fired = true
  end

  @[ExportCustom(hint: 1_u32, hint_string: "0,50,5")]
  property custom_hint_prop : Int32 = 10

  # 4. Grouping Annotations
  @[ExportCategory("Stats")]
  property cat_marker : Int32 = 1

  @[ExportGroup("Movement", prefix: "move_")]
  property move_speed : Float32 = 250.0_f32

  @[ExportSubgroup("Air")]
  property move_air_speed : Float32 = 180.0_f32

  # 5. Signals
  signal test_event_fired(val : Int32)
  signal multi_arg_event(code : Int32, label : String, ratio : Float64)
  signal custom_event(payload : String)
end

@[Tool]
node GDScriptInteropTarget < Godot::Node do
  @[Export]
  property crystal_greeting : String = "Hello from Crystal"

  @[Export]
  property crystal_count : Int32 = 100

  signal crystal_ping(val : Int32)

  def multiply(a : Int32, b : Int32) : Int32
    a * b
  end

  def ping(val : Int32)
    emit_crystal_ping(val)
  end
end
