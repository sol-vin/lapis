# =============================================================================
# LibGodot Test Suite: SceneTree Fluent Operators & Resource Card Macro
# =============================================================================
# Verifies parent << child chaining, parent.spawn(Type) { ... },
# and resource_card strategy cloning.

include Lapis::Test

node ErgonomicChildNode < Godot::Node2D do
  property tag : String = "default"
end

resource_card ErgonomicSpellCard < Godot::Resource do
  property mana_cost : Int32 = 15
  property spell_name : String = "Fireball"
end

test_suite "Ergonomics" do
  test "parent << child supports fluent chaining of multiple child nodes" do
    parent = Godot.create(Godot::Node2D)
    c1 = Godot.create(ErgonomicChildNode)
    c1.name = "Child1"
    c2 = Godot.create(ErgonomicChildNode)
    c2.name = "Child2"
    c3 = Godot.create(ErgonomicChildNode)
    c3.name = "Child3"

    # Fluent chain
    parent << c1 << c2 << c3

    assert_eq parent.child_count, 3
    assert_eq parent.children[0].name, "Child1"
    assert_eq parent.children[1].name, "Child2"
    assert_eq parent.children[2].name, "Child3"

    c1.destroy
    c2.destroy
    c3.destroy
    parent.destroy
  end

  test "parent.spawn creates, configures, and attaches child node" do
    parent = Godot.create(Godot::Node2D)

    spawned = parent.spawn(ErgonomicChildNode) do |child|
      child.tag = "custom_spawn"
      child.name = "SpawnedChild"
    end

    assert_eq parent.child_count, 1
    assert_eq spawned.tag, "custom_spawn"
    assert_eq spawned.name, "SpawnedChild"

    spawned.destroy
    parent.destroy
  end

  test "resource_card macro creates custom resource with clone_card capability" do
    card = Godot.create(ErgonomicSpellCard)
    card.mana_cost = 45
    card.spell_name = "LightningBolt"

    assert_eq card.mana_cost, 45
    assert_eq card.spell_name, "LightningBolt"

    cloned = card.clone_card
    assert_not_nil cloned
    assert_eq cloned.mana_cost, 45
    assert_eq cloned.spell_name, "LightningBolt"

    # Mutating cloned does not mutate original
    cloned.mana_cost = 99
    assert_eq card.mana_cost, 45
    assert_eq cloned.mana_cost, 99
  end

  test "wildcard query operator * supports untyped glob and typed tuple filtering" do
    parent = Godot.create(Godot::Node2D)
    parent.name = "Root"

    branch = Godot.create(Godot::Node2D)
    branch.name = "MyNodes"
    parent.add_child(branch)

    c1 = Godot.create(ErgonomicChildNode)
    c1.name = "Mesh1"
    c1.tag = "alpha"
    branch.add_child(c1)

    c2 = Godot.create(ErgonomicChildNode)
    c2.name = "Mesh2"
    c2.tag = "beta"
    branch.add_child(c2)

    c3 = Godot.create(Godot::Node2D)
    c3.name = "OtherMesh"
    branch.add_child(c3)

    # 1. Untyped wildcard glob: parent * "MyNodes/Mesh*"
    all_meshes = parent * "MyNodes/Mesh*"
    assert_eq all_meshes.size, 2
    assert_true all_meshes.any? { |m| m.name == "Mesh1" }
    assert_true all_meshes.any? { |m| m.name == "Mesh2" }

    # 2. Typed wildcard glob tuple: parent * {"MyNodes/Mesh*", ErgonomicChildNode}
    typed_meshes = parent * {"MyNodes/Mesh*", ErgonomicChildNode}
    assert_eq typed_meshes.size, 2
    assert_eq typed_meshes.first.tag, "alpha"
    assert_eq typed_meshes.last.tag, "beta"

    # 3. Chained path traversal then wildcard: parent / "MyNodes" * "Mesh*"
    chained_meshes = parent / "MyNodes" * "Mesh*"
    assert_eq chained_meshes.size, 2

    # 4. Chained path traversal then typed wildcard: parent / "MyNodes" * {"Mesh*", ErgonomicChildNode}
    chained_typed = parent / "MyNodes" * {"Mesh*", ErgonomicChildNode}
    assert_eq chained_typed.size, 2
    assert_eq chained_typed.first.tag, "alpha"

    # 5. Regex wildcard matching: parent * /^Mesh\d+$/
    regex_matches = parent * /^Mesh\d+$/
    assert_eq regex_matches.size, 2

    # 6. Typed regex matching: parent * {/^Mesh\d+$/, ErgonomicChildNode}
    typed_regex = parent * {/^Mesh\d+$/, ErgonomicChildNode}
    assert_eq typed_regex.size, 2
    assert_eq typed_regex.first.tag, "alpha"

    c1.destroy
    c2.destroy
    c3.destroy
    branch.destroy
    parent.destroy
  end
end
