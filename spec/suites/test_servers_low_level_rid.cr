# =============================================================================
# LibGodot Test Suite: Low-Level Server APIs & Direct RID Manipulation
# =============================================================================
#
# Tests direct RID creation, configuration, and destruction on RenderingServer,
# PhysicsServer2D, PhysicsServer3D, and AudioServer without SceneTree nodes.
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "ServersRID" do
  test "RenderingServer direct canvas item RID creation and destruction" do
    rs = Godot::RenderingServer.instance
    assert_not_nil rs

    ci_rid = rs.canvas_item_create
    assert_true ci_rid > 0_i64, "Created canvas item RID must be valid"

    # Configure canvas item properties directly via RID
    rs.canvas_item_set_visible(ci_rid, true)
    rs.canvas_item_set_modulate(ci_rid, Godot::Color::WHITE)

    # Free RID directly on server
    rs.free_rid(ci_rid)
  end

  test "PhysicsServer2D direct body and collision shape RID lifecycle" do
    ps2d = Godot::PhysicsServer2D.instance
    assert_not_nil ps2d

    body_rid = ps2d.body_create
    assert_true body_rid > 0_i64, "Created 2D physics body RID must be valid"

    shape_rid = ps2d.circle_shape_create
    assert_true shape_rid > 0_i64, "Created circle shape RID must be valid"

    # Attach shape to body with default transform
    ps2d.body_add_shape(body_rid, shape_rid, Godot::Transform2D.new)
    assert_eq ps2d.body_get_shape_count(body_rid), 1_i64

    # Free RIDs
    ps2d.free_rid(shape_rid)
    ps2d.free_rid(body_rid)
  end

  test "PhysicsServer3D direct body RID manipulation" do
    ps3d = Godot::PhysicsServer3D.instance
    assert_not_nil ps3d

    body3d_rid = ps3d.body_create
    assert_true body3d_rid > 0_i64, "Created 3D physics body RID must be valid"

    ps3d.body_set_mode(body3d_rid, 0_i64) # BODY_MODE_STATIC
    assert_eq ps3d.body_get_mode(body3d_rid).to_i64, 0_i64

    ps3d.free_rid(body3d_rid)
  end

  test "AudioServer master bus queries and volume manipulation" do
    audio_server = Godot::AudioServer.instance
    assert_not_nil audio_server

    bus_count = audio_server.get_bus_count
    assert_true bus_count >= 1_i64, "At least master audio bus must exist"

    master_name = audio_server.get_bus_name(0_i64)
    assert_eq master_name, "Master"

    # Check mute state
    initial_mute = audio_server.is_bus_mute(0_i64)
    audio_server.set_bus_mute(0_i64, !initial_mute)
    assert_eq audio_server.is_bus_mute(0_i64), !initial_mute

    # Restore original mute state
    audio_server.set_bus_mute(0_i64, initial_mute)
  end
end
