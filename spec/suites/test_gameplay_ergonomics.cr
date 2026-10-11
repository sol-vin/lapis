# =============================================================================
# LibGodot Test Suite: Next-Generation Gameplay Usability & Ergonomics
# =============================================================================

include Lapis::Test

node SuiteErgoPlayer < Godot::Node do
  property name_tag : String = "Hero"
  signal hit(player : Godot::Node, amount : Int32)
  signal equipped(player : Godot::Node, weapon : Godot::Node)
end

node SuiteErgoEnemy < Godot::Node do
  property hp : Int32 = 100
end

node SuiteErgoSword < Godot::Node do
  property power : Int32 = 25
end

test_suite "GameplayErgonomics" do
  test "Pillar 1: Direct tree instantiation and configuration block" do
    parent = Godot.create(Godot::Node)
    child = parent.add_child(SuiteErgoPlayer) do |p|
      p.name_tag = "Champion"
    end

    assert_not_nil child
    assert_true child.is_a?(SuiteErgoPlayer)
    assert_eq child.name_tag, "Champion"
    assert_eq parent.get_child_count, 1_i64

    sibling = child.add_sibling(SuiteErgoEnemy) do |e|
      e.hp = 300
    end

    assert_not_nil sibling
    assert_true sibling.is_a?(SuiteErgoEnemy)
    assert_eq sibling.hp, 300
    assert_eq parent.get_child_count, 2_i64

    parent.destroy
  end

  test "Pillar 2: Frictionless Dictionary with kwargs, Symbol keys, typed get, and dig?" do
    dict = Godot::Dictionary.new(health: 100, speed: 7.5_f32, hero: "Lapis")
    assert_eq dict[:health].raw, 100_i64
    assert_approx_eq dict.get(:speed, as: Float32, default: 0.0_f32), 7.5_f32
    assert_eq dict[:hero].raw, "Lapis"

    dict[:score] = 500
    assert_eq dict[:score].raw, 500_i64
    assert_true dict.has(:score)
    assert_true dict.has_key?(:score)

    assert_eq dict.get(:score, as: Int32, default: 0), 500
    assert_eq dict.get(:missing, as: Int32, default: 999), 999
    assert_eq dict.get?(:score, as: Int32), 500
    assert_nil dict.get?(:missing, as: Int32)

    inner = Godot::Dictionary.new(base: 30)
    outer = Godot::Dictionary.new(attack: inner)
    root = Godot::Dictionary.new(stats: outer)
    assert_eq root.dig?(:stats, :attack, :base, as: Int32), 30
    assert_nil root.dig?(:stats, :defense, :base, as: Int32)

    hash = {"a" => "apple", "b" => "banana"}
    gd_dict = hash.to_godot
    assert_eq gd_dict["a"].raw, "apple"
  end

  test "Pillar 3: GodotArray fluent conversions, filter_as, and bounds helpers" do
    arr = [10, 20, 30].to_godot
    assert_eq arr.size, 3_i64
    assert_eq arr[0], 10
    assert_eq arr[-1], 30

    assert_eq arr.first?, 10
    assert_eq arr.last?, 30
    assert_true [10, 20, 30].includes?(arr.sample.not_nil!)

    parent = Godot.create(Godot::Node)
    p1 = parent.add_child(SuiteErgoPlayer)
    e1 = parent.add_child(SuiteErgoEnemy)
    e2 = parent.add_child(SuiteErgoEnemy)

    children = parent.get_children
    enemies = children.filter_as(SuiteErgoEnemy)
    assert_eq enemies.size, 2
    enemies.each do |e|
      assert_true e.is_a?(SuiteErgoEnemy)
    end

    players = children.filter_as(SuiteErgoPlayer)
    assert_eq players.size, 1
    assert_eq players.first, p1

    parent.destroy
  end

  test "Pillar 4: Positional type-filtered signals, on macro, += and -= operators" do
    player = SuiteErgoPlayer.new
    sword = SuiteErgoSword.new
    enemy = SuiteErgoEnemy.new

    received_sword : SuiteErgoSword? = nil
    received_player : SuiteErgoPlayer? = nil

    on player.equipped, SuiteErgoPlayer, SuiteErgoSword do |p, s|
      received_player = p
      received_sword = s
    end

    # Mismatch emission
    player.equipped.emit(player, enemy)
    assert_nil received_player
    assert_nil received_sword

    # Matching emission
    player.equipped.emit(player, sword)
    assert_eq received_player, player
    assert_eq received_sword, sword

    # Wildcard Any
    matched_player : SuiteErgoPlayer? = nil
    matched_raw : Godot::VariantValue? = nil

    on player.hit, SuiteErgoPlayer, Any do |p, raw|
      matched_player = p
      matched_raw = raw
    end

    player.hit.emit(player, 42)
    assert_eq matched_player, player
    assert_eq matched_raw, 42_i64

    # Compound operators += and -=
    handled_count = 0
    handler = ->(p : SuiteErgoPlayer, s : SuiteErgoSword) {
      handled_count += 1
    }

    player.equipped += handler
    player.equipped.emit(player, sword)
    assert_eq handled_count, 1

    player.equipped -= handler
    player.equipped.emit(player, sword)
    assert_eq handled_count, 1

    # Disconnect all
    count = 0
    player.hit.connect { count += 1 }
    player.hit.connect { count += 1 }
    player.hit.emit(player, 1)
    assert_eq count, 2

    player.hit.disconnect_all
    player.hit.emit(player, 1)
    assert_eq count, 2
  end

  test "Pillar 5: Direct space physics structures" do
    player = SuiteErgoPlayer.new
    hit2d = Godot::PhysicsHit2D.new(
      point: Godot::Vector2.new(10.0_f32, 20.0_f32),
      normal: Godot::Vector2.new(0.0_f32, -1.0_f32),
      collider: player
    )
    assert_approx_eq hit2d.point.x, 10.0_f32
    assert_approx_eq hit2d.point.y, 20.0_f32
    assert_eq hit2d.collider.as?(SuiteErgoPlayer), player
    assert_nil hit2d.collider.as?(SuiteErgoEnemy)

    hit3d = Godot::PhysicsHit3D.new(
      point: Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32),
      normal: Godot::Vector3.new(0.0_f32, 1.0_f32, 0.0_f32),
      collider: player
    )
    assert_approx_eq hit3d.point.z, 3.0_f32
    assert_eq hit3d.collider.as?(SuiteErgoPlayer), player
    assert_nil hit3d.collider.as?(SuiteErgoEnemy)
  end

  test "Pillar 6: Lifecycle-safe cooperative timers" do
    handle = Godot::TimerHandle.new(1.0)
    assert_true handle.running?
    assert_false handle.cancelled?

    handle.pause
    assert_true handle.paused?

    handle.resume
    assert_false handle.paused?

    handle.cancel
    assert_true handle.cancelled?
    assert_false handle.running?

    handle2 = Godot::TimerHandle.new(0.5)
    assert_false handle2.advance(0.2)
    assert_true handle2.advance(0.3)
    assert_eq handle2.tick_count, 1

    handle2.reset
    assert_eq handle2.tick_count, 0
    assert_approx_eq handle2.elapsed_time.to_f32, 0.0_f32
  end

  test "Pillar 7 & 8: ConfigFile, Resource, and SceneTree ergonomics" do
    cfg = Godot.create(Godot::ConfigFile)
    cfg.set_value("sound", "volume", 0.8)
    assert_approx_eq cfg.get("sound", "volume", as: Float64, default: 1.0).to_f32, 0.8_f32
    assert_approx_eq cfg.get("sound", "missing", as: Float64, default: 1.0).to_f32, 1.0_f32
    cfg.destroy

    err = Godot::SceneChangeError.new("Scene load failure")
    assert_eq err.message, "Scene load failure"
  end

  test "Pillar 9: NodeType.instantiate, add_sibling, and add_child positional scene overloads" do
    # 1. Direct class-level instantiate with config block
    marker = Godot::Marker2D.instantiate("res://scenes/test_marker_scene.tscn") do |m|
      m.position = Godot::Vector2.new(10.0_f32, 50.0_f32)
    end
    assert_not_nil marker
    assert_true marker.is_a?(Godot::Marker2D)
    assert_approx_eq marker.position.x, 10.0_f32
    assert_approx_eq marker.position.y, 50.0_f32

    # 2. Add sibling using (path, Type) positional args
    parent = Godot.create(Godot::Node2D)
    child1 = parent.add_child(Godot::Node2D)

    sibling = child1.add_sibling("res://scenes/test_marker_scene.tscn", Godot::Marker2D) do |s|
      s.position = Godot::Vector2.new(25.0_f32, 75.0_f32)
    end
    assert_not_nil sibling
    assert_true sibling.is_a?(Godot::Marker2D)
    assert_approx_eq sibling.position.x, 25.0_f32
    assert_approx_eq sibling.position.y, 75.0_f32
    assert_eq parent.get_child_count, 2_i64

    # 3. Add child using (path, Type) positional args
    child2 = parent.add_child("res://scenes/test_marker_scene.tscn", Godot::Marker2D) do |c|
      c.position = Godot::Vector2.new(5.0_f32, 15.0_f32)
    end
    assert_not_nil child2
    assert_true child2.is_a?(Godot::Marker2D)
    assert_approx_eq child2.position.x, 5.0_f32
    assert_approx_eq child2.position.y, 15.0_f32
    assert_eq parent.get_child_count, 3_i64

    # 4. Safe nilable variant on non-existent path
    nil_marker = Godot::Marker2D.instantiate?("res://scenes/does_not_exist_xyz.tscn")
    assert_nil nil_marker

    # 5. Nested instantiate passed directly to add_sibling
    sibling2 = child1.add_sibling(Godot::Marker2D.instantiate("res://scenes/test_marker_scene.tscn") do |m|
      m.position = Godot::Vector2.new(0.0_f32, 50.0_f32)
    end)
    assert_not_nil sibling2
    assert_true sibling2.is_a?(Godot::Marker2D)
    assert_approx_eq sibling2.position.y, 50.0_f32
    assert_eq parent.get_child_count, 4_i64

    parent.destroy
    marker.destroy
  end
end

