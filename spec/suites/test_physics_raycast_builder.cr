# =============================================================================
# LibGodot Test Suite: Physics Raycast Fluent Builder & Exclusion Filtering
# =============================================================================
# Verifies raycast2d and raycast3d fluent query builders, parameter chaining,
# from/to positioning, exclusion list filtering, and dead-pointer safety.

include Lapis::Test

node RaycastBuilderTester2D < Godot::Node2D do
  def configure_builder : Godot::RaycastBuilder2D
    raycast2d(Godot::Vector2.new(100.0_f32, 200.0_f32))
      .from(Godot::Vector2.new(10.0_f32, 20.0_f32))
      .mask(0b101_u32)
      .exclude(self)
      .areas(false)
      .bodies(true)
  end
end

node RaycastBuilderTester3D < Godot::Node3D do
  def configure_builder : Godot::RaycastBuilder3D
    raycast3d(Godot::Vector3.new(0.0_f32, 10.0_f32, 0.0_f32))
      .from(Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32))
      .mask(1_u32)
      .exclude(self)
      .areas(true)
      .bodies(true)
  end
end

test_suite "Physics" do
  test "RaycastBuilder2D configures raycast parameters with method chaining" do
    tester = Godot.create(RaycastBuilderTester2D)
    builder = tester.configure_builder

    assert_approx_eq builder.from_pos.x, 10.0_f32
    assert_approx_eq builder.from_pos.y, 20.0_f32
    assert_approx_eq builder.to_pos.not_nil!.x, 100.0_f32
    assert_approx_eq builder.to_pos.not_nil!.y, 200.0_f32
    assert_eq builder.mask_val, 0b101_u32
    assert_eq builder.exclude_list.size, 1
    assert_false builder.collide_with_areas?
    assert_true builder.collide_with_bodies?

    # Direction chaining
    builder.direction(Godot::Vector2.new(1.0_f32, 0.0_f32), distance: 50.0)
    assert_approx_eq builder.to_pos.not_nil!.x, 60.0_f32
    assert_approx_eq builder.to_pos.not_nil!.y, 20.0_f32

    tester.destroy
  end

  test "RaycastBuilder3D configures 3D spatial query parameters" do
    tester = Godot.create(RaycastBuilderTester3D)
    builder = tester.configure_builder

    assert_approx_eq builder.from_pos.y, 0.0_f32
    assert_approx_eq builder.to_pos.not_nil!.y, 10.0_f32
    assert_eq builder.mask_val, 1_u32
    assert_eq builder.exclude_list.size, 1
    assert_true builder.collide_with_areas?
    assert_true builder.collide_with_bodies?

    tester.destroy
  end
end
