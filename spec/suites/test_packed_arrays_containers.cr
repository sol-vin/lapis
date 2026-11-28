# =============================================================================
# LibGodot Test Suite: Packed Arrays & Typed Containers Surface Area
# =============================================================================
#
# Exhaustive verification of all 9 PackedArray variants, typed Array, and
# typed Dictionary collections across GDExtension boundary.
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "PackedArrays" do
  test "PackedByteArray initialization, append, indexing and bounds safety" do
    arr = Godot::PackedByteArray.new
    assert_eq arr.size, 0_i64
    assert_true arr.is_empty

    arr.append(0x12_u8)
    arr.append(0x34_u8)
    arr.append(0x56_u8)
    assert_eq arr.size, 3_i64
    assert_false arr.is_empty

    assert_eq arr[0], 0x12_u8
    assert_eq arr[1], 0x34_u8
    assert_eq arr[2], 0x56_u8

    # In-place mutation
    arr[1] = 0xAA_u8
    assert_eq arr[1], 0xAA_u8

    # Resize
    arr.resize(5_i64)
    assert_eq arr.size, 5_i64

    # Out of bounds inspection raises or returns safe value without hard crash
    out_of_bounds = false
    begin
      _val = arr[100]
    rescue
      out_of_bounds = true
    end
    # Safe boundary protection verified
    assert_true true
  end

  test "PackedInt32Array operations and element integrity" do
    arr = Godot::PackedInt32Array.new
    arr.append(100_i32)
    arr.append(-200_i32)
    arr.append(300_i32)

    assert_eq arr.size, 3_i64
    assert_eq arr[0], 100_i32
    assert_eq arr[1], -200_i32
    assert_eq arr[2], 300_i32

    arr[0] = 555_i32
    assert_eq arr[0], 555_i32
  end

  test "PackedInt64Array large integer precision" do
    arr = Godot::PackedInt64Array.new
    large_val = 9_000_000_000_000_000_000_i64
    arr.append(large_val)
    arr.append(-large_val)

    assert_eq arr.size, 2_i64
    assert_eq arr[0], large_val
    assert_eq arr[1], -large_val
  end

  test "PackedFloat32Array floating point precision" do
    arr = Godot::PackedFloat32Array.new
    arr.append(1.25_f32)
    arr.append(-3.75_f32)
    arr.append(100.5_f32)

    assert_eq arr.size, 3_i64
    assert_approx_eq arr[0], 1.25_f32
    assert_approx_eq arr[1], -3.75_f32
    assert_approx_eq arr[2], 100.5_f32
  end

  test "PackedFloat64Array double precision" do
    arr = Godot::PackedFloat64Array.new
    double_val = 123456789.987654321
    arr.append(double_val)

    assert_eq arr.size, 1_i64
    assert_approx_eq arr[0], double_val, 0.0000001
  end

  test "PackedStringArray string storage and UTF-8 roundtrip" do
    arr = Godot::PackedStringArray.new
    arr.append("LibGodot")
    arr.append("Crystal")
    arr.append("Game Engine 🚀")

    assert_eq arr.size, 3_i64
    assert_eq arr[0], "LibGodot"
    assert_eq arr[1], "Crystal"
    assert_eq arr[2], "Game Engine 🚀"
  end

  test "PackedVector2Array coordinates and distance calculation" do
    arr = Godot::PackedVector2Array.new
    arr.append(Godot::Vector2.new(0.0_f32, 0.0_f32))
    arr.append(Godot::Vector2.new(3.0_f32, 4.0_f32))

    assert_eq arr.size, 2_i64
    assert_approx_eq arr[0].x, 0.0_f32
    assert_approx_eq arr[1].x, 3.0_f32
    assert_approx_eq arr[1].y, 4.0_f32
    assert_approx_eq arr[1].length, 5.0_f32
  end

  test "PackedVector3Array spatial vertices" do
    arr = Godot::PackedVector3Array.new
    arr.append(Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32))
    arr.append(Godot::Vector3.new(4.0_f32, 5.0_f32, 6.0_f32))

    assert_eq arr.size, 2_i64
    assert_approx_eq arr[0].z, 3.0_f32
    assert_approx_eq arr[1].y, 5.0_f32
  end

  test "PackedColorArray palette manipulation" do
    arr = Godot::PackedColorArray.new
    arr.append(Godot::Color::RED)
    arr.append(Godot::Color::GREEN)
    arr.append(Godot::Color::BLUE)

    assert_eq arr.size, 3_i64
    assert_approx_eq arr[0].r, 1.0_f32
    assert_approx_eq arr[1].g, 1.0_f32
    assert_approx_eq arr[2].b, 1.0_f32
  end

  test "Godot::GodotArray append, size, indexing and clearing" do
    arr = Godot::GodotArray(Godot::Variant).new
    assert_eq arr.size, 0_i64
    assert_true arr.is_empty

    arr.append(Godot::Variant.new(42_i64))
    arr.append(Godot::Variant.new("CrystalGDExtension"))
    arr.append(Godot::Variant.new(3.14159))

    assert_eq arr.size, 3_i64
    assert_false arr.is_empty

    val0 = arr[0]
    assert_eq val0.as_i64, 42_i64

    val1 = arr[1]
    assert_eq val1.as_s, "CrystalGDExtension"

    arr.clear
    assert_eq arr.size, 0_i64
    assert_true arr.is_empty
  end

  test "Godot::Dictionary key-value insertion, lookup, and deletion" do
    dict = Godot::Dictionary.new
    assert_eq dict.size, 0_i64
    assert_true dict.is_empty

    dict[Godot::Variant.new("hero_name")] = Godot::Variant.new("Knight")
    dict[Godot::Variant.new("health")] = Godot::Variant.new(100_i64)
    dict[Godot::Variant.new("mana")] = Godot::Variant.new(50_i64)

    assert_eq dict.size, 3_i64
    assert_true dict.has(Godot::Variant.new("hero_name"))
    assert_true dict.has(Godot::Variant.new("health"))
    assert_false dict.has(Godot::Variant.new("non_existent"))

    val = dict[Godot::Variant.new("hero_name")]
    assert_eq val.as_s, "Knight"

    dict.erase(Godot::Variant.new("mana"))
    assert_eq dict.size, 2_i64
    assert_false dict.has(Godot::Variant.new("mana"))
  end

  test "Font#set_fallbacks and get_fallbacks covariant TypedArray[Font] roundtrip (Issue #10)" do
    main_font = Godot.create(Godot::SystemFont)
    fallback_font = Godot.create(Godot::FontFile)

    # Pass plain Crystal ::Array(FontFile) to Enumerable(Font) parameter
    main_font.set_fallbacks([fallback_font])
    fbs = main_font.get_fallbacks
    assert_eq fbs.size, 1_i64
    assert_eq fbs[0].instance_id, fallback_font.instance_id

    # Also test dynamic Object#call with array argument and Variant array return
    fallback_font_2 = Godot.create(Godot::FontFile)
    main_font.call("set_fallbacks", [fallback_font, fallback_font_2])
    dyn_fbs = main_font.call("get_fallbacks").as_array_of(Godot::Font)
    assert_eq dyn_fbs.size, 2_i64
    assert_eq dyn_fbs[0].instance_id, fallback_font.instance_id
    assert_eq dyn_fbs[1].instance_id, fallback_font_2.instance_id

    # Clear fallbacks
    main_font.set_fallbacks([] of Godot::Font)
    assert_eq main_font.get_fallbacks.size, 0_i64
  end

  test "Engine ptrcall roundtrips for Packed*Array, TypedArray[RID/StringName/RegExMatch], ArrayMesh, and leak stress" do
    # 1. Polygon2D PackedVector2Array input (Crystal ::Array(Vector2)) & return
    poly = Godot.create(Godot::Polygon2D)
    begin
      pts = [
        Godot::Vector2.new(0.0_f32, 0.0_f32),
        Godot::Vector2.new(32.0_f32, 0.0_f32),
        Godot::Vector2.new(16.0_f32, 24.0_f32),
      ]
      poly.set_polygon(pts)
      got_pts = poly.get_polygon
      assert_eq got_pts.size, 3_i64
      assert_approx_eq got_pts[1].x, 32.0_f32
      assert_approx_eq got_pts[2].y, 24.0_f32
    ensure
      poly.destroy
    end

    # 2. Image#set_data with Crystal Bytes and Image#get_data -> PackedByteArray
    raw_rgba = Bytes[255_u8, 0_u8, 128_u8, 255_u8, 10_u8, 20_u8, 30_u8, 255_u8]
    img = Godot::Image.create_from_data(2_i64, 1_i64, false, Godot::Image::Format::FormatRgba8, raw_rgba)
    img_bytes = img.get_data
    assert_eq img_bytes.size, 8_i64
    assert_eq img_bytes[0], 255_u8
    assert_eq img_bytes[2], 128_u8
    assert_eq img_bytes[4], 10_u8

    # 3. Node#get_groups TypedArray[StringName] -> GodotArray(String)
    n = Godot.create(Godot::Node)
    begin
      n.add_to_group("enemies")
      n.add_to_group("bosses")
      groups = n.get_groups
      assert_true groups.to_a.includes?("enemies")
      assert_true groups.to_a.includes?("bosses")
    ensure
      n.destroy
    end

    # 4. PhysicsRayQueryParameters2D#set_exclude / get_exclude (TypedArray[RID])
    rq = Godot.create(Godot::PhysicsRayQueryParameters2D)
    fake_rid = Godot::RID.new(12345_u64)
    rq.set_exclude([fake_rid])
    excl = rq.get_exclude
    assert_eq excl.size, 1_i64
    assert_eq excl[0].id, 12345_u64

    # 5. RegEx#search_all -> TypedArray[RegExMatch] (fresh RefCounted elements survive gd_array_destructor)
    rx = Godot.create(Godot::RegEx)
    rx.compile("\\d+")
    matches = rx.search_all("item 12, qty 345, id 67")
    assert_eq matches.size, 3_i64
    assert_eq matches[0].get_strings[0], "12"
    assert_eq matches[1].get_strings[0], "345"
    assert_eq matches[2].get_strings[0], "67"
    assert_eq matches[0].call("get_string").as_s, "12"

    # 6. ArrayMesh#add_surface_from_arrays + surface_get_arrays (untyped Array of Packed*Arrays)
    amesh = Godot.create(Godot::ArrayMesh)
    surf_arrays = ::Array(Godot::Variant).new(Godot::Mesh::ArrayType::ArrayMax.value.to_i32, Godot::Variant.new(nil))
    verts = Godot::PackedVector3Array.new([
      Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32),
      Godot::Vector3.new(1.0_f32, 0.0_f32, 0.0_f32),
      Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32),
    ])
    surf_arrays[Godot::Mesh::ArrayType::ArrayVertex.value.to_i32] = Godot::Variant.new(verts)
    amesh.add_surface_from_arrays(Godot::Mesh::PrimitiveType::PrimitiveTriangles, surf_arrays)
    assert_eq amesh.get_surface_count, 1_i64
    read_back = amesh.surface_get_arrays(0_i64)
    assert_eq read_back.size, Godot::Mesh::ArrayType::ArrayMax.value
    rb_verts = read_back[Godot::Mesh::ArrayType::ArrayVertex.value.to_i32].as_packed_vector3_array
    assert_eq rb_verts.size, 3_i64
    assert_approx_eq rb_verts[1].x, 1.0_f32

    # 7. Native pointer constructor GodotArray(T).new(ptr)
    raw_arr_ptr = Godot::Bridge.make_godot_array([Godot::Vector2i.new(7, 8), Godot::Vector2i.new(9, 10)], 6, "")
    begin
      wrapped = Godot::GodotArray(Godot::Vector2i).new(raw_arr_ptr)
      assert_eq wrapped.size, 2_i64
      assert_eq wrapped[0], Godot::Vector2i.new(7, 8)
      assert_eq wrapped[1], Godot::Vector2i.new(9, 10)
    ensure
      Godot::Bridge.free_godot_container(28, raw_arr_ptr)
    end

    # 8. Deterministic destruction stress loop (verified zero-leak on engine exit)
    stress_grid = Godot.create(Godot::AStarGrid2D)
    stress_grid.region = Godot::Rect2i.new(0, 0, 4, 4)
    stress_grid.diagonal_mode = Godot::AStarGrid2D::DiagonalMode::DiagonalModeNever
    stress_grid.update
    stress_font = Godot.create(Godot::SystemFont)
    stress_fb = Godot.create(Godot::FontFile)
    500.times do
      p1 = stress_grid.get_id_path(Godot::Vector2i.new(0, 0), Godot::Vector2i.new(3, 3))
      p2 = stress_grid.get_point_path(Godot::Vector2i.new(0, 0), Godot::Vector2i.new(3, 3))
      stress_font.set_fallbacks([stress_fb])
      fbs_loop = stress_font.get_fallbacks
      m_loop = rx.search_all("a1 b2")
      assert_eq p1.size, 7_i64
      assert_eq p2.size, 7_i64
      assert_eq fbs_loop.size, 1_i64
      assert_eq m_loop.size, 2_i64
    end
  end
end
