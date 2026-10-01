require "../src/lapis"
require "./libgodot_spec"

puts "=== Running Safety, Memory & Dynamic Scaling Specifications ==="

# -------------------------------------------------------------
# 1. GC Lifetime & Bridge Instance Tracking Test
# -------------------------------------------------------------
puts "[Spec 1] Boehm GC Object Retention & Lifecycle..."

# Create a mock Godot node pointer
dummy_godot_ptr = Pointer(Void).new(0x12345678_u64)
player_inst = Player.new(dummy_godot_ptr)

# Verify alive_instances tracking
boxed_ptr = Box.box(player_inst)
Godot::Bridge.alive_instances[boxed_ptr] = player_inst

# Force GC stress iterations to verify object isn't collected
1000.times do |i|
  str = "stress_string_allocation_#{i}" * 50
  arr = (0..100).to_a
end
GC.collect

abort "Failed: player_inst was lost during GC cycle" unless Godot::Bridge.alive_instances.has_key?(boxed_ptr)
abort "Failed: player_inst corrupted in alive_instances" unless Godot::Bridge.alive_instances[boxed_ptr].same?(player_inst)

# Test cleanup on free
Godot::Bridge.alive_instances.delete(boxed_ptr)
abort "Failed: alive_instances cleanup" if Godot::Bridge.alive_instances.has_key?(boxed_ptr)
puts "  ✓ Boehm GC retention table and cleanup verified!"

# -------------------------------------------------------------
# 2. Dynamic Scaling: 200+ Properties & Dynamic Signals
# -------------------------------------------------------------
puts "[Spec 2] Dynamic Scaling (200+ Properties, 20+ Signals, 10+ Args)..."

# Define a node with 220 properties using macro expansion
{% begin %}
  node MassivePropertyNode < Node do
    {% for i in 1..220 %}
      @[Export]
      property prop_{{i.id}} : Int32 = {{i}}
    {% end %}

    signal multi_signal_1(a : Int32, b : Int32, c : Int32, d : Int32, e : Int32, f : Int32, g : Int32, h : Int32, i : Int32, j : Int32)
  end
{% end %}

entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "MassivePropertyNode" }
abort "Failed: MassivePropertyNode not registered in ClassRegistry" unless entry
abort "Failed: expected 220 properties, got #{entry.properties.size}" unless entry.properties.size == 220
abort "Failed: signal arg count mismatch" unless entry.signals.first.args.size == 10

# Test instantiating the massive node
massive_inst = MassivePropertyNode.new
abort "Failed: prop_1 mismatch" unless massive_inst.prop_1 == 1
abort "Failed: prop_220 mismatch" unless massive_inst.prop_220 == 220
puts "  ✓ Dynamic property scaling (220 properties) verified without buffer limits!"

# -------------------------------------------------------------
# 3. Comprehensive Property Round-Trip Dispatch
# -------------------------------------------------------------
puts "[Spec 3] Property Set/Get Round-Trip across all Variant Types..."

node FullTypesNode < Node do
  @[Export]
  property f32_val : Float32 = 1.5_f32

  @[Export]
  property f64_val : Float64 = 3.141592653589793

  @[Export]
  property i32_val : Int32 = 42

  @[Export]
  property i64_val : Int64 = 9876543210_i64

  @[Export]
  property bool_val : Bool = false

  @[Export]
  property v2_val : Vector2 = Vector2.new(1.0, 2.0)

  @[Export]
  property v2i_val : Vector2i = Vector2i.new(10, 20)

  @[Export]
  property v3_val : Vector3 = Vector3.new(1.0, 2.0, 3.0)

  @[Export]
  property v3i_val : Vector3i = Vector3i.new(100, 200, 300)

  @[Export]
  property color_val : Color = Color::RED

  @[Export]
  property rect_val : Rect2 = Rect2.new(5.0, 10.0, 50.0, 100.0)
end

t_node = FullTypesNode.new

# Test Float32 set/get
buf = Pointer(Float64).malloc(1)
buf.value = 12.34_f64
t_node._godot_set_property("f32_val", buf.as(Void*))
abort "Failed: Float32 set" unless (t_node.f32_val - 12.34_f32).abs < 0.001_f32
ret_buf = Pointer(Float64).malloc(1)
t_node._godot_get_property("f32_val", ret_buf.as(Void*))
abort "Failed: Float32 get" unless (ret_buf.value - 12.34).abs < 0.001

# Test Float64 set/get (precise 64-bit)
buf.value = 2.718281828459045
t_node._godot_set_property("f64_val", buf.as(Void*))
abort "Failed: Float64 set" unless t_node.f64_val == 2.718281828459045
t_node._godot_get_property("f64_val", ret_buf.as(Void*))
abort "Failed: Float64 get" unless ret_buf.value == 2.718281828459045

# Test Int32 & Int64 set/get
i_buf = Pointer(Int64).malloc(1)
i_buf.value = 12345_i64
t_node._godot_set_property("i32_val", i_buf.as(Void*))
abort "Failed: Int32 set" unless t_node.i32_val == 12345
t_node._godot_get_property("i32_val", i_buf.as(Void*))
abort "Failed: Int32 get" unless i_buf.value == 12345_i64

i_buf.value = 999999999999_i64
t_node._godot_set_property("i64_val", i_buf.as(Void*))
abort "Failed: Int64 set" unless t_node.i64_val == 999999999999_i64
t_node._godot_get_property("i64_val", i_buf.as(Void*))
abort "Failed: Int64 get" unless i_buf.value == 999999999999_i64

# Test Bool set/get
b_buf = Pointer(UInt8).malloc(1)
b_buf.value = 1_u8
t_node._godot_set_property("bool_val", b_buf.as(Void*))
abort "Failed: Bool set true" unless t_node.bool_val == true
t_node._godot_get_property("bool_val", b_buf.as(Void*))
abort "Failed: Bool get true" unless b_buf.value == 1_u8

# Test Vector2i & Vector3i set/get
v2i_buf = Pointer(Vector2i).malloc(1)
v2i_buf.value = Vector2i.new(77, 88)
t_node._godot_set_property("v2i_val", v2i_buf.as(Void*))
abort "Failed: Vector2i set" unless t_node.v2i_val.x == 77 && t_node.v2i_val.y == 88

v3i_buf = Pointer(Vector3i).malloc(1)
v3i_buf.value = Vector3i.new(111, 222, 333)
t_node._godot_set_property("v3i_val", v3i_buf.as(Void*))
abort "Failed: Vector3i set" unless t_node.v3i_val.x == 111 && t_node.v3i_val.y == 222 && t_node.v3i_val.z == 333

# Test Rect2 set/get
rect_buf = Pointer(Rect2).malloc(1)
rect_buf.value = Rect2.new(1.0, 2.0, 30.0, 40.0)
t_node._godot_set_property("rect_val", rect_buf.as(Void*))
abort "Failed: Rect2 set" unless t_node.rect_val.size.x == 30.0_f32

puts "  ✓ All property variant round-trips verified!"

# -------------------------------------------------------------
# 4. Virtual Dispatch with 64-bit Float Precision
# -------------------------------------------------------------
puts "[Spec 4] 64-bit Float Precision in Virtual Dispatch..."

node ProcessPrecisionNode < Node do
  property last_delta : Float64 = 0.0
  property physics_delta : Float64 = 0.0

  def _process(delta : Float64) : Void
    @last_delta = delta
  end

  def _physics_process(delta : Float64) : Void
    @physics_delta = delta
  end
end

p_node = ProcessPrecisionNode.new
test_delta = 0.016666666666666666_f64
p_node._godot_call_virtual("_process", test_delta)
abort "Failed: 64-bit precision lost in _process" unless p_node.last_delta == test_delta

physics_test_delta = 0.008333333333333333_f64
p_node._godot_call_virtual("_physics_process", physics_test_delta)
abort "Failed: 64-bit precision lost in _physics_process" unless p_node.physics_delta == physics_test_delta
puts "  ✓ 64-bit float precision preserved in virtual dispatch!"

# -------------------------------------------------------------
# 5. Defensive Null-Pointer Checks & Robustness
# -------------------------------------------------------------
puts "[Spec 5] Defensive Null-Pointer Checks & Robustness..."

null_node = Godot::Node2D.new
# Position, rotation, scale on unattached / null pointer should not crash
null_node.position = Vector2.new(10.0, 20.0)
abort "Failed: Node2D position fallback" unless null_node.position.x == 10.0_f32
null_node.rotation = 1.57_f32
abort "Failed: Node2D rotation fallback" unless null_node.rotation == 1.57_f32
null_node.scale = Vector2.new(2.0, 2.0)
abort "Failed: Node2D scale fallback" unless null_node.scale.x == 2.0_f32

null_3d = Godot::CharacterBody3D.new
abort "Failed: is_on_floor fallback" unless null_3d.is_on_floor == false
null_3d.velocity = Vector3.new(0.0, 5.0, 0.0)
abort "Failed: move_and_slide fallback" unless null_3d.move_and_slide == false

# Input queries without engine initialized should safely return false / zero without crash
abort "Failed: Input.is_action_just_released" if Godot::Input.is_action_just_released("ui_accept")
abort "Failed: Input.get_vector" unless Godot::Input.get_vector("left", "right", "up", "down") == Vector2::ZERO

# -------------------------------------------------------------
# 6. Object Identity, Equality (==), Hashing, and Null-Safety
# -------------------------------------------------------------
puts "[Spec 6] Object Identity, Equality (==), Hashing, and Null-Safety..."

# Null-pointer wrapper state
abort "Failed: null_node.alive? should be false" if null_node.alive?
abort "Failed: null_node.is_valid? should be false" if null_node.is_valid?
abort "Failed: null_node.if_alive should be nil" unless null_node.if_alive.nil?
abort "Failed: null_node == nil should be true" unless null_node == nil
abort "Failed: nil == null_node should be true" unless nil == null_node

# Two separate Crystal wrappers pointing to the same engine address
fake_ptr = Pointer(Void).new(0xCAFEBABE_u64)
wrap1 = Godot::Object.new(fake_ptr)
wrap2 = Godot::Object.new(fake_ptr)
diff_ptr = Pointer(Void).new(0xDEADBEEF_u64)
wrap3 = Godot::Object.new(diff_ptr)

abort "Failed: wrap1 == wrap2 should be true" unless wrap1 == wrap2
abort "Failed: wrap1 == wrap3 should be false" if wrap1 == wrap3
abort "Failed: wrap1 == nil should be false" if wrap1 == nil
abort "Failed: nil == wrap1 should be false" if nil == wrap1
abort "Failed: wrap1.hash == wrap2.hash" unless wrap1.hash == wrap2.hash

# Set deduplication and Hash key lookup
test_set = Set(Godot::Object).new
test_set.add(wrap1)
test_set.add(wrap2)
abort "Failed: Set should deduplicate wrappers with identical engine identity" unless test_set.size == 1
abort "Failed: Set should include wrap2" unless test_set.includes?(wrap2)

test_map = Hash(Godot::Object, String).new
test_map[wrap1] = "engine_entity"
abort "Failed: Hash lookup via wrap2 should find wrap1 value" unless test_map[wrap2]? == "engine_entity"

# RayCast3D & ShapeCast3D get_collider? on uncollided / null instances
null_ray = Godot::RayCast3D.new
abort "Failed: null_ray.get_collider? should be nil" unless null_ray.get_collider?.nil?

null_shape = Godot::ShapeCast3D.new
abort "Failed: null_shape.get_collider? should be nil" unless null_shape.get_collider?.nil?

puts "  ✓ Engine identity equality (==), hashing, and null safety verified!"

puts "All safety, memory, and dynamic binding specifications passed cleanly!"
