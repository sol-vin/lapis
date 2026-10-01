# =============================================================================
# LibGodot Test Suite: Core Built-ins, Math, Resources, Singletons
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "Core" do
  test "Vector2 arithmetic, length and normalize" do
    v1 = Godot::Vector2.new(3.0, 4.0)
    assert_approx_eq v1.length, 5.0_f32
    assert_approx_eq v1.length_squared, 25.0_f32

    v_norm = v1.normalized
    assert_approx_eq v_norm.length, 1.0_f32
    assert_approx_eq v_norm.x, 0.6_f32
    assert_approx_eq v_norm.y, 0.8_f32

    v2 = Godot::Vector2.new(1.0, 2.0)
    add = v1 + v2
    assert_eq add.x, 4.0_f32
    assert_eq add.y, 6.0_f32

    sub = v1 - v2
    assert_eq sub.x, 2.0_f32
    assert_eq sub.y, 2.0_f32

    dot = Godot::Vector2.new(1.0, 0.0).dot(Godot::Vector2.new(0.0, 1.0))
    assert_approx_eq dot, 0.0_f32
  end

  test "Vector2i grid coordinates" do
    v = Godot::Vector2i.new(10, 20)
    assert_eq v.x, 10
    assert_eq v.y, 20
    v_mul = v * 2
    assert_eq v_mul.x, 20
    assert_eq v_mul.y, 40
  end

  test "Vector3 arithmetic, dot and cross product" do
    v1 = Godot::Vector3.new(1.0, 0.0, 0.0)
    v2 = Godot::Vector3.new(0.0, 1.0, 0.0)
    cross = v1.cross(v2)
    assert_approx_eq cross.x, 0.0_f32
    assert_approx_eq cross.y, 0.0_f32
    assert_approx_eq cross.z, 1.0_f32

    dot = v1.dot(v2)
    assert_approx_eq dot, 0.0_f32
  end

  test "Color channel precision and constants" do
    c = Godot::Color.new(0.5, 0.25, 0.75, 1.0)
    assert_approx_eq c.r, 0.5_f32
    assert_approx_eq c.g, 0.25_f32
    assert_approx_eq c.b, 0.75_f32
    assert_approx_eq c.a, 1.0_f32

    white = Godot::Color::WHITE
    assert_approx_eq white.r, 1.0_f32
    assert_approx_eq white.g, 1.0_f32
    assert_approx_eq white.b, 1.0_f32
  end

  test "Rect2 bounds and position" do
    r = Godot::Rect2.new(10.0, 20.0, 50.0, 60.0)
    assert_eq r.position.x, 10.0_f32
    assert_eq r.position.y, 20.0_f32
    assert_eq r.size.x, 50.0_f32
    assert_eq r.size.y, 60.0_f32
  end

  test "Transform3D and Basis identity matrix" do
    t = Godot::Transform3D.new
    assert_approx_eq t.origin.x, 0.0_f32
    assert_approx_eq t.origin.y, 0.0_f32
    assert_approx_eq t.origin.z, 0.0_f32

    vec = Godot::Vector3.new(1.0, 2.0, 3.0)
    transformed = t.basis * vec
    assert_approx_eq transformed.x, 1.0_f32
    assert_approx_eq transformed.y, 2.0_f32
    assert_approx_eq transformed.z, 3.0_f32
  end

  test "Math.move_toward float precision" do
    moved32 = Math.move_toward(0.0_f32, 10.0_f32, 2.5_f32)
    assert_approx_eq moved32, 2.5_f32

    moved64 = Math.move_toward(10.0, 0.0, 3.0)
    assert_approx_eq moved64, 7.0
  end

  test "Godot::Range and Crystal Range cohesion" do
    cr_range = (10..100)
    g_range = cr_range.to_godot_range(5.0)
    assert_eq g_range.min_value, 10.0
    assert_eq g_range.max_value, 100.0
    assert_eq g_range.step, 5.0

    g_range.value = 55.0
    assert_approx_eq g_range.ratio, 0.5
    assert_true g_range.includes?(55)
    assert_false g_range.includes?(150)
  end

  test "Resource loading (Godot.load & preload)" do
    res = Godot.load("res://scenes/test_dummy_2d.tscn")
    assert_not_nil res
    assert_false res.pointer.null?, "res.pointer is null"

    scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_dummy_2d.tscn")
    assert_not_nil scene
    assert_false scene.pointer.null?, "scene.pointer is null"

    inst = scene.instantiate
    assert_not_nil inst
    assert_false inst.pointer.null?, "inst.pointer is null"
    assert_eq inst.name, "TestDummy2D"
    inst.destroy
    scene.destroy
    res.destroy
  end

  test "Input singleton method verification" do
    pressed = Godot::Input.is_key_pressed(4194305) # Key::KEY_ESCAPE
    assert_false pressed
  end
end
