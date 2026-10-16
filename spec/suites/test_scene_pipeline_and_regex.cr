# =============================================================================
# LibGodot Test Suite: Scene Pipeline Nilable Operators & Regex Node Queries
# =============================================================================

include Lapis::Test

node PipelineTestNode < Godot::Node2D do
  property label : String = "PipelineTest"
end

test_suite "ScenePipelineRegex" do
  test "Regex node query via Node#find_child and Node#find_children" do
    root = Godot.create(Godot::Node2D)
    root.name = "Root"

    child1 = Godot.create(Godot::Node2D)
    child1.name = "Enemy_01"
    child2 = Godot.create(Godot::Node2D)
    child2.name = "Enemy_02"
    child3 = Godot.create(Godot::Node2D)
    child3.name = "Ally_01"

    nested = Godot.create(Godot::Node2D)
    nested.name = "Enemy_Nested"
    child2.add_child(nested)

    root.add_child(child1)
    root.add_child(child2)
    root.add_child(child3)

    # 1. Direct regex query find_child
    found_one = root.find_child(/Enemy_\d+/)
    assert_not_nil found_one
    assert_true found_one.try(&.name) == "Enemy_01" || found_one.try(&.name) == "Enemy_02"

    # 2. Direct regex query find_children (recursive)
    enemies = root.find_children(/Enemy_.+/)
    assert_eq enemies.size, 3

    # 3. Direct regex query find_children (non-recursive)
    shallow_enemies = root.find_children(/Enemy_.+/, recursive: false)
    assert_eq shallow_enemies.size, 2

    # 4. NodeQuery helper parity
    nq_found = Godot::NodeQuery.find_nodes_by_regex(root, /^Enemy/)
    assert_eq nq_found.size, 3

    nq_single = Godot::NodeQuery.find_node_by_regex(root, /^Ally/)
    assert_not_nil nq_single
    assert_eq nq_single.try(&.name), "Ally_01"

    child2.remove_child(nested)
    root.remove_child(child1)
    root.remove_child(child2)
    root.remove_child(child3)
    nested.destroy
    child1.destroy
    child2.destroy
    child3.destroy
    root.destroy
  end

  test "Active NodeContext unary ~Regex and nodes(Regex) query" do
    root = Godot.create(Godot::Node2D)
    c1 = Godot.create(Godot::Node2D)
    c1.name = "TargetAlpha"
    c2 = Godot.create(Godot::Node2D)
    c2.name = "TargetBeta"
    root.add_child(c1)
    root.add_child(c2)

    Godot::NodeContext.scope(root) do
      # 1. Unary ~ on Regex resolves single match
      matched = ~/TargetAlpha/
      assert_not_nil matched
      assert_eq matched.try(&.name), "TargetAlpha"

      # Missing regex returns nil
      assert_nil ~/NoSuchTarget\d+/

      # 2. nodes(Regex) resolves all matches
      targets = nodes(/Target\w+/)
      assert_eq targets.size, 2

      no_targets = nodes(/NonExistentPattern/)
      assert_true no_targets.empty?
    end

    root.remove_child(c1)
    root.remove_child(c2)
    c1.destroy
    c2.destroy
    root.destroy
  end

  test "Nilable scene pipeline operators > and >> with T?" do
    # 1. Non-existent scene path with T? returns nil instead of raising
    missing_inst = "res://missing_scene_12345.tscn" > Godot::Node2D?
    assert_nil missing_inst

    # 2. Non-existent scene path with >> and T? returns nil instead of raising
    missing_loaded = "res://missing_scene_12345.tscn" >> Godot::Node2D?
    assert_nil missing_loaded

    # 3. PackedScene#instantiate_as? handles type mismatch returning nil without raising
    scene = Godot.create(Godot::PackedScene)
    # Empty packed scene instantiation returns nil safely
    inst = scene.instantiate_as?(PipelineTestNode)
    assert_nil inst

    # Scene pipeline operator > with T? on PackedScene returns nil safely
    pipe_res = scene > PipelineTestNode?
    assert_nil pipe_res

    scene.destroy
  end

  test "Nilable resource loading via load? and preload?" do
    # 1. Godot.load? returns nil on missing resource without raising
    res = Godot.load?("res://missing_resource_xyz.tres")
    assert_nil res

    # 2. Godot.load_scene? returns nil on missing scene
    scene = Godot.load_scene?("res://missing_scene_xyz.tscn")
    assert_nil scene

    # 3. Godot.instantiate_scene? returns nil on missing scene
    node = Godot.instantiate_scene?("res://missing_scene_xyz.tscn")
    assert_nil node

    # 4. Godot.preload? returns nil on missing resource
    p_res = Godot.preload?("res://missing_resource_xyz.tres")
    assert_nil p_res

    # 5. Macro load? and preload? syntax
    macro_loaded = load?("res://missing_resource_abc.tres")
    assert_nil macro_loaded

    macro_preloaded = preload?("res://missing_resource_abc.tres")
    assert_nil macro_preloaded

    # 6. Type casting via .as?
    typed_cast = load?("res://missing_resource_abc.tres").as?(Godot::Resource)
    assert_nil typed_cast
  end

  test "Mathematical zero-leak verification for regex queries and nilable pipelines" do
    assert_no_leak do
      5.times do
        root = Godot.create(Godot::Node2D)
        c1 = Godot.create(Godot::Node2D)
        c1.name = "LeakCheck1"
        root.add_child(c1)

        Godot::NodeContext.scope(root) do
          _ = ~/LeakCheck1/
          _ = nodes(/LeakCheck\d/)
        end

        _ = root.find_child(/LeakCheck/)
        _ = root.find_children(/LeakCheck/)

        _ = "res://no_such_file.tscn" > Godot::Node2D?
        _ = "res://no_such_file.tscn" >> Godot::Node2D?
        _ = load?("res://no_such_res.tres")
        _ = preload?("res://no_such_res.tres")

        root.remove_child(c1)
        c1.destroy
        root.destroy
      end
    end
  end
end
