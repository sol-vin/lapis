# =============================================================================
# Crystal <-> GDScript Interop Round-Trip Stress Benchmark
# =============================================================================
# Tests cross-boundary dispatch performance (50,000 iterations)
# between Crystal and GDScript across Variant boundary types:
# Int, Float, String, Vector3, Node, Dictionary.

require "../../../src/lapis"

class CrystalInteropReceiver < Godot::Node
  def recv_int(val : Int64) : Int64
    val + 1
  end

  def recv_float(val : Float64) : Float64
    val + 1.0
  end

  def recv_string(val : String) : String
    val
  end

  def recv_vector3(val : Godot::Vector3) : Godot::Vector3
    val
  end

  def recv_node(val : Godot::Node?) : Godot::Node?
    val
  end

  def recv_dictionary(val : Godot::Dictionary) : Godot::Dictionary
    val
  end
end

mode = ARGV[0]? || "cr_to_gd_int"
count = (ARGV[1]? || "50000").to_i

# Create GDScript receiver object dynamically
gd_script = Godot::GDScript.new
gd_script.source_code = <<-GDSCRIPT
extends Node

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
GDSCRIPT
gd_script.reload(true)

gd_node = Godot::Node.new
gd_node.set_script(gd_script)

crystal_node = CrystalInteropReceiver.new

start_time = Time.instant
elapsed_ms = 0.0

case mode.downcase
when "cr_to_gd_int", "crystal_to_gdscript_int", "int"
  count.times do |i|
    gd_node.call_i64("recv_int", i.to_i64)
  end
  elapsed_ms = (Time.instant - start_time).total_milliseconds

when "cr_to_gd_float", "crystal_to_gdscript_float", "float"
  count.times do |i|
    gd_node.call_f64("recv_float", i.to_f64)
  end
  elapsed_ms = (Time.instant - start_time).total_milliseconds

when "cr_to_gd_string", "crystal_to_gdscript_string", "string"
  payload = "payload"
  count.times do
    gd_node.call_str("recv_string", payload)
  end
  elapsed_ms = (Time.instant - start_time).total_milliseconds

when "cr_to_gd_vector3", "crystal_to_gdscript_vector3", "vector3"
  vec = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
  count.times do
    gd_node.call("recv_vector3", vec)
  end
  elapsed_ms = (Time.instant - start_time).total_milliseconds

when "cr_to_gd_node", "crystal_to_gdscript_node", "node"
  count.times do
    gd_node.call_obj("recv_node", crystal_node)
  end
  elapsed_ms = (Time.instant - start_time).total_milliseconds

when "cr_to_gd_dictionary", "crystal_to_gdscript_dictionary", "dictionary"
  dict = Godot::Dictionary.new
  dict["key"] = 1
  count.times do
    gd_node.call("recv_dictionary", dict)
  end
  elapsed_ms = (Time.instant - start_time).total_milliseconds

# --- GDScript calling Crystal ---
when "gd_to_cr_int", "gdscript_to_crystal_int"
  elapsed_ms = gd_node.call_f64("run_gd_to_crystal", crystal_node, "int", count)

when "gd_to_cr_float", "gdscript_to_crystal_float"
  elapsed_ms = gd_node.call_f64("run_gd_to_crystal", crystal_node, "float", count)

when "gd_to_cr_string", "gdscript_to_crystal_string"
  elapsed_ms = gd_node.call_f64("run_gd_to_crystal", crystal_node, "string", count)

when "gd_to_cr_vector3", "gdscript_to_crystal_vector3"
  elapsed_ms = gd_node.call_f64("run_gd_to_crystal", crystal_node, "vector3", count)

when "gd_to_cr_node", "gdscript_to_crystal_node"
  elapsed_ms = gd_node.call_f64("run_gd_to_crystal", crystal_node, "node", count)

when "gd_to_cr_dictionary", "gdscript_to_crystal_dictionary"
  elapsed_ms = gd_node.call_f64("run_gd_to_crystal", crystal_node, "dictionary", count)

else
  count.times do |i|
    gd_node.call_i64("recv_int", i.to_i64)
  end
  elapsed_ms = (Time.instant - start_time).total_milliseconds
end

puts "InteropRoundTrip #{mode} #{count} calls: #{elapsed_ms.round(2)} ms"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"

crystal_node.free
gd_node.free
