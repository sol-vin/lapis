@tool
extends CharacterBody2D
class_name GdscriptInheritsCrystal

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
