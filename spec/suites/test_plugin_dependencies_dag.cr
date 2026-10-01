# =============================================================================
# LibGodot Test Suite: Multi-Plugin Dependency DAG & Cross-Addon Orchestration
# =============================================================================
#
# Tests deep multi-plugin dependency DAG topology:
#   - Root: dummy_base_dep (Base provider)
#   - Mid-tier: dummy_dep_combat, dummy_dep_storage, dummy_dep_weather
#   - Top-tier: dummy_dep_quest (Diamond dependency consuming combat & storage)
# =============================================================================

include Lapis::Test

test_suite "PluginDependenciesDAG" do
  test "topological DAG hierarchy: base provider coexists with mid-tier and diamond consumers" do
    class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)

    # Validate Base provider existence
    assert_true class_db.call_bool("class_exists", "DummyBaseEntity"), "Base provider must exist in ClassDB"

    # Validate Mid-tier consumers
    assert_true class_db.call_bool("class_exists", "DummyCombatEntity"), "Combat mid-tier entity must exist"
    assert_true class_db.call_bool("class_exists", "DummyStorageEntity"), "Storage mid-tier entity must exist"
    assert_true class_db.call_bool("class_exists", "DummyWeatherEntity"), "Weather mid-tier entity must exist"

    # Validate Top-tier diamond consumer (Quest depends on Combat & Storage)
    assert_true class_db.call_bool("class_exists", "DummyQuestEntity"), "Quest top-tier diamond consumer must exist"
  end

  test "cross-addon dynamic interaction: diamond DAG entity assembly and method routing" do
    # 1. Instantiate Base Entity
    base_ptr = Godot::Bridge.construct_object("DummyBaseEntity")
    assert_false base_ptr.null?
    base = Godot::Node2D.new(base_ptr)

    # 2. Instantiate Combat Entity (Mid-tier)
    combat_ptr = Godot::Bridge.construct_object("DummyCombatEntity")
    assert_false combat_ptr.null?
    combat = Godot::Node2D.new(combat_ptr)

    # 3. Instantiate Storage Entity (Mid-tier)
    storage_ptr = Godot::Bridge.construct_object("DummyStorageEntity")
    assert_false storage_ptr.null?
    storage = Godot::Node2D.new(storage_ptr)

    # 4. Instantiate Quest Entity (Top-tier Diamond consumer)
    quest_ptr = Godot::Bridge.construct_object("DummyQuestEntity")
    assert_false quest_ptr.null?
    quest = Godot::Node2D.new(quest_ptr)

    # Wire entities in scene tree hierarchy: Base -> [Combat, Storage] -> Quest
    root.add_child(base)
    base.add_child(combat)
    base.add_child(storage)
    combat.add_child(quest)

    assert_eq base.get_child_count, 2_i64
    assert_eq combat.get_child_count, 1_i64
    assert_eq quest.get_parent.not_nil!.name, combat.name

    # Cross-addon property reflection across distinct DLL modules
    combat.call("set", "combo_counter", 15_i64)
    storage.call("set", "max_slots", 64_i64)
    quest.call("set", "current_quest", "DragonSlayer")

    assert_eq combat.call_i64("get", "combo_counter"), 15_i64
    assert_eq storage.call_i64("get", "max_slots"), 64_i64
    assert_eq quest.call_str("get", "current_quest"), "DragonSlayer"

    # Clean unparenting and destruction
    root.remove_child(base)
    base.destroy
  end

  test "ClassDB signal and inheritance isolation: distinct ClassDB registrations across separate DLLs" do
    cdb_ptr = Godot::Bridge.get_singleton("ClassDB")
    class_db = Godot::ClassDB.new(cdb_ptr)

    # ClassDB registration and inheritance hierarchy isolation
    assert_true class_db.call_bool("class_exists", "DummyCombatEntity"), "Combat entity must exist in ClassDB"
    assert_true class_db.call_bool("class_exists", "DummyStorageEntity"), "Storage entity must exist in ClassDB"
    assert_true class_db.call_bool("class_exists", "DummyQuestEntity"), "Quest entity must exist in ClassDB"

    assert_true class_db.call_bool("is_parent_class", "DummyCombatEntity", "Node2D")
    assert_true class_db.call_bool("is_parent_class", "DummyStorageEntity", "Node2D")
    assert_true class_db.call_bool("is_parent_class", "DummyQuestEntity", "Node2D")

    # Distinct signals across DLL boundaries
    assert_true class_db.call_bool("class_has_signal", "DummyCombatEntity", "attack_executed"), "Combat entity must register attack_executed signal"
    assert_true class_db.call_bool("class_has_signal", "DummyCombatEntity", "critical_hit"), "Combat entity must register critical_hit signal"
    assert_false class_db.call_bool("class_has_signal", "DummyStorageEntity", "attack_executed"), "Storage entity must not leak attack_executed signal"

    assert_true class_db.call_bool("class_has_signal", "DummyStorageEntity", "item_deposited"), "Storage entity must register item_deposited signal"
    assert_true class_db.call_bool("class_has_signal", "DummyStorageEntity", "inventory_full"), "Storage entity must register inventory_full signal"
    assert_false class_db.call_bool("class_has_signal", "DummyCombatEntity", "item_deposited"), "Combat entity must not leak item_deposited signal"

    assert_true class_db.call_bool("class_has_signal", "DummyQuestEntity", "quest_advanced"), "Quest entity must register quest_advanced signal"
    assert_true class_db.call_bool("class_has_signal", "DummyQuestEntity", "quest_completed"), "Quest entity must register quest_completed signal"
    assert_false class_db.call_bool("class_has_signal", "DummyCombatEntity", "quest_advanced"), "Combat entity must not leak quest_advanced signal"
  end

  test "assert_no_leak proves zero memory leak across cross-addon instantiation churn" do
    assert_no_leak(max_delta_objects: 0, name: "PluginChurn") do
      20.times do
        base_ptr = Godot::Bridge.construct_object("DummyBaseEntity")
        combat_ptr = Godot::Bridge.construct_object("DummyCombatEntity")
        quest_ptr = Godot::Bridge.construct_object("DummyQuestEntity")

        base = Godot::Node2D.new(base_ptr)
        combat = Godot::Node2D.new(combat_ptr)
        quest = Godot::Node2D.new(quest_ptr)

        base.add_child(combat)
        combat.add_child(quest)

        base.destroy
      end
    end
  end
end
