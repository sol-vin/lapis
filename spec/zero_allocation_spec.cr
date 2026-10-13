# =============================================================================
# LibGodot - Automated Zero-Allocation Assertion & Hot Loop Spec Suite
# =============================================================================
# Validates that critical game engine math, spatial transformations, color spaces,
# and high-throughput frame loops execute with strictly ZERO heap allocations.
#
# Assigned Specialist: Mu (Performance & Allocation Profiler)
# Quality Gate: Upsilon (DevOps & CI/CD)
# Work Order: WO-020
# =============================================================================

require "./spec_helper"

describe "Lapis::Profiler - Automated Zero-Allocation Framework" do
  describe "Core Engine Tier (AllocationSnapshot & AllocationProbe)" do
    it "captures point-in-time GC statistics without heap allocation" do
      s1 = Lapis::Profiler::AllocationSnapshot.capture
      s2 = Lapis::Profiler::AllocationSnapshot.capture
      delta = s2.delta_from(s1)
      delta.bytes_allocated.should eq(0_i64)
      delta.zero_allocation?.should be_true
    end

    it "accurately detects zero-allocation loops" do
      a = 10_i64
      b = 20_i64
      sum = 0_i64

      report = Lapis::Profiler::AllocationProbe.run("Primitive Arithmetic", iterations: 50_000, warmup: 50) do |i|
        sum += (a + b) ^ i
      end

      report.zero_allocation?.should be_true
      report.bytes_allocated.should eq(0_i64)
      report.bytes_per_iteration.should eq(0.0)
      report.passed?.should be_true
      sum.should_not eq(0_i64)
    end

    it "accurately flags heap allocations and calculates byte rate" do
      sink = [] of Array(Int32)
      report = Lapis::Profiler::AllocationProbe.run("Heap Allocation Test", iterations: 100, warmup: 5) do |i|
        sink << [i, i * 2, i * 3]
      end

      report.zero_allocation?.should be_false
      report.bytes_allocated.should be > 0_i64
      report.bytes_per_iteration.should be > 0.0
      report.passed?.should be_false
      sink.size.should be > 0
    end

    it "generates rich diagnostic failure messages with troubleshooting checklist" do
      report = Lapis::Profiler::AllocationReport.new(
        name: "Mock Failure",
        iterations: 1000,
        warmup_cycles: 10,
        bytes_allocated: 4096_i64,
        duration: 1.milliseconds,
        threshold_bytes: 0_i64
      )

      msg = report.failure_message(0_i64)
      msg.should contain("Allocation Assertion Failed for 'Mock Failure'!")
      msg.should contain("4096 bytes allocated across 1000 iterations")
      msg.should contain("Closure variable capture")
      msg.should contain("String interpolation")
    end
  end

  describe "Declarative Builder & DSL Tier (Lapis::Profiler.audit)" do
    it "configures and runs an audit via fluent block receiver" do
      v1 = Godot::Vector2.new(1.0_f32, 2.0_f32)
      v2 = Godot::Vector2.new(3.0_f32, 4.0_f32)
      dot_sum = 0.0_f32

      report = Lapis::Profiler.audit("Vector2 Dot Product") do |audit|
        audit.iterations(25_000)
        audit.warmup(50)
        audit.assert_zero_allocation do |i|
          dot_sum += v1.dot(v2)
        end
      end

      report.should_not be_nil
      report.not_nil!.zero_allocation?.should be_true
      dot_sum.should be > 0.0_f32
    end

    it "supports concise hot_loop one-liners" do
      x = 5.0_f32
      y = 10.0_f32

      report = Lapis::Profiler.hot_loop("Math clamp", iterations: 10_000) do
        x = x.clamp(0.0_f32, y)
      end

      report.zero_allocation?.should be_true
    end
  end

  describe "Spec Expectation Matchers (allocate_zero_bytes & allocate_at_most)" do
    it "matches zero-allocation procs via should allocate_zero_bytes" do
      v = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
      up = Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)

      ->{
        v = v.cross(up).normalized
        nil
      }.should allocate_zero_bytes(iterations: 10_000, warmup: 50)
    end

    it "matches bounded allocation procs via should allocate_at_most" do
      sink = [] of Array(Int32)
      ->{
        sink << [1, 2, 3]
        nil
      }.should allocate_at_most(10_000_i64, iterations: 10, warmup: 2)
    end

    it "matches rate-bounded allocation procs via should allocate_bytes_per_iteration" do
      sink = [] of Array(Int32)
      ->{
        sink << [1, 2]
        nil
      }.should allocate_bytes_per_iteration(500.0, iterations: 10, warmup: 2)
    end

    it "raises AssertionError when assert_zero_allocation detects allocations" do
      sink = [] of Array(Int32)
      expect_raises(Lapis::Test::AssertionError) do
        assert_zero_allocation("Intentionally Allocating", iterations: 10, warmup: 2) do |i|
          sink << [i, 2, 3, 4]
        end
      end
    end
  end

  describe "2D Spatial Math Hot Loops (Zero-Allocation)" do
    it "executes Vector2 arithmetic without allocations" do
      v1 = Godot::Vector2.new(10.5_f32, 20.25_f32)
      v2 = Godot::Vector2.new(5.0_f32, -2.0_f32)
      result = Godot::Vector2.new(0.0_f32, 0.0_f32)

      assert_zero_allocation("Vector2 Arithmetic", iterations: 50_000) do
        result = (v1 + v2 - v1) * 2.0_f32 / 1.5_f32
      end
    end

    it "executes Vector2 geometric algorithms without allocations" do
      v1 = Godot::Vector2.new(3.0_f32, 4.0_f32)
      v2 = Godot::Vector2.new(-1.0_f32, 2.0_f32)
      dist = 0.0_f32
      norm = Godot::Vector2.new(0.0_f32, 0.0_f32)

      assert_zero_allocation("Vector2 Geometry", iterations: 50_000) do
        norm = v1.normalized
        dist = v1.distance_to(v2)
        ortho = v1.orthogonal
      end

      dist.should be > 0.0_f32
    end

    it "executes Transform2D affine point transformations without allocations" do
      xform = Godot::Transform2D.new(1.5_f32, Godot::Vector2.new(100.0_f32, 200.0_f32))
      point = Godot::Vector2.new(50.0_f32, 75.0_f32)
      transformed = Godot::Vector2.new(0.0_f32, 0.0_f32)

      assert_zero_allocation("Transform2D Multiply", iterations: 50_000) do
        transformed = xform * point
      end
    end

    it "executes Rect2 intersection and containment checks without allocations" do
      r1 = Godot::Rect2.new(Godot::Vector2.new(0.0_f32, 0.0_f32), Godot::Vector2.new(100.0_f32, 100.0_f32))
      r2 = Godot::Rect2.new(Godot::Vector2.new(50.0_f32, 50.0_f32), Godot::Vector2.new(100.0_f32, 100.0_f32))
      pt = Godot::Vector2.new(75.0_f32, 75.0_f32)
      intersects = false

      assert_zero_allocation("Rect2 Intersection", iterations: 50_000) do
        intersects = r1.intersects(r2) && r1.has_point(pt)
      end

      intersects.should be_true
    end
  end

  describe "3D Spatial Math & Transform Hot Loops (Zero-Allocation)" do
    it "executes Vector3 vector algebra without allocations" do
      v1 = Godot::Vector3.new(1.0_f32, 0.0_f32, 0.0_f32)
      v2 = Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
      cross = Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)
      dot = 0.0_f32

      assert_zero_allocation("Vector3 Algebra", iterations: 50_000) do
        cross = v1.cross(v2)
        dot = v1.dot(v2)
        len = cross.length
      end

      cross.z.should eq(1.0_f32)
    end

    it "executes Vector3 linear interpolation (lerp) without allocations" do
      v1 = Godot::Vector3.new(0.0_f32, 10.0_f32, 20.0_f32)
      v2 = Godot::Vector3.new(100.0_f32, 50.0_f32, -20.0_f32)
      out_vec = Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)

      assert_zero_allocation("Vector3 Lerp", iterations: 50_000) do |i|
        weight = (i % 100).to_f32 / 100.0_f32
        out_vec = v1.lerp(v2, weight)
      end
    end

    it "executes Basis matrix operations and determinant without allocations" do
      b1 = Godot::Basis.new
      b2 = Godot::Basis.from_axis_angle(Godot::Vector3::UP, Math::PI / 4.0)
      v = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
      res_v = Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)

      assert_zero_allocation("Basis Math", iterations: 50_000) do
        transposed = b2.transposed
        det = b2.determinant
        res_v = transposed * v
      end

      res_v.length.should be_close(v.length, 0.001_f32)
    end

    it "executes Quaternion arithmetic and norm without allocations" do
      q1 = Godot::Quaternion.new
      q2 = Godot::Quaternion.new(0.0_f32, 0.7071_f32, 0.0_f32, 0.7071_f32)
      q_out = Godot::Quaternion.new

      assert_zero_allocation("Quaternion Math", iterations: 50_000) do
        q_out = (q1 * q2).normalized
      end

      q_out.w.should be_close(0.7071_f32, 0.001_f32)
    end

    it "executes Transform3D affine transformations without allocations" do
      xform = Godot::Transform3D.new.translated(Godot::Vector3.new(10.0_f32, 20.0_f32, 30.0_f32))
      pt = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
      out_pt = Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)

      assert_zero_allocation("Transform3D Transform Point", iterations: 50_000) do
        out_pt = xform * pt
        inv = xform.affine_inverse
        orig = inv * out_pt
      end

      out_pt.should eq(Godot::Vector3.new(11.0_f32, 22.0_f32, 33.0_f32))
    end

    it "executes AABB intersection checks without allocations" do
      b1 = Godot::AABB.new(Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32), Godot::Vector3.new(10.0_f32, 10.0_f32, 10.0_f32))
      b2 = Godot::AABB.new(Godot::Vector3.new(5.0_f32, 5.0_f32, 5.0_f32), Godot::Vector3.new(10.0_f32, 10.0_f32, 10.0_f32))
      hit = false

      assert_zero_allocation("AABB Intersection", iterations: 50_000) do
        hit = b1.intersects(b2)
      end

      hit.should be_true
    end
  end

  describe "Color & Color Space Hot Loops (Zero-Allocation)" do
    it "executes Color blending and component arithmetic without allocations" do
      c1 = Godot::Color.new(0.8_f32, 0.2_f32, 0.3_f32, 1.0_f32)
      c2 = Godot::Color.new(0.1_f32, 0.9_f32, 0.4_f32, 1.0_f32)
      blended = Godot::Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)

      assert_zero_allocation("Color Blend", iterations: 50_000) do |i|
        weight = (i % 100).to_f32 / 100.0_f32
        blended = c1.lerp(c2, weight)
        inv = blended.inverted
      end
    end

    it "converts between RGB and HSV without heap allocations" do
      c = Godot::Color.new(0.2_f32, 0.7_f32, 0.9_f32, 1.0_f32)
      h = 0.0_f32
      s = 0.0_f32
      v = 0.0_f32

      assert_zero_allocation("Color RGB->HSV", iterations: 50_000) do
        h = c.h
        s = c.s
        v = c.v
        reconstructed = Godot::Color.from_hsv(h, s, v)
      end

      h.should be > 0.0_f32
    end
  end

  describe "Gameplay Primitives & Number Math (Zero-Allocation)" do
    it "executes Number#approach in hot loops without allocations" do
      current = 0.0_f64
      target = 100.0_f64

      assert_zero_allocation("Number#approach", iterations: 50_000) do
        current = current.approach(target, 0.5_f64)
      end

      current.should eq(100.0_f64)
    end

    it "executes degrees/radians conversions without allocations" do
      rad = 0.0_f64
      deg = 180.0_f64

      assert_zero_allocation("Angle Conversion", iterations: 50_000) do
        rad = deg.degrees
        deg = rad.to_degrees
      end

      deg.should be_close(180.0_f64, 0.001_f64)
    end
  end
end
