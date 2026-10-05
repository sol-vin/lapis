# =============================================================================
# LibGodot Test Suite: Exhaustive Spatial Queries & Raycast Builder Invariants
# =============================================================================
# Verifies 2D and 3D direct space raycast builder chaining:
# - to / from endpoints
# - exclude arrays and single objects
# - collision mask filtering
# - collide_with_areas vs collide_with_bodies toggles
# - query execution and nil safety when no intersection occurs

include Lapis::Test

node SpatialExhaustive2DHost < Godot::Node2D do
  property dummy_prop : Int32 = 0
end

node SpatialExhaustive3DHost < Godot::Node3D do
  property dummy_prop : Int32 = 0
end

test_suite "SpatialPhysics" do
  test "RaycastBuilder2D builds query parameters with full fluent chaining" do
    host = Godot.create(SpatialExhaustive2DHost)

    builder = host.raycast2d
      .to(Godot::Vector2.new(100.0, 50.0))
      .exclude(host)
      .mask(0b0011)
      .areas(false)
      .bodies(true)

    assert_eq builder.to_pos, Godot::Vector2.new(100.0, 50.0)
    assert_eq builder.mask_val, 0b0011_u32
    assert_false builder.collide_with_areas?
    assert_true builder.collide_with_bodies?
    assert_eq builder.exclude_list.size, 1

    # In empty test world, query returns nil safely
    hit = builder.query
    assert_nil hit

    host.destroy
  end

  test "RaycastBuilder3D builds query parameters with full fluent chaining" do
    host = Godot.create(SpatialExhaustive3DHost)

    builder = host.raycast3d
      .to(Godot::Vector3.new(0.0, 20.0, -10.0))
      .exclude(host)
      .mask(0b0100)
      .areas(true)
      .bodies(false)

    assert_eq builder.to_pos, Godot::Vector3.new(0.0, 20.0, -10.0)
    assert_eq builder.mask_val, 0b0100_u32
    assert_true builder.collide_with_areas?
    assert_false builder.collide_with_bodies?
    assert_eq builder.exclude_list.size, 1

    # In empty test world, query returns nil safely
    hit = builder.query
    assert_nil hit

    host.destroy
  end

  test "Directional raycast methods handle distance and direction" do
    host = Godot.create(SpatialExhaustive2DHost)
    hit = host.raycast(Godot::Vector2.new(1.0, 0.0), distance: 50.0)
    assert_nil hit
    host.destroy
  end
end
