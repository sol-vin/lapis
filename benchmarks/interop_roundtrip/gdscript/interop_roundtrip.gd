extends SceneTree

# =============================================================================
# GDScript <-> Crystal Interop Round-Trip Stress Benchmark
# =============================================================================
# Benchmarks high-frequency cross-boundary dispatch (50,000 round-trip calls)
# across Godot Variant types: Int, Float, String, Vector3, Node, and Dictionary.

class ReceiverNode extends Node:
	func recv_int(val: int) -> int:
		return val + 1

	func recv_float(val: float) -> float:
		return val + 1.0

	func recv_string(val: String) -> String:
		return val

	func recv_vector3(val: Vector3) -> Vector3:
		return val

	func recv_node(val: Node) -> Node:
		return val

	func recv_dictionary(val: Dictionary) -> Dictionary:
		return val

	# Stress test GDScript calling Crystal node 50,000 times
	func run_gd_to_crystal(crystal_target: Object, mode: String, count: int) -> float:
		var start_time = Time.get_ticks_usec()
		match mode:
			"int":
				for i in range(count):
					crystal_target.call("recv_int", i)
			"float":
				for i in range(count):
					crystal_target.call("recv_float", float(i))
			"string":
				var s = "payload"
				for i in range(count):
					crystal_target.call("recv_string", s)
			"vector3":
				var v = Vector3(1.0, 2.0, 3.0)
				for i in range(count):
					crystal_target.call("recv_vector3", v)
			"node":
				for i in range(count):
					crystal_target.call("recv_node", self)
			"dictionary":
				var d = {"key": 1}
				for i in range(count):
					crystal_target.call("recv_dictionary", d)
		return (Time.get_ticks_usec() - start_time) / 1000.0

func _init():
	var args = OS.get_cmdline_user_args()
	var mode = "int"
	var count = 50000
	if args.size() > 0:
		mode = args[0]
	if args.size() > 1:
		count = int(args[1])

	var receiver = ReceiverNode.new()
	var start_time = Time.get_ticks_usec()
	match mode:
		"int":
			for i in range(count):
				receiver.recv_int(i)
		"float":
			for i in range(count):
				receiver.recv_float(float(i))
		"string":
			var s = "payload"
			for i in range(count):
				receiver.recv_string(s)
		"vector3":
			var v = Vector3(1.0, 2.0, 3.0)
			for i in range(count):
				receiver.recv_vector3(v)
		"node":
			for i in range(count):
				receiver.recv_node(null)
		"dictionary":
			var d = {"key": 1}
			for i in range(count):
				receiver.recv_dictionary(d)

	var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
	print("GDScript Internal %s %d calls: %.2f ms" % [mode, count, elapsed])
	print("ELAPSED_MS: %.2f" % elapsed)
	receiver.free()
	quit(0)
