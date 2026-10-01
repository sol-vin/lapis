require "./spec_helper"

describe "Godot Math & Spatial Primitives" do
  describe "Vector2" do
    it "performs addition and subtraction" do
      v1 = Vector2.new(2.0, 3.0)
      v2 = Vector2.new(4.0, 1.0)
      (v1 + v2).should eq(Vector2.new(6.0_f32, 4.0_f32))
      (v1 - v2).should eq(Vector2.new(-2.0_f32, 2.0_f32))
    end

    it "supports unary negation" do
      v = Vector2.new(3.0, -5.0)
      (-v).should eq(Vector2.new(-3.0_f32, 5.0_f32))
    end

    it "performs scalar and component-wise multiplication and division" do
      v = Vector2.new(3.0, 6.0)
      (v * 2).should eq(Vector2.new(6.0_f32, 12.0_f32))
      (v / 3).should eq(Vector2.new(1.0_f32, 2.0_f32))

      v2 = Vector2.new(2.0, 3.0)
      (v * v2).should eq(Vector2.new(6.0_f32, 18.0_f32))
      (v / v2).should eq(Vector2.new(1.5_f32, 2.0_f32))
    end

    it "calculates length and length_squared" do
      v = Vector2.new(3.0, 4.0)
      v.length_squared.should eq(25.0_f32)
      v.length.should eq(5.0_f32)
    end

    it "calculates dot and cross products" do
      v1 = Vector2.new(1.0, 2.0)
      v2 = Vector2.new(3.0, 4.0)
      v1.dot(v2).should eq(11.0_f32)
      v1.cross(v2).should eq(-2.0_f32)
    end

    it "normalizes non-zero vectors" do
      v = Vector2.new(0.0, 5.0).normalized
      v.x.should eq(0.0_f32)
      v.y.should eq(1.0_f32)
      v.is_normalized?.should be_true
    end

    it "rotates vector by radians (Vector2#rotated)" do
      v = Vector2.new(1.0, 0.0)
      rot = v.rotated(Math::PI / 2.0)
      rot.x.abs.should be < 0.0001_f32
      rot.y.should be_close(1.0_f32, 0.0001_f32)
    end

    it "calculates orthogonal and perpendicular vectors" do
      v = Vector2.new(2.0, 5.0)
      v.orthogonal.should eq(Vector2.new(-5.0_f32, 2.0_f32))
      v.perpendicular.should eq(v.orthogonal)
    end

    it "slides, reflects, and bounces vectors" do
      v = Vector2.new(3.0, -4.0)
      normal = Vector2::UP # (0, -1)
      v.slide(normal).should eq(Vector2.new(3.0_f32, 0.0_f32))

      refl = v.reflect(normal)
      refl.should eq(Vector2.new(3.0_f32, 4.0_f32))
      v.bounce(normal).should eq(-refl)
    end

    it "projects onto another vector" do
      v = Vector2.new(2.0, 3.0)
      b = Vector2.new(4.0, 0.0)
      v.project(b).should eq(Vector2.new(2.0_f32, 0.0_f32))
    end

    it "calculates angles and distances" do
      v1 = Vector2.new(1.0, 0.0)
      v2 = Vector2.new(0.0, 1.0)
      v1.angle.should eq(0.0_f32)
      v1.angle_to(v2).should be_close(Math::PI.to_f32 / 2.0_f32, 0.0001_f32)
      v1.distance_to(v2).should be_close(Math.sqrt(2.0).to_f32, 0.0001_f32)
      v1.direction_to(v2).should eq(Vector2.new(-1.0_f32, 1.0_f32).normalized)
    end

    it "supports interpolation, movement, and clamping" do
      v1 = Vector2.new(0.0, 0.0)
      v2 = Vector2.new(10.0, 10.0)
      v1.lerp(v2, 0.5).should eq(Vector2.new(5.0_f32, 5.0_f32))
      v1.move_toward(v2, 2.0).length.should be_close(2.0_f32, 0.0001_f32)

      v_long = Vector2.new(10.0, 0.0)
      v_long.limit_length(4.0).should eq(Vector2.new(4.0_f32, 0.0_f32))

      v_clamp = Vector2.new(-5.0, 15.0)
      v_clamp.clamp(Vector2.new(0.0, 0.0), Vector2.new(10.0, 10.0)).should eq(Vector2.new(0.0_f32, 10.0_f32))
    end

    it "supports conversions and approximations" do
      v = Vector2.new(3.7, -2.3)
      v.floor.should eq(Vector2.new(3.0_f32, -3.0_f32))
      v.ceil.should eq(Vector2.new(4.0_f32, -2.0_f32))
      v.round.should eq(Vector2.new(4.0_f32, -2.0_f32))
      v.abs.should eq(Vector2.new(3.7_f32, 2.3_f32))
      v.sign.should eq(Vector2.new(1.0_f32, -1.0_f32))
      v.to_i.should eq(Vector2i.new(3, -2))

      Vector2.new(0.000001, 0.000001).is_zero_approx.should be_true
      Vector2.new(1.0, 2.0).is_equal_approx(Vector2.new(1.000001, 1.999999)).should be_true
    end

    it "provides standard direction constants" do
      Vector2::ZERO.should eq(Vector2.new(0.0_f32, 0.0_f32))
      Vector2::UP.should eq(Vector2.new(0.0_f32, -1.0_f32))
      Vector2::DOWN.should eq(Vector2.new(0.0_f32, 1.0_f32))
      Vector2::RIGHT.should eq(Vector2.new(1.0_f32, 0.0_f32))
      Vector2::LEFT.should eq(Vector2.new(-1.0_f32, 0.0_f32))
    end
  end

  describe "Vector2i" do
    it "performs integer coordinates addition, scaling, and unary negation" do
      v1 = Vector2i.new(10, 20)
      v2 = Vector2i.new(5, -5)
      (v1 + v2).should eq(Vector2i.new(15, 15))
      (v1 - v2).should eq(Vector2i.new(5, 25))
      (-v1).should eq(Vector2i.new(-10, -20))
      (v1 * 2).should eq(Vector2i.new(20, 40))
      (v1 * v2).should eq(Vector2i.new(50, -100))
      (v1 / 2).should eq(Vector2i.new(5, 10))
    end

    it "supports abs, sign, min, max, clamp, and to_v2" do
      v = Vector2i.new(-10, 25)
      v.abs.should eq(Vector2i.new(10, 25))
      v.sign.should eq(Vector2i.new(-1, 1))
      v.clamp(Vector2i.new(0, 0), Vector2i.new(20, 20)).should eq(Vector2i.new(0, 20))
      v.to_v2.should eq(Vector2.new(-10.0_f32, 25.0_f32))
    end
  end

  describe "Vector3" do
    it "performs vector addition, subtraction, scaling, and unary negation" do
      v1 = Vector3.new(1.0, 2.0, 3.0)
      v2 = Vector3.new(4.0, 5.0, 6.0)
      (v1 + v2).should eq(Vector3.new(5.0_f32, 7.0_f32, 9.0_f32))
      (v1 - v2).should eq(Vector3.new(-3.0_f32, -3.0_f32, -3.0_f32))
      (-v1).should eq(Vector3.new(-1.0_f32, -2.0_f32, -3.0_f32))
      (v1 * 2).should eq(Vector3.new(2.0_f32, 4.0_f32, 6.0_f32))
      (v1 * v2).should eq(Vector3.new(4.0_f32, 10.0_f32, 18.0_f32))
      (v2 / v1).should eq(Vector3.new(4.0_f32, 2.5_f32, 2.0_f32))
    end

    it "calculates dot and cross products" do
      v1 = Vector3.new(1.0, 2.0, 3.0)
      v2 = Vector3.new(4.0, 5.0, 6.0)
      v1.dot(v2).should eq(32.0_f32)
      cross = Vector3::UP.cross(Vector3::RIGHT)
      cross.z.should eq(-1.0_f32)
    end

    it "slides vector along plane normal (Vector3#slide)" do
      v = Vector3.new(5.0, -10.0, 3.0)
      normal = Vector3::UP # (0, 1, 0)
      slid = v.slide(normal)
      slid.x.should eq(5.0_f32)
      slid.y.should eq(0.0_f32)
      slid.z.should eq(3.0_f32)

      # Slide along a vertical wall
      wall_v = Vector3.new(8.0, 0.0, 4.0)
      wall_normal = Vector3.new(-1.0, 0.0, 0.0)
      wall_slid = wall_v.slide(wall_normal)
      wall_slid.x.should eq(0.0_f32)
      wall_slid.y.should eq(0.0_f32)
      wall_slid.z.should eq(4.0_f32)
    end

    it "rotates vector around axis (Vector3#rotated)" do
      v = Vector3::FORWARD # (0, 0, -1)
      rot = v.rotated(Vector3::UP, Math::PI / 2.0)
      rot.x.should be_close(-1.0_f32, 0.0001_f32)
      rot.y.abs.should be < 0.0001_f32
      rot.z.abs.should be < 0.0001_f32
    end

    it "reflects and bounces vectors" do
      v = Vector3.new(2.0, -5.0, 1.0)
      normal = Vector3::UP
      refl = v.reflect(normal)
      refl.should eq(Vector3.new(2.0_f32, 5.0_f32, 1.0_f32))
      v.bounce(normal).should eq(-refl)
    end

    it "projects onto another vector" do
      v = Vector3.new(1.0, 2.0, 3.0)
      b = Vector3.new(0.0, 1.0, 0.0)
      v.project(b).should eq(Vector3.new(0.0_f32, 2.0_f32, 0.0_f32))
    end

    it "calculates angles and signed angles" do
      v1 = Vector3.new(1.0, 0.0, 0.0)
      v2 = Vector3.new(0.0, 1.0, 0.0)
      v1.angle_to(v2).should be_close(Math::PI.to_f32 / 2.0_f32, 0.0001_f32)
      v1.signed_angle_to(v2, Vector3.new(0.0, 0.0, 1.0)).should be_close(Math::PI.to_f32 / 2.0_f32, 0.0001_f32)
    end

    it "supports interpolation and move_toward" do
      v1 = Vector3.new(0.0, 0.0, 0.0)
      v2 = Vector3.new(0.0, 10.0, 0.0)
      v1.lerp(v2, 0.3).should eq(Vector3.new(0.0_f32, 3.0_f32, 0.0_f32))
      v1.move_toward(v2, 4.0).should eq(Vector3.new(0.0_f32, 4.0_f32, 0.0_f32))
    end

    it "supports swizzle accessors and conversions" do
      v = Vector3.new(1.0, 2.0, 3.0)
      v.xz.should eq(Vector2.new(1.0_f32, 3.0_f32))
      v.xy.should eq(Vector2.new(1.0_f32, 2.0_f32))
      v.yz.should eq(Vector2.new(2.0_f32, 3.0_f32))
      v.to_i.should eq(Vector3i.new(1, 2, 3))
    end

    it "provides standard 3D constants" do
      Vector3::ZERO.should eq(Vector3.new(0.0_f32, 0.0_f32, 0.0_f32))
      Vector3::UP.should eq(Vector3.new(0.0_f32, 1.0_f32, 0.0_f32))
      Vector3::DOWN.should eq(Vector3.new(0.0_f32, -1.0_f32, 0.0_f32))
      Vector3::RIGHT.should eq(Vector3.new(1.0_f32, 0.0_f32, 0.0_f32))
      Vector3::LEFT.should eq(Vector3.new(-1.0_f32, 0.0_f32, 0.0_f32))
      Vector3::FORWARD.should eq(Vector3.new(0.0_f32, 0.0_f32, -1.0_f32))
      Vector3::BACK.should eq(Vector3.new(0.0_f32, 0.0_f32, 1.0_f32))
    end
  end

  describe "Vector3i" do
    it "handles discrete 3D voxel arithmetic" do
      v1 = Vector3i.new(1, 2, 3)
      v2 = Vector3i.new(10, 20, 30)
      (v1 + v2).should eq(Vector3i.new(11, 22, 33))
      (v2 - v1).should eq(Vector3i.new(9, 18, 27))
      (-v1).should eq(Vector3i.new(-1, -2, -3))
      (v1 * 3).should eq(Vector3i.new(3, 6, 9))
      v1.to_v3.should eq(Vector3.new(1.0_f32, 2.0_f32, 3.0_f32))
    end
  end

  describe "Color" do
    it "initializes RGBA channels with default 1.0" do
      c = Color.new
      c.r.should eq(1.0_f32)
      c.g.should eq(1.0_f32)
      c.b.should eq(1.0_f32)
      c.a.should eq(1.0_f32)
    end

    it "initializes custom color values" do
      c = Color.new(0.5, 0.25, 0.75, 0.9)
      c.r.should eq(0.5_f32)
      c.g.should eq(0.25_f32)
      c.b.should eq(0.75_f32)
      c.a.should eq(0.9_f32)
    end

    it "provides basic palette constants" do
      Color::WHITE.r.should eq(1.0_f32)
      Color::BLACK.r.should eq(0.0_f32)
      Color::RED.r.should eq(1.0_f32)
      Color::RED.g.should eq(0.0_f32)
      Color::GREEN.g.should eq(1.0_f32)
      Color::BLUE.b.should eq(1.0_f32)
    end
  end

  describe "Rect2 & Rect2i" do
    it "initializes position and size for Rect2 and Rect2i" do
      r = Rect2.new(10.0, 20.0, 100.0, 200.0)
      r.position.x.should eq(10.0_f32)
      r.position.y.should eq(20.0_f32)
      r.size.x.should eq(100.0_f32)
      r.size.y.should eq(200.0_f32)

      ri = Rect2i.new(5, 10, 50, 100)
      ri.position.x.should eq(5)
      ri.size.y.should eq(100)
    end
  end

  describe "Transform2D" do
    it "initializes identity Transform2D and transforms points" do
      t = Transform2D.new
      pt = Vector2.new(3.0, 4.0)
      (t * pt).should eq(pt)
    end

    it "performs translation, rotation and inverse" do
      t = Transform2D.new(Math::PI.to_f32 / 2.0_f32, Vector2.new(10.0_f32, 20.0_f32))
      pt = Vector2.new(1.0, 0.0)
      transformed = t * pt
      transformed.x.should be_close(10.0_f32, 0.0001_f32)
      transformed.y.should be_close(21.0_f32, 0.0001_f32)

      inv = t.affine_inverse
      orig = inv * transformed
      orig.x.should be_close(pt.x, 0.0001_f32)
      orig.y.should be_close(pt.y, 0.0001_f32)
    end
  end

  describe "Basis & Transform3D" do
    it "creates identity Basis matrix" do
      b = Basis.new
      b.x.should eq(Vector3.new(1.0_f32, 0.0_f32, 0.0_f32))
      b.y.should eq(Vector3.new(0.0_f32, 1.0_f32, 0.0_f32))
      b.z.should eq(Vector3.new(0.0_f32, 0.0_f32, 1.0_f32))
      b.determinant.should eq(1.0_f32)
    end

    it "multiplies Basis by Vector3" do
      b = Basis.new
      v = Vector3.new(3.0_f32, 4.0_f32, 5.0_f32)
      (b * v).should eq(v)
    end

    it "supports axis-angle rotation and transpose" do
      b = Basis.from_axis_angle(Vector3::UP, Math::PI / 2.0)
      v = Vector3::FORWARD
      (b * v).x.should be_close(-1.0_f32, 0.0001_f32)

      transposed = b.transposed
      (transposed * (b * v)).z.should be_close(v.z, 0.0001_f32)
    end

    it "initializes Transform3D with basis and origin and transforms points" do
      t = Transform3D.new(Basis.new, Vector3.new(10.0_f32, 20.0_f32, 30.0_f32))
      pt = Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
      (t * pt).should eq(Vector3.new(11.0_f32, 22.0_f32, 33.0_f32))

      inv = t.affine_inverse
      (inv * (t * pt)).should eq(pt)
    end

    it "supports translated and scaled transforms" do
      t = Transform3D.new.translated(Vector3.new(5.0_f32, 0.0_f32, 0.0_f32))
      t.origin.should eq(Vector3.new(5.0_f32, 0.0_f32, 0.0_f32))

      scaled = t.scaled(Vector3.new(2.0_f32, 2.0_f32, 2.0_f32))
      (scaled * Vector3.new(1.0_f32, 0.0_f32, 0.0_f32)).should eq(Vector3.new(7.0_f32, 0.0_f32, 0.0_f32))
    end
  end

  describe "Spatial Structs (Quaternion, Plane, AABB, Vector4)" do
    it "initializes Quaternion with identity default" do
      q = Quaternion.new
      q.w.should eq(1.0_f32)
      q.x.should eq(0.0_f32)
    end

    it "initializes Plane and AABB" do
      p = Plane.new(Vector3::UP, 5.0_f32)
      p.normal.should eq(Vector3::UP)
      p.d.should eq(5.0_f32)

      box = AABB.new(Vector3.new(0.0_f32, 0.0_f32, 0.0_f32), Vector3.new(10.0_f32, 10.0_f32, 10.0_f32))
      box.size.should eq(Vector3.new(10.0_f32, 10.0_f32, 10.0_f32))
    end

    it "initializes Vector4 and Vector4i" do
      v4 = Vector4.new(1.0, 2.0, 3.0, 4.0)
      v4.w.should eq(4.0_f32)

      v4i = Vector4i.new(10, 20, 30, 40)
      v4i.w.should eq(40)
    end
  end

  describe "Math.move_toward & Math.lerp" do
    it "interpolates toward target without overshooting" do
      res1 = Math.move_toward(0.0_f32, 10.0_f32, 3.0_f32)
      res1.should eq(3.0_f32)

      res2 = Math.move_toward(9.0_f32, 10.0_f32, 3.0_f32)
      res2.should eq(10.0_f32)

      res3 = Math.move_toward(10.0_f32, 0.0_f32, 4.0_f32)
      res3.should eq(6.0_f32)
    end

    it "calculates scalar linear interpolation" do
      Math.lerp(0.0_f32, 100.0_f32, 0.25_f32).should eq(25.0_f32)
      Math.lerp(10.0_f64, 20.0_f64, 0.5_f64).should eq(15.0_f64)
    end
  end
end
