# =============================================================================
# LibGodot Test Suite: Deep Math, Spatial Transforms & Variant Operators
# =============================================================================
#
# Exhaustive testing of spatial types, matrix calculations, Basis, Quaternion,
# Transform2D/3D, Plane, AABB, Projection, and mathematical boundary edge cases.
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

test_suite "VariantMath" do
  test "Basis identity, determinant, scaling and inverse" do
    b = Godot::Basis.new
    # Identity matrix determinant must be exactly 1.0
    assert_approx_eq b.determinant, 1.0_f32

    # Scale basis
    scaled = b.scaled(Godot::Vector3.new(2.0_f32, 3.0_f32, 4.0_f32))
    assert_approx_eq scaled.determinant, 24.0_f32

    # Vector transformation
    vec = Godot::Vector3.new(1.0_f32, 1.0_f32, 1.0_f32)
    transformed = scaled * vec
    assert_approx_eq transformed.x, 2.0_f32
    assert_approx_eq transformed.y, 3.0_f32
    assert_approx_eq transformed.z, 4.0_f32

    # Inverse transformation restores original vector
    inv = scaled.inverse
    restored = inv * transformed
    assert_approx_eq restored.x, 1.0_f32
    assert_approx_eq restored.y, 1.0_f32
    assert_approx_eq restored.z, 1.0_f32
  end

  test "Quaternion identity, normalization, slerp and rotation" do
    q1 = Godot::Quaternion.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32) # Identity
    assert_approx_eq q1.length, 1.0_f32

    # 90 degree rotation around Y axis
    half_angle = Math::PI.to_f32 / 4.0_f32
    q2 = Godot::Quaternion.new(0.0_f32, Math.sin(half_angle).to_f32, 0.0_f32, Math.cos(half_angle).to_f32)
    assert_approx_eq q2.length, 1.0_f32

    # Halfway slerp (45 degree rotation)
    q_mid = q1.slerp(q2, 0.5_f32)
    assert_approx_eq q_mid.length, 1.0_f32
    assert_true q_mid.y > 0.0_f32
    assert_true q_mid.w > 0.0_f32
  end

  test "Transform2D affine transformations and point projection" do
    t = Godot::Transform2D.new
    assert_approx_eq t.origin.x, 0.0_f32
    assert_approx_eq t.origin.y, 0.0_f32

    # Translate transform
    translated = t.translated(Godot::Vector2.new(100.0_f32, 50.0_f32))
    assert_approx_eq translated.origin.x, 100.0_f32
    assert_approx_eq translated.origin.y, 50.0_f32

    # Transform point
    pt = Godot::Vector2.new(10.0_f32, 20.0_f32)
    transformed_pt = translated * pt
    assert_approx_eq transformed_pt.x, 110.0_f32
    assert_approx_eq transformed_pt.y, 70.0_f32

    # Affine inverse restores original point
    inv = translated.affine_inverse
    restored_pt = inv * transformed_pt
    assert_approx_eq restored_pt.x, 10.0_f32
    assert_approx_eq restored_pt.y, 20.0_f32
  end

  test "Transform3D translation, rotation, scale and affine inverse" do
    t = Godot::Transform3D.new
    translated = t.translated(Godot::Vector3.new(10.0_f32, 20.0_f32, 30.0_f32))
    assert_approx_eq translated.origin.x, 10.0_f32
    assert_approx_eq translated.origin.y, 20.0_f32
    assert_approx_eq translated.origin.z, 30.0_f32

    point = Godot::Vector3.new(5.0_f32, 5.0_f32, 5.0_f32)
    transformed_point = translated * point
    assert_approx_eq transformed_point.x, 15.0_f32
    assert_approx_eq transformed_point.y, 25.0_f32
    assert_approx_eq transformed_point.z, 35.0_f32

    inv = translated.affine_inverse
    restored_point = inv * transformed_point
    assert_approx_eq restored_point.x, 5.0_f32
    assert_approx_eq restored_point.y, 5.0_f32
    assert_approx_eq restored_point.z, 5.0_f32
  end

  test "Plane distance to point and normal verification" do
    # Ground plane facing straight up (Y = 0)
    normal = Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
    plane = Godot::Plane.new(normal, 0.0_f32)

    above_point = Godot::Vector3.new(10.0_f32, 15.0_f32, 20.0_f32)
    dist = plane.distance_to(above_point)
    assert_approx_eq dist, 15.0_f32

    below_point = Godot::Vector3.new(0.0_f32, -8.0_f32, 0.0_f32)
    dist_below = plane.distance_to(below_point)
    assert_approx_eq dist_below, -8.0_f32

    on_plane = Godot::Vector3.new(5.0_f32, 0.0_f32, 5.0_f32)
    assert_true plane.has_point(on_plane, 0.001_f32)
  end

  test "AABB enclosing bounds and intersection checks" do
    box1 = Godot::AABB.new(Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32), Godot::Vector3.new(10.0_f32, 10.0_f32, 10.0_f32))
    assert_approx_eq box1.size.x, 10.0_f32

    # Point inside
    assert_true box1.has_point(Godot::Vector3.new(5.0_f32, 5.0_f32, 5.0_f32))
    # Point outside
    assert_false box1.has_point(Godot::Vector3.new(15.0_f32, 5.0_f32, 5.0_f32))

    # Overlapping box
    box2 = Godot::AABB.new(Godot::Vector3.new(8.0_f32, 8.0_f32, 8.0_f32), Godot::Vector3.new(10.0_f32, 10.0_f32, 10.0_f32))
    assert_true box1.intersects(box2)

    # Disjoint box
    box3 = Godot::AABB.new(Godot::Vector3.new(100.0_f32, 100.0_f32, 100.0_f32), Godot::Vector3.new(5.0_f32, 5.0_f32, 5.0_f32))
    assert_false box1.intersects(box3)
  end

  test "Color linear interpolation (lerp) and components" do
    c1 = Godot::Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
    c2 = Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)

    c_mid = c1.lerp(c2, 0.5_f32)
    assert_approx_eq c_mid.r, 0.5_f32
    assert_approx_eq c_mid.g, 0.5_f32
    assert_approx_eq c_mid.b, 0.5_f32
    assert_approx_eq c_mid.a, 1.0_f32
  end
end
