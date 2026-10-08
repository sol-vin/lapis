# =============================================================================
# LibGodot Test Suite: Object Downcasting, Casting Aliases & Typed Re-Wrapping
# =============================================================================

include Lapis::Test

test_suite "ObjectCasting" do
  test "Pillar 1: as_a?(T) and as_a(T) typed polymorphic downcasting" do
    sprite = Godot.create(Godot::Sprite2D)
    sprite.call("set_name", "TargetSprite")

    # Upcast to base Godot::Object wrapper
    base_obj = Godot::Object.new(sprite.pointer)

    # 1. Downcast to Sprite2D via as_a?
    casted_opt = base_obj.as_a?(Godot::Sprite2D)
    assert_not_nil casted_opt
    if s = casted_opt
      assert_eq s.call_str("get_name"), "TargetSprite"
      assert_true s.alive?
    end

    # 2. Downcast to Node2D ancestor via as_a?
    node2d_opt = base_obj.as_a?(Godot::Node2D)
    assert_not_nil node2d_opt
    if n = node2d_opt
      assert_eq n.call_str("get_name"), "TargetSprite"
    end

    # 3. Downcast via strict as_a (raises on failure)
    strict_sprite = base_obj.as_a(Godot::Sprite2D)
    assert_eq strict_sprite.call_str("get_name"), "TargetSprite"

    sprite.destroy
  end

  test "Pillar 2: Shorthand aliases (cast_to?, cast_to, as_t?, as_t) parity" do
    control = Godot.create(Godot::Control)
    control.call("set_name", "UIElement")
    base_obj = Godot::Object.new(control.pointer)

    # cast_to? and cast_to
    c1 = base_obj.cast_to?(Godot::Control)
    assert_not_nil c1
    c2 = base_obj.cast_to(Godot::Control)
    assert_eq c2.call_str("get_name"), "UIElement"

    # as_t? and as_t
    c3 = base_obj.as_t?(Godot::Control)
    assert_not_nil c3
    c4 = base_obj.as_t(Godot::Control)
    assert_eq c4.call_str("get_name"), "UIElement"

    control.destroy
  end

  test "Pillar 3: Class-level casting helpers (Godot::Object.cast_to? and cast_to)" do
    node3d = Godot.create(Godot::Node3D)
    node3d.call("set_name", "SpatialNode")
    base_obj = Godot::Object.new(node3d.pointer)

    # Class-level cast_to?
    res_opt = Godot::Object.cast_to?(base_obj, Godot::Node3D)
    assert_not_nil res_opt
    if s = res_opt
      assert_eq s.call_str("get_name"), "SpatialNode"
    end

    # Class-level cast_to (strict)
    strict_res = Godot::Object.cast_to(base_obj, Godot::Node3D)
    assert_eq strict_res.call_str("get_name"), "SpatialNode"

    node3d.destroy
  end

  test "Pillar 4: Incompatible type handling (nil return and TypeCastError)" do
    sprite = Godot.create(Godot::Sprite2D)
    base_obj = Godot::Object.new(sprite.pointer)

    # Incompatible cast to Camera3D returns nil on as_a? / cast_to? / as_t?
    assert_nil base_obj.as_a?(Godot::Camera3D)
    assert_nil base_obj.cast_to?(Godot::Camera3D)
    assert_nil base_obj.as_t?(Godot::Camera3D)

    # Incompatible strict cast raises TypeCastError
    assert_raises(TypeCastError) do
      base_obj.as_a(Godot::Camera3D)
    end

    assert_raises(TypeCastError) do
      base_obj.cast_to(Godot::Camera3D)
    end

    assert_raises(TypeCastError) do
      base_obj.as_t(Godot::Camera3D)
    end

    sprite.destroy
  end

  test "Pillar 5: Dead pointer and uninitialized wrapper safety" do
    sprite = Godot.create(Godot::Sprite2D)
    base_obj = Godot::Object.new(sprite.pointer)

    # Destroy object
    sprite.destroy
    assert_false sprite.alive?

    # Casting destroyed object returns nil without memory fault
    assert_nil base_obj.as_a?(Godot::Sprite2D)
    assert_nil base_obj.cast_to?(Godot::Sprite2D)

    # Uninitialized wrapper with null pointer returns nil safely
    null_obj = Godot::Object.new(Pointer(Void).null)
    assert_nil null_obj.as_a?(Godot::Sprite2D)
    assert_nil null_obj.cast_to?(Godot::Sprite2D)
  end

  test "Pillar 6: RefCounted downcasting and lifecycle safety" do
    ref = Godot.create(Godot::RefCounted)
    assert_true ref.is_a?(Godot::RefCounted)
    base_obj = Godot::Object.new(ref.pointer)

    # Cast to RefCounted preserves valid reference count
    casted_ref = base_obj.as_a?(Godot::RefCounted)
    assert_not_nil casted_ref
    if r = casted_ref
      assert_true r.get_reference_count >= 1
    end
  end

  test "Pillar 7: Mathematical zero memory leak verification" do
    assert_no_leak do
      20.times do
        node = Godot.create(Godot::Node2D)
        base = Godot::Object.new(node.pointer)
        _ = base.as_a?(Godot::Node2D)
        _ = base.as_a?(Godot::CanvasItem)
        _ = base.cast_to?(Godot::Node)
        _ = base.as_a?(Godot::Camera3D) # Incompatible
        node.destroy
      end
    end
  end
end
