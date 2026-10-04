# =============================================================================
# LibGodot Test Suite: DSL Helpers, Ancestor Operator, Group DSL & OnReady
# =============================================================================

include Lapis::Test

# Test hierarchy nodes for ancestor search tests
node AncestorRoot < Godot::Node2D do
  property score : Int32 = 100
end

node AncestorParent < Godot::Node2D do
  property region_name : String = "Forest"
end

node AncestorHitbox < Godot::Area2D do
  property damage : Int32 = 25
end

node AncestorUnrelated < Godot::Node2D do
end

# Test node for group query tests
node GroupTestEnemy < Godot::Node2D do
  property health : Int32 = 100
  property hits_received : Int32 = 0

  def take_damage(amount : Int32) : Void
    @health -= amount
    @hits_received += 1
  end
end

node GroupTestBoss < Godot::Node2D do
  property boss_title : String = "Dragon King"
end

# Test node for onready custom getter/setter tests
node OnReadyProbeNode < Godot::Node2D do
  onready child_marker : Godot::Marker2D = "Marker"
  property custom_setter_called : Bool = false
  property custom_getter_called : Bool = false

  def child_marker=(marker : Godot::Marker2D?) : Void
    @child_marker = marker
    @custom_setter_called = true
  end

  def child_marker : Godot::Marker2D?
    @custom_getter_called = true
    @child_marker
  end
end

test_suite "DslHelpersAndOnReady" do
  test "Pillar 1: upward ancestor search via << operator and find_ancestor_as" do
    root_node = Godot.create(AncestorRoot)
    parent_node = Godot.create(AncestorParent)
    hitbox = Godot.create(AncestorHitbox)

    root_node.add_child(parent_node)
    parent_node.add_child(hitbox)

    # 1. Strict ancestor search: hitbox << AncestorParent
    parent_found = hitbox << AncestorParent
    assert_not_nil parent_found
    assert_eq parent_found.region_name, "Forest"

    # 2. Strict ancestor search to higher root: hitbox << AncestorRoot
    root_found = hitbox << AncestorRoot
    assert_not_nil root_found
    assert_eq root_found.score, 100

    # 3. Strict ancestor search for missing type raises NodeNotFoundError
    assert_raises(Godot::NodeNotFoundError) do
      hitbox << AncestorUnrelated
    end

    # 4. Nilable ancestor search: hitbox << AncestorParent?
    maybe_parent = hitbox << AncestorParent?
    assert_not_nil maybe_parent
    if p = maybe_parent
      assert_eq p.region_name, "Forest"
    end

    # 5. Nilable ancestor search for missing type returns nil
    maybe_unrelated = hitbox << AncestorUnrelated?
    assert_nil maybe_unrelated

    # 6. find_ancestor_as and find_ancestor_as! parity
    assert_eq hitbox.find_ancestor_as!(AncestorParent).region_name, "Forest"
    assert_nil hitbox.find_ancestor_as(AncestorUnrelated)

    # Teardown
    parent_node.remove_child(hitbox)
    root_node.remove_child(parent_node)
    hitbox.destroy
    parent_node.destroy
    root_node.destroy
  end

  test "Pillar 2: fluent group(:name) DSL iteration, collection, and queries" do
    enemy1 = Godot.create(GroupTestEnemy)
    enemy2 = Godot.create(GroupTestEnemy)
    boss = Godot.create(GroupTestBoss)

    test_parent = Godot.create(Godot::Node2D)
    test_parent.add_child(enemy1)
    test_parent.add_child(enemy2)
    test_parent.add_child(boss)

    enemy1.add_to_group("test_enemies")
    enemy2.add_to_group("test_enemies")
    boss.add_to_group("test_bosses")

    # 1. to_a as typed and untyped
    all_enemies = test_parent.group(:test_enemies).to_a(as: GroupTestEnemy)
    assert_eq all_enemies.size, 2

    # 2. size, empty?, and any?
    assert_eq test_parent.group(:test_enemies).size, 2
    assert_false test_parent.group(:test_enemies).empty?
    assert_true test_parent.group(:test_enemies).any?
    assert_true test_parent.group(:empty_group).empty?
    assert_false test_parent.group(:empty_group).any?
    assert_eq test_parent.group(:empty_group).size, 0

    # 3. each iteration with typed receiver
    total_health = 0
    test_parent.group(:test_enemies).each(as: GroupTestEnemy) do |e|
      total_health += e.health
    end
    assert_eq total_health, 200

    # 4. first? and first
    boss_found = test_parent.group(:test_bosses).first(as: GroupTestBoss)
    assert_not_nil boss_found
    if b = boss_found
      assert_eq b.boss_title, "Dragon King"
    end
    assert_nil test_parent.group(:empty_group).first

    # 5. first! (raises NodeNotFoundError on missing)
    assert_eq test_parent.group(:test_bosses).first!(as: GroupTestBoss).boss_title, "Dragon King"
    assert_raises(Godot::NodeNotFoundError) do
      test_parent.group(:empty_group).first!(as: GroupTestBoss)
    end

    # 6. Typed each group dispatch
    test_parent.group(:test_enemies).each(as: GroupTestEnemy) do |e|
      e.take_damage(15)
    end
    assert_eq enemy1.health, 85
    assert_eq enemy2.health, 85
    assert_eq enemy1.hits_received, 1
    assert_eq enemy2.hits_received, 1

    # 7. Native engine method call broadcast across group
    test_parent.group(:test_enemies).call("set_visible", false)
    assert_false enemy1.is_visible
    assert_false enemy2.is_visible

    # Teardown
    test_parent.remove_child(enemy1)
    test_parent.remove_child(enemy2)
    test_parent.remove_child(boss)
    enemy1.destroy
    enemy2.destroy
    boss.destroy
    test_parent.destroy
  end

  test "Pillar 3: onready property initialization and custom getters/setters" do
    probe = Godot.create(OnReadyProbeNode)
    marker = Godot.create(Godot::Marker2D)
    marker.name = "Marker"
    probe.add_child(marker)

    # Initialize onready properties directly
    if probe.responds_to?(:_godot_init_onready_properties)
      probe._godot_init_onready_properties
    end

    # Verify custom setter was triggered during assignment
    assert_true probe.custom_setter_called

    # Verify custom getter returns marker and flag is set
    fetched_marker = probe.child_marker
    assert_true probe.custom_getter_called
    assert_not_nil fetched_marker
    assert_eq fetched_marker.try(&.name), "Marker"

    probe.remove_child(marker)
    marker.destroy
    probe.destroy
  end

  test "Pillar 4: load and preload compile-time extension type inference" do
    # 1. Type inference verification:
    # .tscn -> PackedScene
    # .svg / .png -> Texture2D
    # .wav -> AudioStream
    # other / .tres -> Resource
    #
    # We verify that load macro produces correct typed wrappers when files exist in Godot VFS,
    # or fallback cleanly in mock/test VFS paths.
    if Godot::ResourceLoader.singleton_ptr.null? == false
      res_loader = Godot::ResourceLoader.new(Godot::ResourceLoader.singleton_ptr)
      if res_loader.exists("res://scenes/main_test_runner.tscn")
        scene = load("res://scenes/main_test_runner.tscn")
        assert_not_nil scene
        assert_true scene.is_a?(Godot::PackedScene)

        cached_scene = preload("res://scenes/main_test_runner.tscn")
        assert_not_nil cached_scene
        assert_true cached_scene.is_a?(Godot::PackedScene)
      end

      if Godot.editor_hint? && res_loader.exists("res://icon.svg")
        tex = load("res://icon.svg")
        assert_not_nil tex
        assert_true tex.is_a?(Godot::Texture2D)

        cached_tex = preload("res://icon.svg")
        assert_not_nil cached_tex
        assert_true cached_tex.is_a?(Godot::Texture2D)
      end
    end
  end

  test "Pillar 5: Godot.on_main_thread and on_main_thread dispatch" do
    executed = false
    Godot.on_main_thread do
      executed = true
    end
    assert_true executed

    top_level_executed = false
    on_main_thread do
      top_level_executed = true
    end
    assert_true top_level_executed
  end

  test "Pillar 6: mathematical zero leak verification" do
    assert_no_leak do
      5.times do
        root_node = Godot.create(AncestorRoot)
        parent_node = Godot.create(AncestorParent)
        hitbox = Godot.create(AncestorHitbox)

        root_node.add_child(parent_node)
        parent_node.add_child(hitbox)

        _ = hitbox << AncestorParent
        _ = hitbox << AncestorRoot?

        parent_node.remove_child(hitbox)
        root_node.remove_child(parent_node)

        hitbox.destroy
        parent_node.destroy
        root_node.destroy
      end
    end
  end
end
