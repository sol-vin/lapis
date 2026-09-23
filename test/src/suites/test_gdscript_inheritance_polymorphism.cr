# =============================================================================
# LibGodot Test Suite: GDScript Subclassing Crystal & Bidirectional Polymorphism
# Replicating godot-rust's InheritTests.gd and ManualFfiTests.gd
# =============================================================================

include Lapis::Test

node CrystalBaseEntity < Godot::CharacterBody2D do
  @[Export]
  property base_speed : Float32 = 100.0_f32

  @[Export]
  property hit_points : Int32 = 50

  signal entity_acted(action_name : String)
end

module Godot
  alias CrystalBaseEntity = ::CrystalBaseEntity
end

test_suite "Polymorphism" do
  test "GDScript subclassing Crystal node inherits properties and signals" do
  entity = Godot.create(CrystalBaseEntity)
  assert_not_nil entity, "CrystalBaseEntity must instantiate"

  # Base properties exported from Crystal should be accessible on entity
  assert_approx_eq entity.call_f64("get", "base_speed"), 100.0, 0.01
  assert_eq entity.call_i64("get", "hit_points"), 50_i64

  # Mutating inherited property from Crystal side reflects in instance
  entity.call("set", "base_speed", 120.0_f64)
  assert_approx_eq entity.call_f64("get", "base_speed"), 120.0, 0.01

  # Dynamically compile and attach GDScript subclass extending CharacterBody2D
  # Replicating godot-rust's create_gdscript & node.set_script testing methodology
  code = <<-GDSCRIPT
  extends CharacterBody2D

  @export var gdscript_bonus: int = 15

  func compute_damage(raw_input: int) -> int:
    var spd = int(get("base_speed"))
    return (raw_input * 2) + gdscript_bonus + spd

  func get_effective_speed() -> float:
    var spd = float(get("base_speed"))
    return spd * 1.5

  func trigger_entity_action(act: String) -> String:
    emit_signal("entity_acted", "GDScript_" + act)
    return "GDScriptWrapped[" + act + "]"
  GDSCRIPT

  gdscript = Godot.create(Godot::GDScript)
  gdscript.call("set_path", "user://test_poly_script.gd")
  gdscript.set_source_code(code)
  reload_err = gdscript.call_i64("reload")

  # Also test loading the pre-authored script via ResourceLoader
  res_loader = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
  file_script = res_loader.load("res://scripts/gdscript_inherits_crystal.gd", "", 1_i64)

  chosen_script = (reload_err == 0) ? gdscript : file_script
  entity.call("set_script", chosen_script)
  has_comp = entity.call_bool("has_method", "compute_damage")

  # GDScript method computes damage: (10 * 2) + 15 + 120 = 155
  result = entity.call_i64("compute_damage", 10_i64)
  assert_eq result, 155_i64, "GDScript method must compute damage"

  # GDScript method computing speed multiplier: 120.0 * 1.5 = 180.0
  eff_speed = entity.call_f64("get_effective_speed")
  assert_approx_eq eff_speed, 180.0, 0.01, "GDScript method must compute speed multiplier"

  # GDScript emitting inherited signal defined on Crystal base class
  received_signal_arg = ""
  entity.connect("entity_acted") do |args|
    received_signal_arg = args[0].to_s if args.size > 0
  end

  action_res = entity.call_str("trigger_entity_action", "Jump")
  assert_eq action_res, "GDScriptWrapped[Jump]"
  assert_eq received_signal_arg, "GDScript_Jump", "Signal declared in Crystal node must be emitted from GDScript subclass"

  entity.destroy
end

end
