@tool
extends Node2D
class_name ComprehensiveInteropNode

# =============================================================================
# Comprehensive GDScript Test Node for Automated LibGodot Binding
# =============================================================================

signal data_processed(record_id: int, label: String, score: float)
signal state_transitioned(old_state: String, new_state: String)

@export var int_prop: int = 42
@export var float_prop: float = 3.14159
@export var string_prop: String = "LibGodot AutoBind"
@export var bool_prop: bool = true

var internal_reset_count: int = 0
var last_transition_old: String = ""
var last_transition_new: String = ""

func compute_scaled_sum(a: int, b: int, multiplier: float) -> int:
	return int((a + b) * multiplier)

func calculate_hypotenuse(a: float, b: float) -> float:
	return sqrt(a * a + b * b)

func format_complex_message(prefix: String, id: int, status: String) -> String:
	return "%s #%d -> %s" % [prefix, id, status]

func validate_conditions(flag_a: bool, flag_b: bool) -> bool:
	return flag_a and not flag_b

func distance_to_point(point: Vector2) -> float:
	return position.distance_to(point)

func compute_dot3(v1: Vector3, v2: Vector3) -> float:
	return v1.dot(v2)

func color_brightness(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0

func duplicate_child_node(node_name: String) -> Node:
	var n = Node.new()
	n.name = node_name
	add_child(n)
	return n

func inspect_incoming_node(target: Node) -> String:
	if target == null:
		return "NULL_NODE"
	return "%s:%s" % [target.name, target.get_class()]

func perform_state_reset() -> void:
	int_prop = 0
	float_prop = 0.0
	string_prop = "RESET"
	bool_prop = false
	internal_reset_count += 1

func trigger_data_processed(record_id: int, label: String, score: float) -> void:
	emit_signal("data_processed", record_id, label, score)

func trigger_state_transitioned(old_state: String, new_state: String) -> void:
	last_transition_old = old_state
	last_transition_new = new_state
	emit_signal("state_transitioned", old_state, new_state)
