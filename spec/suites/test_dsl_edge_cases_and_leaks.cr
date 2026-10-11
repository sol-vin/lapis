# =============================================================================
# LibGodot Test Suite: DSL Edge Cases & Quantitative Zero-Leak Verification
# =============================================================================

include Lapis::Test

# Probe node for receiver scoping and state mutation
node DslEdgeProbeNode < Godot::Node2D do
  property counter : Int32 = 0
  property active : Bool = false
  property tag : String = "probe"

  def activate! : Void
    @active = true
    @counter += 1
  end

  def increment(by : Int32) : Void
    @counter += by
  end
end

# Target node for type filtering and collider checks
node DslEdgeTargetNode < Godot::Node2D do
  property hit_points : Int32 = 100
  property target_name : String = "Target"

  def damage!(amount : Int32) : Void
    @hit_points = Math.max(0, @hit_points - amount)
  end
end

# Node with onready properties unwrapping ~ and .as(...)
node DslEdgeOnreadyHost < Godot::Node2D do
  onready child_probe : DslEdgeProbeNode = ~"ProbeChild".as(DslEdgeProbeNode)
  onready child_target : DslEdgeTargetNode = ~"TargetChild".as(DslEdgeTargetNode)
end

test_suite "DslEdgeCasesAndLeaks" do
  test "Pillar 1: each_node receiver scoping invokes methods and mutates receiver state" do
    root = Godot.create(Godot::Node2D)
    container = Godot.create(Godot::Node2D)
    container.name = "Probes"
    root.add_child(container)

    p1 = Godot.create(DslEdgeProbeNode)
    p1.name = "Probe1"
    container.add_child(p1)

    p2 = Godot.create(DslEdgeProbeNode)
    p2.name = "Probe2"
    container.add_child(p2)

    # Scoped execution: activate! is invoked directly on each probe receiver
    root.each_node("Probes/*", DslEdgeProbeNode) do
      activate!
      increment(5)
    end

    assert_true p1.active
    assert_eq p1.counter, 6
    assert_true p2.active
    assert_eq p2.counter, 6

    # Block parameter alternative works identically
    root.each_node("Probes/*", DslEdgeProbeNode) do |p|
      p.increment(10)
    end
    assert_eq p1.counter, 16
    assert_eq p2.counter, 16

    # Shorthand block pass syntax (&.method)
    root.each_node("Probes/*", &.queue_free)

    root.destroy
  end

  test "Pillar 1: each_node mid-iteration node destruction safety" do
    root = Godot.create(Godot::Node2D)
    probes = (1..5).map do |i|
      p = Godot.create(DslEdgeProbeNode)
      p.name = "Probe_#{i}"
      root.add_child(p)
      p
    end

    visited_count = 0
    # During iteration, destroy Probe_2
    root.each_node("*", DslEdgeProbeNode) do |node|
      visited_count += 1
      if node.name == "Probe_2"
        node.destroy
      end
    end

    assert_eq visited_count, 5
    assert_true probes[0].alive?
    assert_false probes[1].alive? # Probe_2 was destroyed
    assert_true probes[2].alive?
    assert_true probes[3].alive?
    assert_true probes[4].alive?

    root.destroy
  end

  test "Pillar 1: each_node hierarchical globbing and empty set safety" do
    root = Godot.create(Godot::Node2D)
    tier1 = Godot.create(Godot::Node2D)
    tier1.name = "Tier1"
    root.add_child(tier1)

    tier2 = Godot.create(Godot::Node2D)
    tier2.name = "Tier2"
    tier1.add_child(tier2)

    leaf = Godot.create(DslEdgeProbeNode)
    leaf.name = "LeafProbe"
    tier2.add_child(leaf)

    # Deep globbing
    found_count = 0
    root.each_node("Tier1/**/LeafProbe", DslEdgeProbeNode) do
      found_count += 1
      activate!
    end
    assert_eq found_count, 1
    assert_true leaf.active

    # Non-existent glob returns immediately with 0 iterations
    empty_count = 0
    root.each_node("NonExistentPattern/*") do
      empty_count += 1
    end
    assert_eq empty_count, 0

    root.destroy
  end

  test "Pillar 1: each_node type filtering strictly isolates matching node types" do
    root = Godot.create(Godot::Node2D)

    t1 = Godot.create(DslEdgeTargetNode)
    t1.name = "Target1"
    root.add_child(t1)

    p1 = Godot.create(DslEdgeProbeNode)
    p1.name = "Probe1"
    root.add_child(p1)

    t2 = Godot.create(DslEdgeTargetNode)
    t2.name = "Target2"
    root.add_child(t2)

    p2 = Godot.create(DslEdgeProbeNode)
    p2.name = "Probe2"
    root.add_child(p2)

    # Filtering for DslEdgeTargetNode visits only t1 and t2
    target_names = [] of String
    root.each_node("*", DslEdgeTargetNode) do |target|
      target_names << target.name
    end
    assert_eq target_names, ["Target1", "Target2"]

    # Filtering for DslEdgeProbeNode visits only p1 and p2
    probe_names = [] of String
    root.each_node("*", DslEdgeProbeNode) do |probe|
      probe_names << probe.name
    end
    assert_eq probe_names, ["Probe1", "Probe2"]

    root.destroy
  end

  test "Pillar 2: PhysicsHit collider alive-checking, casting, and dead-pointer safety" do
    target = Godot.create(DslEdgeTargetNode)
    target.name = "LiveCollider"

    hit = Godot::PhysicsHit2D.new(
      point: Godot::Vector2.new(50.0_f32, 100.0_f32),
      normal: Godot::Vector2.new(0.0_f32, -1.0_f32),
      collider: target
    )

    # 1. Living collider returns non-nil and casts cleanly
    assert_not_nil hit.collider
    assert_true hit.collider.try(&.alive?) == true
    casted = hit.collider.as?(DslEdgeTargetNode)
    assert_not_nil casted
    if t = casted
      t.damage!(40)
      assert_eq t.hit_points, 60
    end

    # 2. Type mismatch returns nil safely
    mismatched = hit.collider.as?(DslEdgeProbeNode)
    assert_nil mismatched

    # 3. Destroying collider: subsequent queries return nil with ZERO crashes
    target.destroy
    assert_false target.alive?
    assert_nil hit.collider
    assert_nil hit.collider.as?(DslEdgeTargetNode)

    # 4. Repeated invocations on dead pointer remain 100% stable
    10.times do
      assert_nil hit.collider
      assert_nil hit.collider.as?(DslEdgeTargetNode)
    end
  end

  test "Pillar 3: match macro implicit variable narrowing across primitive and math types" do
    # Int64 narrowing
    val_int = Godot::Variant.new(50_i64)
    res_int = match val_int do
      is Int64          do "Int: #{val_int * 2}" end
      is String         do "Str: #{val_int}" end
      default           do "other" end
    end
    assert_eq res_int, "Int: 100"

    # Float64 narrowing
    val_float = Godot::Variant.new(3.5_f64)
    res_float = match val_float do
      is Float64 do "Float: #{val_float * 2.0}" end
      default    do "other" end
    end
    assert_eq res_float, "Float: 7.0"

    # String narrowing
    val_str = Godot::Variant.new("crystal_godot")
    res_str = match val_str do
      is String do "Upper: #{val_str.upcase}" end
      default   do "other" end
    end
    assert_eq res_str, "Upper: CRYSTAL_GODOT"

    # Vector2 mathematical type narrowing
    val_vec2 = Godot::Variant.new(Godot::Vector2.new(12.0_f32, 24.0_f32))
    res_vec2 = match val_vec2 do
      is Godot::Vector2 do "Vec2: (#{val_vec2.x.to_i}, #{val_vec2.y.to_i})" end
      default           do "other" end
    end
    assert_eq res_vec2, "Vec2: (12, 24)"

    # Vector3 mathematical type narrowing
    val_vec3 = Godot::Variant.new(Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32))
    res_vec3 = match val_vec3 do
      is Godot::Vector3 do "Vec3: z=#{val_vec3.z.to_i}" end
      default           do "other" end
    end
    assert_eq res_vec3, "Vec3: z=3"

    # Color type narrowing
    val_color = Godot::Variant.new(Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32))
    res_color = match val_color do
      is Godot::Color do "Color: r=#{val_color.r.to_i}" end
      default         do "other" end
    end
    assert_eq res_color, "Color: r=1"
  end

  test "Pillar 3: match macro receiver scoping on typed nodes" do
    probe = Godot.create(DslEdgeProbeNode)
    probe.name = "ReceiverProbe"
    res = match probe do
      is DslEdgeProbeNode do
        activate!
        increment(20)
        "activated_#{counter}"
      end
      default do "other" end
    end
    assert_eq res, "activated_21"
    assert_eq probe.counter, 21
    assert_true probe.active
    probe.destroy
  end

  test "Pillar 3: match macro boolean guard clauses and fallbacks" do
    val_high = Godot::Variant.new(500_i64)
    res_high = match val_high do
      is Int64, if: val_high > 100 do "high_int" end
      is Int64                     do "low_int" end
      default                      do "not_int" end
    end
    assert_eq res_high, "high_int"

    val_low = Godot::Variant.new(25_i64)
    res_low = match val_low do
      is Int64, if: val_low > 100 do "high_int" end
      is Int64                    do "low_int" end
      default                     do "not_int" end
    end
    assert_eq res_low, "low_int"

    # Fallback to default
    val_other = Godot::Variant.new(true)
    res_other = match val_other do
      is Int64  do "int" end
      is String do "str" end
      default   do "fallback_default" end
    end
    assert_eq res_other, "fallback_default"
  end

  test "Pillar 3: match macro explicit parameter binding backwards compatibility" do
    val = Godot::Variant.new(42_i64)
    res = match val do
      is Int64 do |number|
        "ExplicitParam: #{number + 8}"
      end
      default do
        "other"
      end
    end
    assert_eq res, "ExplicitParam: 50"
  end

  test "Pillar 4: in_group? symbol and string parity across groups" do
    node = Godot.create(Godot::Node2D)
    node.add_to_group("network_synced")
    node.add_to_group("combat_entities")

    # Symbol lookups
    assert_true node.in_group?(:network_synced)
    assert_true node.in_group?(:combat_entities)
    assert_false node.in_group?(:nonexistent_group)

    # String lookups
    assert_true node.in_group?("network_synced")
    assert_true node.in_group?("combat_entities")
    assert_false node.in_group?("nonexistent_group")

    # Dynamic group removal
    node.remove_from_group("network_synced")
    assert_false node.in_group?(:network_synced)
    assert_false node.in_group?("network_synced")
    assert_true node.in_group?(:combat_entities)

    node.destroy
  end

  test "Pillar 5: onready property initialization and resolution" do
    host = Godot.create(DslEdgeOnreadyHost)

    probe = Godot.create(DslEdgeProbeNode)
    probe.name = "ProbeChild"
    host.add_child(probe)

    target = Godot.create(DslEdgeTargetNode)
    target.name = "TargetChild"
    host.add_child(target)

    # Adding to the active SceneTree root invokes _enter_tree and _ready, which triggers _godot_init_onready_properties
    root.add_child(host)
    host._godot_init_onready_properties

    # Verify onready properties are resolved and typed
    assert_not_nil host.child_probe
    assert_eq host.child_probe.try(&.name), "ProbeChild"

    assert_not_nil host.child_target
    assert_eq host.child_target.try(&.name), "TargetChild"

    root.remove_child(host)
    host.destroy
  end

  test "Pillar 6: Metadata CRUD operations and type conversion" do
    node = Godot.create(Godot::Node2D)

    # Integer metadata
    node.set_meta(:score, 9999_i64)
    assert_eq node.get_meta_i64(:score), 9999_i64

    # String metadata
    node.set_meta("player_name", "Valkyrie")
    assert_eq node.get_meta_str("player_name"), "Valkyrie"

    # Float metadata
    node.set_meta(:multiplier, 2.5_f64)
    assert_approx_eq node.call_f64("get_meta", "multiplier"), 2.5_f64

    # Metadata key checking and removal
    assert_true node.has_meta("score")
    assert_true node.has_meta("player_name")
    node.remove_meta("score")
    assert_false node.has_meta("score")

    # Safe operations on non-existent keys
    assert_false node.has_meta("nonexistent_key")
    node.remove_meta("nonexistent_key") # zero error

    node.destroy
  end

  test "Pillar 7: Quantitative Zero-Leak Verification under assert_no_leak" do
    # Run 500 complete cycles of allocating, querying with each_node, matching variants,
    # accessing metadata, and destroying instances under assert_no_leak.
    assert_no_leak(max_delta_objects: 0, name: "DSL Operations Zero-Leak Stress") do
      500.times do |i|
        parent = Godot.create(Godot::Node2D)
        probe = Godot.create(DslEdgeProbeNode)
        probe.name = "Probe_#{i}"
        probe.set_meta(:cycle, i.to_i64)
        parent.add_child(probe)

        # 1. Receiver-scoped query
        parent.each_node("*", DslEdgeProbeNode) do
          activate!
        end

        # 2. Pattern match
        val = Godot::Variant.new(i.to_i64)
        _res = match val do
          is Int64 do val * 2 end
          default  do 0_i64 end
        end

        # 3. Clean disposal
        parent.destroy
      end
    end
  end

  test "Pillar 7: Quantitative Zero-Orphan Verification under assert_no_new_orphans" do
    assert_no_new_orphans("DSL Tree Operations") do
      root = Godot.create(Godot::Node2D)
      100.times do |i|
        child = Godot.create(DslEdgeProbeNode)
        child.name = "Child_#{i}"
        root.add_child(child)
      end

      # Query nodes
      visited = 0
      root.each_node("*", DslEdgeProbeNode) do
        visited += 1
      end
      assert_eq visited, 100

      root.destroy
    end
  end
end
