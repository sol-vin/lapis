# =============================================================================
# LibGodot Test Suite: Multi-Frame TileMap Coordinate Systems & Layer Operations
# =============================================================================

include Lapis::Test

test_suite "TileMapMultiFrame" do
  test "TileMap coordinate translation between map grid and local space across frames" do
    assert_no_leak(max_delta_objects: 5, name: "TileMap coordinate translation") do
      tilemap = Godot.create(Godot::TileMap)
      tileset = Godot.create(Godot::TileSet)
      tileset.set_tile_size(Godot::Vector2i.new(32, 32))
      tilemap.set_tileset(tileset)
      root.add_child(tilemap)

      skip_frames(2)

      # Test map_to_local and local_to_map conversions
      # In Godot TileMap with 32x32 tiles, map cell (0, 0) center is at (16.0, 16.0)
      local_pos = tilemap.map_to_local(Godot::Vector2i.new(0, 0))
      assert_approx_eq local_pos.x.to_f32, 16.0_f32
      assert_approx_eq local_pos.y.to_f32, 16.0_f32

      # Cell (5, 10): center at (5 * 32 + 16, 10 * 32 + 16) = (176.0, 336.0)
      local_5_10 = tilemap.map_to_local(Godot::Vector2i.new(5, 10))
      assert_approx_eq local_5_10.x.to_f32, 176.0_f32
      assert_approx_eq local_5_10.y.to_f32, 336.0_f32

      # Reverse conversion: local_to_map
      map_coord = tilemap.local_to_map(Godot::Vector2.new(176.0, 336.0))
      assert_eq map_coord.x, 5
      assert_eq map_coord.y, 10

      root.remove_child(tilemap)
      tilemap.destroy
    end
  end

  test "TileMap layer management, enabling/disabling, and quadrant size configuration" do
    assert_no_leak(max_delta_objects: 5, name: "TileMap layer operations") do
      tilemap = Godot.create(Godot::TileMap)
      tilemap.set_rendering_quadrant_size(16_i64)
      root.add_child(tilemap)

      # Layer 0 exists by default
      assert_true tilemap.get_layers_count >= 1_i64

      # Add a layer
      tilemap.add_layer(1_i64)
      assert_eq tilemap.get_layers_count, 2_i64

      tilemap.set_layer_name(1_i64, "ForegroundDecals")
      assert_eq tilemap.get_layer_name(1_i64), "ForegroundDecals"

      tilemap.set_layer_enabled(1_i64, false)
      assert_false tilemap.is_layer_enabled(1_i64)

      tilemap.set_layer_enabled(1_i64, true)
      assert_true tilemap.is_layer_enabled(1_i64)

      skip_frames(2)

      # Remove layer
      tilemap.remove_layer(1_i64)
      assert_eq tilemap.get_layers_count, 1_i64

      root.remove_child(tilemap)
      tilemap.destroy
    end
  end
end
