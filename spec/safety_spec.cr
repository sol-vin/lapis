require "./spec_helper"

{% begin %}
  node SpecMassivePropertyNode < Node do
    {% for i in 1..220 %}
      @[Export]
      property prop_{{i.id}} : Int32 = {{i}}
    {% end %}

    signal multi_signal_1(a : Int32, b : Int32, c : Int32, d : Int32, e : Int32, f : Int32, g : Int32, h : Int32, i : Int32, j : Int32)
  end
{% end %}

node SpecFullTypesNode < Node do
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

node SpecProcessPrecisionNode < Node do
  property last_delta : Float64 = 0.0
  property physics_delta : Float64 = 0.0

  def _process(delta : Float64) : Void
    @last_delta = delta
  end

  def _physics_process(delta : Float64) : Void
    @physics_delta = delta
  end
end

describe "LibGodot Safety, GC Retention & Dynamic Scaling" do
  describe "Boehm GC Lifetime & Bridge Instance Tracking" do
    it "retains Crystal node instances across GC stress collections" do
      dummy_ptr = Pointer(Void).new(0x12345678_u64)
      player_inst = SpecPlayer.new(dummy_ptr)

      boxed_ptr = Box.box(player_inst)
      Godot::Bridge.alive_instances[boxed_ptr] = player_inst

      # Force GC allocations
      500.times do |i|
        _s = "gc_stress_allocation_#{i}" * 50
        _a = (0..50).to_a
      end
      GC.collect

      Godot::Bridge.alive_instances.has_key?(boxed_ptr).should be_true
      Godot::Bridge.alive_instances[boxed_ptr].same?(player_inst).should be_true

      # Cleanup
      Godot::Bridge.alive_instances.delete(boxed_ptr)
      Godot::Bridge.alive_instances.has_key?(boxed_ptr).should be_false
    end
  end

  describe "Dynamic Scaling" do
    it "scales to 220+ properties without buffer limits" do
      entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "SpecMassivePropertyNode" }.not_nil!
      entry.properties.size.should eq(220)
      entry.signals.first.args.size.should eq(10)

      inst = SpecMassivePropertyNode.new
      inst.prop_1.should eq(1)
      inst.prop_220.should eq(220)
    end
  end

  describe "Property Set/Get Round-Trip across Variant Types" do
    it "dispatches property reads and writes via pointer buffers" do
      node = SpecFullTypesNode.new

      # Float32
      buf_f64 = Pointer(Float64).malloc(1)
      buf_f64.value = 12.34_f64
      node._godot_set_property("f32_val", buf_f64.as(Void*))
      (node.f32_val - 12.34_f32).abs.should be < 0.001_f32

      # Float64
      buf_f64.value = 2.718281828459045
      node._godot_set_property("f64_val", buf_f64.as(Void*))
      node.f64_val.should eq(2.718281828459045)

      # Int32
      buf_i64 = Pointer(Int64).malloc(1)
      buf_i64.value = 12345_i64
      node._godot_set_property("i32_val", buf_i64.as(Void*))
      node.i32_val.should eq(12345)

      # Int64
      buf_i64.value = 999999999999_i64
      node._godot_set_property("i64_val", buf_i64.as(Void*))
      node.i64_val.should eq(999999999999_i64)

      # Bool
      buf_u8 = Pointer(UInt8).malloc(1)
      buf_u8.value = 1_u8
      node._godot_set_property("bool_val", buf_u8.as(Void*))
      node.bool_val.should be_true

      # Vector2i
      buf_v2i = Pointer(Vector2i).malloc(1)
      buf_v2i.value = Vector2i.new(77, 88)
      node._godot_set_property("v2i_val", buf_v2i.as(Void*))
      node.v2i_val.should eq(Vector2i.new(77, 88))

      # Vector3i
      buf_v3i = Pointer(Vector3i).malloc(1)
      buf_v3i.value = Vector3i.new(111, 222, 333)
      node._godot_set_property("v3i_val", buf_v3i.as(Void*))
      node.v3i_val.should eq(Vector3i.new(111, 222, 333))

      # Rect2
      buf_rect = Pointer(Rect2).malloc(1)
      buf_rect.value = Rect2.new(1.0, 2.0, 30.0, 40.0)
      node._godot_set_property("rect_val", buf_rect.as(Void*))
      node.rect_val.size.x.should eq(30.0_f32)
    end
  end

  describe "64-bit Float Precision in Virtual Dispatch" do
    it "preserves double precision in _process and _physics_process" do
      p_node = SpecProcessPrecisionNode.new
      test_delta = 0.016666666666666666_f64
      p_node._godot_call_virtual("_process", test_delta)
      p_node.last_delta.should eq(test_delta)

      physics_test_delta = 0.008333333333333333_f64
      p_node._godot_call_virtual("_physics_process", physics_test_delta)
      p_node.physics_delta.should eq(physics_test_delta)
    end
  end

  describe "Defensive Null-Pointer Checks & Robustness" do
    it "safely handles Node2D transform properties on unattached wrapper" do
      null_node = Godot::Node2D.new
      null_node.position = Vector2.new(10.0, 20.0)
      null_node.position.x.should eq(10.0_f32)
      null_node.rotation = 1.57_f32
      null_node.rotation.should eq(1.57_f32)
      null_node.scale = Vector2.new(2.0, 2.0)
      null_node.scale.x.should eq(2.0_f32)
    end

    it "safely queries CharacterBody3D and Input without engine crash" do
      null_3d = Godot::CharacterBody3D.new
      null_3d.is_on_floor.should be_false
      null_3d.velocity = Vector3.new(0.0, 5.0, 0.0)
      null_3d.move_and_slide.should be_false

      Godot::Input.is_action_just_released("ui_accept").should be_false
      Godot::Input.get_vector("left", "right", "up", "down").should eq(Vector2::ZERO)
    end
  end
end
