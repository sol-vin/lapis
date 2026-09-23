@tool
extends Node
class_name InteropController

# GDScript <-> Crystal Interoperability Test Controller
signal gd_ping(val: int)
signal gd_pong(msg: String)
signal channel_select_completed(ch: RefCounted, val: String)

var counter: int = 0
var received_node_name: String = ""

func add_numbers(a: int, b: int) -> int:
	return a + b

func compute_distance(p1: Vector2, p2: Vector2) -> float:
	return p1.distance_to(p2)

func format_greeting(name: String) -> String:
	return "Hello from GDScript, %s!" % name

func is_node_valid_and_named(node: Node, expected_name: String) -> bool:
	if node == null:
		return false
	return node.name == expected_name

func spawn_node_for_crystal(node_name: String) -> Node:
	var n = Node.new()
	n.name = node_name
	add_child(n)
	return n

func inspect_crystal_node(node: Node) -> String:
	if node == null:
		return "NIL"
	received_node_name = str(node.name)
	return "OK:%s:%s" % [node.name, node.get_class()]

func reparent_node_from_crystal(child: Node, new_parent: Node) -> bool:
	if child == null or new_parent == null:
		return false
	if child.get_parent() != null:
		child.get_parent().remove_child(child)
	new_parent.add_child(child)
	return child.get_parent() == new_parent

func increment_counter(amount: int) -> int:
	counter += amount
	return counter

func fire_gd_ping(val: int) -> void:
	emit_signal("gd_ping", val)

func run_await_sequence() -> String:
	await get_tree().process_frame
	return "Awaited Frame Successfully"

func destroy_node_from_gdscript(target: Node) -> bool:
	if target == null:
		return false
	target.free()
	return true

func queue_free_node_from_gdscript(target: Node) -> bool:
	if target == null:
		return false
	target.queue_free()
	return true

# Resource Interoperability
func inspect_resource_power(res: Resource) -> int:
	if res == null:
		return -1
	return int(res.get("power"))

func inspect_resource_name(res: Resource) -> String:
	if res == null:
		return ""
	return str(res.get("item_name"))

func modify_resource_power(res: Resource, new_power: int) -> bool:
	if res == null:
		return false
	res.set("power", new_power)
	return true

func load_resource_from_disk_and_get_power(path: String) -> int:
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return -1
	var p = int(res.get("power"))
	res.take_over_path("")
	if res.get_reference_count() > 1:
		res.unreference()
	res = null
	return p

# Enum Interoperability
func inspect_enum_property(node: Node, prop_name: String) -> int:
	if node == null:
		return -1
	return int(node.get(prop_name))

func set_enum_property(node: Node, prop_name: String, val: int) -> bool:
	if node == null:
		return false
	node.set(prop_name, val)
	return true

func get_enum_property_hint_string(node: Node, prop_name: String) -> String:
	if node == null:
		return ""
	for p in node.get_property_list():
		if p["name"] == prop_name:
			return str(p["hint_string"])
	return ""

func get_enum_property_hint(node: Node, prop_name: String) -> int:
	if node == null:
		return -1
	for p in node.get_property_list():
		if p["name"] == prop_name:
			return int(p["hint"])
	return -1

func query_classdb_enum_constant(class_name_str: String, const_name: String) -> int:
	if ClassDB.class_exists(class_name_str) and ClassDB.class_has_integer_constant(class_name_str, const_name):
		return ClassDB.class_get_integer_constant(class_name_str, const_name)
	return -1

# GodotChannel Interoperability
func create_channel(capacity: int = 16) -> RefCounted:
	return ClassDB.instantiate("GodotChannel")

func send_to_channel(ch: RefCounted, data: String) -> bool:
	if ch == null:
		return false
	return ch.send(data)

func try_send_to_channel(ch: RefCounted, data: String) -> bool:
	if ch == null:
		return false
	return ch.try_send(data)

func receive_from_channel(ch: RefCounted) -> String:
	if ch == null:
		return ""
	var item = ch.receive()
	return str(item) if item != null else ""

func try_receive_from_channel(ch: RefCounted) -> String:
	if ch == null:
		return ""
	var item = ch.try_receive()
	return str(item) if item != null else ""

func get_channel_size(ch: RefCounted) -> int:
	if ch == null:
		return -1
	return int(ch.size())

func is_channel_empty(ch: RefCounted) -> bool:
	if ch == null:
		return true
	return bool(ch.is_empty())

func is_channel_full(ch: RefCounted) -> bool:
	if ch == null:
		return false
	return bool(ch.is_full())

func is_channel_closed(ch: RefCounted) -> bool:
	if ch == null:
		return true
	return bool(ch.is_closed())

func close_channel(ch: RefCounted) -> void:
	if ch != null:
		ch.close()

# Channel Signal Listener
var channel_received_count: int = 0
var last_channel_received_val: String = ""

func connect_channel_received(ch: RefCounted) -> bool:
	if ch == null:
		return false
	ch.connect("received", Callable(self, "_on_channel_received"))
	return true

func _on_channel_received(val: String) -> void:
	channel_received_count += 1
	last_channel_received_val = val

# Crystal Signal Interoperability
var last_crystal_signal_name: String = ""
var last_crystal_signal_data: String = ""
var signal_call_count: int = 0

func connect_crystal_signals(crystal_node: Node) -> bool:
	if crystal_node == null:
		return false
	if crystal_node.has_signal("crystal_event"):
		crystal_node.connect("crystal_event", Callable(self, "_on_crystal_event"))
	if crystal_node.has_signal("health_changed"):
		crystal_node.connect("health_changed", Callable(self, "_on_health_changed"))
	if crystal_node.has_signal("data_transferred"):
		crystal_node.connect("data_transferred", Callable(self, "_on_data_transferred"))
	return true

func _on_crystal_event(msg: String) -> void:
	last_crystal_signal_name = "crystal_event"
	last_crystal_signal_data = msg
	signal_call_count += 1

func _on_health_changed(current: int, max_val: int) -> void:
	last_crystal_signal_name = "health_changed"
	last_crystal_signal_data = "%d/%d" % [current, max_val]
	signal_call_count += 1

func _on_data_transferred(text: String) -> void:
	last_crystal_signal_name = "data_transferred"
	last_crystal_signal_data = text
	signal_call_count += 1

func emit_crystal_node_signal(crystal_node: Node, signal_name: String, arg: String) -> void:
	if crystal_node != null:
		crystal_node.emit_signal(signal_name, arg)

func find_property_in_list(node: Node, prop_name: String) -> Dictionary:
	if node == null:
		return {}
	for p in node.get_property_list():
		if str(p.get("name", "")) == prop_name:
			return p
	return {}

func inspect_property_val(node: Node, prop_name: String) -> Variant:
	if node == null:
		return null
	return node.get(prop_name)

func set_property_val(node: Node, prop_name: String, val: Variant) -> bool:
	if node == null:
		return false
	node.set(prop_name, val)
	return true

func load_and_inspect_crystal_scene(scene_path: String) -> Dictionary:
	var scene = ResourceLoader.load(scene_path)
	if scene == null:
		return {"success": false, "error": "Failed to load scene"}
	var inst = scene.instantiate()
	if inst == null:
		return {"success": false, "error": "Failed to instantiate scene"}
	var result = {
		"success": true,
		"name": inst.name,
		"class": inst.get_class(),
		"character_name": str(inst.get("character_name")),
		"health": float(inst.get("health")),
		"level": int(inst.get("level"))
	}
	inst.free()
	return result

func verify_crystal_scene_properties(scene_path: String) -> bool:
	var res = load_and_inspect_crystal_scene(scene_path)
	if not res.get("success", false):
		return false
	if res.get("character_name") != "Arthas":
		return false
	if res.get("level") != 25:
		return false
	return true

# GDScript Multi-Channel Select & Multiplexing
var last_selected_channel_value: String = ""

func select_channel_from_pair(ch1: RefCounted, ch2: RefCounted) -> RefCounted:
	var ch = null
	if ch1 != null and not ch1.is_empty():
		ch = ch1
	elif ch2 != null and not ch2.is_empty():
		ch = ch2
	if ch != null:
		last_selected_channel_value = str(ch.try_receive())
		return ch
	last_selected_channel_value = ""
	return null

var last_channel_pair_val: String = ""
var last_channel_pair_id: int = 0

func setup_channel_pair_listener(ch1: RefCounted, ch2: RefCounted) -> void:
	last_channel_pair_val = ""
	last_channel_pair_id = 0
	var on_ch1 = func(val):
		if last_channel_pair_val == "" and ch1 != null and not ch1.is_empty():
			last_channel_pair_val = str(ch1.try_receive())
			last_channel_pair_id = ch1.get_instance_id()
	var on_ch2 = func(val):
		if last_channel_pair_val == "" and ch2 != null and not ch2.is_empty():
			last_channel_pair_val = str(ch2.try_receive())
			last_channel_pair_id = ch2.get_instance_id()
	if ch1 != null:
		ch1.connect("received", on_ch1)
	if ch2 != null:
		ch2.connect("received", on_ch2)

func get_crystal_node_count(node: Node) -> int:
	if node != null:
		return int(node.get("crystal_count"))
	return -1

func set_crystal_node_count(node: Node, val: int) -> bool:
	if node != null:
		node.set("crystal_count", val)
		return true
	return false

func select_channel_nonblocking(channels: Array) -> Array:
	for ch in channels:
		if ch != null and not ch.is_empty():
			var val = ch.try_receive()
			return [ch, val]
	return []

func await_channel_select(channels: Array, timeout_sec: float = 0.0) -> Array:
	# 1. Immediate non-blocking check
	for ch in channels:
		if ch != null and not ch.is_empty():
			return [ch, ch.try_receive()]

	# 2. Cooperative polling across frames
	var start_time = Time.get_ticks_msec() / 1000.0
	while true:
		for ch in channels:
			if ch != null and not ch.is_empty():
				return [ch, ch.try_receive()]
		if timeout_sec > 0.0 and (Time.get_ticks_msec() / 1000.0 - start_time) >= timeout_sec:
			break
		await get_tree().process_frame
	return []

# WorkerThreadPool Background Processing
func start_worker_thread_channel_producer(ch: RefCounted, count: int, prefix: String) -> int:
	var task = func():
		for i in range(count):
			ch.send("%s_%d" % [prefix, i])
	return WorkerThreadPool.add_task(task)

func wait_for_worker_task(task_id: int) -> void:
	WorkerThreadPool.wait_for_task_completion(task_id)

# Container Mutation & Interop
func mutate_dictionary(dict: Dictionary) -> Dictionary:
	dict["gdscript_key"] = "gdscript_value"
	dict["added_count"] = 42
	return dict

func mutate_array(arr: Array) -> Array:
	arr.append("appended_by_gdscript")
	return arr

func invoke_callable(cb: Callable, arg: String) -> Variant:
	if cb.is_valid():
		return cb.call(arg)
	return null

func drain_channel_async(ch: RefCounted) -> Array:
	var items = []
	while ch != null and not ch.is_empty():
		items.append(ch.try_receive())
	return items



