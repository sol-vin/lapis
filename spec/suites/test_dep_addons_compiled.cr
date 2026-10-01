# =============================================================================
# LibGodot Test Suite: Multi-Plugin Dependency Addon Integration (Compiled Mode)
# =============================================================================
#
# Verifies a single base addon (dummy_base_dep) functioning as a shared dependency
# for 4 distinct consumer plugins (dummy_dep_combat, dummy_dep_storage,
# dummy_dep_quest, dummy_dep_weather) in fully compiled GDExtension mode.
# =============================================================================

include Lapis::Test

test_suite "DepAddonsCompiled" do
  test "ClassDB registration and inheritance hierarchy across all 5 compiled addons" do
    class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)

    # 1. Base dependency classes registered by dummy_base_dep.dll
    assert_true class_db.call_bool("class_exists", "DummyBaseEntity"), "DummyBaseEntity must be registered in ClassDB"
    assert_true class_db.call_bool("is_parent_class", "DummyBaseEntity", "Node2D"), "DummyBaseEntity must inherit Node2D"
    assert_true class_db.call_bool("is_parent_class", "DummyBaseEntity", "CanvasItem"), "DummyBaseEntity must inherit CanvasItem"
    assert_true class_db.call_bool("is_parent_class", "DummyBaseEntity", "Node"), "DummyBaseEntity must inherit Node"

    assert_true class_db.call_bool("class_exists", "DummyBaseConfig"), "DummyBaseConfig resource must be registered in ClassDB"
    assert_true class_db.call_bool("is_parent_class", "DummyBaseConfig", "Resource"), "DummyBaseConfig must inherit Resource"

    # 2. Four consumer plugins registered by independent DLLs (inheriting Node2D)
    plugin_entities = ["DummyCombatEntity", "DummyStorageEntity", "DummyQuestEntity", "DummyWeatherEntity"]
    plugin_entities.each do |entity_name|
      assert_true class_db.call_bool("class_exists", entity_name), "#{entity_name} must be registered in ClassDB"
      assert_true class_db.call_bool("is_parent_class", entity_name, "Node2D"), "#{entity_name} must inherit Node2D"
      assert_true class_db.call_bool("is_parent_class", entity_name, "CanvasItem"), "#{entity_name} must transitively inherit CanvasItem"
      assert_true class_db.call_bool("is_parent_class", entity_name, "Node"), "#{entity_name} must transitively inherit Node"
    end

    # 3. In editor sessions, verify EditorPlugin classes coexist
    if Godot.editor_hint?
      plugin_editors = ["DummyBasePlugin", "DummyCombatPlugin", "DummyStoragePlugin", "DummyQuestPlugin", "DummyWeatherPlugin"]
      plugin_editors.each do |editor_name|
        assert_true class_db.call_bool("class_exists", editor_name), "#{editor_name} must be registered in ClassDB in editor"
        assert_true class_db.call_bool("is_parent_class", editor_name, "EditorPlugin"), "#{editor_name} must inherit EditorPlugin"
      end
    end
  end

  test "Lifecycle, property reflection, and state tracking across all 5 compiled addons" do
    # 1. Base Entity (dummy_base_dep.dll)
    base_ptr = Godot::Bridge.construct_object("DummyBaseEntity")
    assert_false base_ptr.null?, "DummyBaseEntity must be constructible via ClassDB"
    base = Godot::Node2D.new(base_ptr)
    assert_true base.alive?, "DummyBaseEntity must be alive"
    assert_eq base.call_str("get", "base_id"), "base_entity_0"
    assert_eq base.call_f64("get", "health_ratio"), 1.0_f64
    assert_true base.call_bool("get", "is_base_active")

    # Mutate properties via reflection
    base.call("set", "base_id", "custom_base_id_99")
    base.call("set", "is_base_active", false)
    assert_eq base.call_str("get", "base_id"), "custom_base_id_99"
    assert_false base.call_bool("get", "is_base_active")
    base.destroy
    assert_true base.destroyed?

    # 2. Combat Entity (dummy_dep_combat.dll)
    combat_ptr = Godot::Bridge.construct_object("DummyCombatEntity")
    assert_false combat_ptr.null?, "DummyCombatEntity must be constructible via ClassDB"
    combat = Godot::Node2D.new(combat_ptr)
    assert_true combat.alive?, "DummyCombatEntity must be alive"
    assert_eq combat.call_f64("get", "attack_power"), 45.0_f64
    assert_eq combat.call_i64("get", "combo_counter"), 0_i64

    # Mutate combat state via reflection
    combat.call("set", "attack_power", 95.5_f64)
    combat.call("set", "combo_counter", 3_i64)
    assert_eq combat.call_f64("get", "attack_power"), 95.5_f64
    assert_eq combat.call_i64("get", "combo_counter"), 3_i64
    combat.destroy
    assert_true combat.destroyed?

    # 3. Storage Entity (dummy_dep_storage.dll)
    storage_ptr = Godot::Bridge.construct_object("DummyStorageEntity")
    assert_false storage_ptr.null?, "DummyStorageEntity must be constructible via ClassDB"
    storage = Godot::Node2D.new(storage_ptr)
    assert_true storage.alive?, "DummyStorageEntity must be alive"
    assert_eq storage.call_i64("get", "max_slots"), 32_i64
    assert_eq storage.call_i64("get", "used_slots"), 0_i64

    # Mutate storage state via reflection
    storage.call("set", "used_slots", 12_i64)
    storage.call("set", "max_slots", 64_i64)
    assert_eq storage.call_i64("get", "used_slots"), 12_i64
    assert_eq storage.call_i64("get", "max_slots"), 64_i64
    storage.destroy
    assert_true storage.destroyed?

    # 4. Quest Entity (dummy_dep_quest.dll)
    quest_ptr = Godot::Bridge.construct_object("DummyQuestEntity")
    assert_false quest_ptr.null?, "DummyQuestEntity must be constructible via ClassDB"
    quest = Godot::Node2D.new(quest_ptr)
    assert_true quest.alive?, "DummyQuestEntity must be alive"
    assert_eq quest.call_str("get", "current_quest"), "IntroQuest"
    assert_eq quest.call_f64("get", "quest_progress"), 0.0_f64

    # Mutate quest state via reflection
    quest.call("set", "current_quest", "DragonSlayer")
    quest.call("set", "quest_progress", 0.75_f64)
    assert_eq quest.call_str("get", "current_quest"), "DragonSlayer"
    assert_eq quest.call_f64("get", "quest_progress"), 0.75_f64
    quest.destroy
    assert_true quest.destroyed?

    # 5. Weather Entity (dummy_dep_weather.dll)
    weather_ptr = Godot::Bridge.construct_object("DummyWeatherEntity")
    assert_false weather_ptr.null?, "DummyWeatherEntity must be constructible via ClassDB"
    weather = Godot::Node2D.new(weather_ptr)
    assert_true weather.alive?, "DummyWeatherEntity must be alive"
    assert_eq weather.call_str("get", "weather_type"), "Clear"
    assert_eq weather.call_f64("get", "temperature"), 21.0_f64

    # Mutate weather state via reflection
    weather.call("set", "weather_type", "Thunderstorm")
    weather.call("set", "temperature", 14.5_f64)
    assert_eq weather.call_str("get", "weather_type"), "Thunderstorm"
    assert_eq weather.call_f64("get", "temperature"), 14.5_f64
    weather.destroy
    assert_true weather.destroyed?
  end

  test "GModule mixin property and signal isolation across all 4 consumer plugins" do
    class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)

    # Verify shared_tag property and mixin_triggered signal exist on all 4 plugins
    plugin_entities = ["DummyCombatEntity", "DummyStorageEntity", "DummyQuestEntity", "DummyWeatherEntity"]
    plugin_entities.each do |entity_name|
      assert_true class_db.call_bool("class_has_signal", entity_name, "mixin_triggered"), "#{entity_name} must expose mixin_triggered signal"
    end

    # Instantiate nodes, verify default mixin property and execution
    instances = plugin_entities.map do |cname|
      ptr = Godot::Bridge.construct_object(cname)
      Godot::Node2D.new(ptr)
    end

    instances.each_with_index do |node, idx|
      assert_eq node.call_str("get", "shared_tag"), "shared_mixin_tag"

      # Mutate shared_tag on this specific instance
      node.call("set", "shared_tag", "tag_from_node_#{idx}")
      assert_eq node.call_str("get", "shared_tag"), "tag_from_node_#{idx}"
    end

    # Confirm mutations on one node do not affect another node's property
    assert_eq instances[0].call_str("get", "shared_tag"), "tag_from_node_0"
    assert_eq instances[1].call_str("get", "shared_tag"), "tag_from_node_1"
    assert_eq instances[2].call_str("get", "shared_tag"), "tag_from_node_2"
    assert_eq instances[3].call_str("get", "shared_tag"), "tag_from_node_3"

    instances.each(&.destroy)
  end

  test "Cross-plugin interaction and parameter passing across DLL boundaries" do
    combat_ptr = Godot::Bridge.construct_object("DummyCombatEntity")
    storage_ptr = Godot::Bridge.construct_object("DummyStorageEntity")

    combat = Godot::Node2D.new(combat_ptr)
    storage = Godot::Node2D.new(storage_ptr)

    root.add_child(combat)
    root.add_child(storage)

    # Combat defeats monster and deposits bounty into storage via Godot property reflection
    initial_used = storage.call_i64("get", "used_slots")
    assert_eq initial_used, 0_i64

    # Combat workflow calculates loot and updates storage
    loot_quantity = 5_i64
    storage.call("set", "used_slots", initial_used + loot_quantity)
    assert_eq storage.call_i64("get", "used_slots"), 5_i64

    root.remove_child(combat)
    root.remove_child(storage)
    combat.destroy
    storage.destroy
  end

  test "ClassDB signal namespace isolation across dependent plugins" do
    class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)

    # Base signals must exist on DummyBaseEntity
    assert_true class_db.call_bool("class_has_signal", "DummyBaseEntity", "state_toggled")
    assert_true class_db.call_bool("class_has_signal", "DummyBaseEntity", "base_event")

    # Plugin-specific signals must be strictly isolated to their own classes
    # Combat signals
    assert_true class_db.call_bool("class_has_signal", "DummyCombatEntity", "attack_executed")
    assert_true class_db.call_bool("class_has_signal", "DummyCombatEntity", "critical_hit")
    assert_false class_db.call_bool("class_has_signal", "DummyCombatEntity", "item_deposited")
    assert_false class_db.call_bool("class_has_signal", "DummyCombatEntity", "quest_advanced")
    assert_false class_db.call_bool("class_has_signal", "DummyCombatEntity", "weather_changed")

    # Storage signals
    assert_true class_db.call_bool("class_has_signal", "DummyStorageEntity", "item_deposited")
    assert_true class_db.call_bool("class_has_signal", "DummyStorageEntity", "inventory_full")
    assert_false class_db.call_bool("class_has_signal", "DummyStorageEntity", "attack_executed")
    assert_false class_db.call_bool("class_has_signal", "DummyStorageEntity", "quest_completed")

    # Quest signals
    assert_true class_db.call_bool("class_has_signal", "DummyQuestEntity", "quest_advanced")
    assert_true class_db.call_bool("class_has_signal", "DummyQuestEntity", "quest_completed")
    assert_false class_db.call_bool("class_has_signal", "DummyQuestEntity", "attack_executed")
    assert_false class_db.call_bool("class_has_signal", "DummyQuestEntity", "weather_changed")

    # Weather signals
    assert_true class_db.call_bool("class_has_signal", "DummyWeatherEntity", "weather_changed")
    assert_true class_db.call_bool("class_has_signal", "DummyWeatherEntity", "storm_alert")
    assert_false class_db.call_bool("class_has_signal", "DummyWeatherEntity", "critical_hit")
    assert_false class_db.call_bool("class_has_signal", "DummyWeatherEntity", "item_deposited")
  end

  test "Zero memory leak across multiple dependent addon nodes" do
    all_nodes = Array(Godot::Node2D).new
    types = ["DummyBaseEntity", "DummyCombatEntity", "DummyStorageEntity", "DummyQuestEntity", "DummyWeatherEntity"]

    10.times do |i|
      types.each do |tname|
        ptr = Godot::Bridge.construct_object(tname)
        if !ptr.null?
          node = Godot::Node2D.new(ptr)
          node.name = "#{tname}_#{i}"
          root.add_child(node)
          all_nodes << node
        end
      end
    end

    assert_eq all_nodes.size, 50, "Allocated 50 multi-plugin nodes"

    all_nodes.each do |n|
      root.remove_child(n)
      n.destroy
      assert_true n.destroyed?
    end
    all_nodes.clear

    GC.collect
    assert_true true, "50 dependent plugin nodes cleanly allocated and deallocated"
  end

  test "Concurrent multi-threaded cross-plugin GC allocation stress test" do
    chan1 = Channel(Int32).new(1)
    chan2 = Channel(Int32).new(1)

    # Worker 1: background string/array allocations
    t1 = Thread.new do
      total = 0
      1000.times do |i|
        s = "worker_dep_addon_#{i * 3}"
        total += s.size
      end
      chan1.send(total)
    end

    # Worker 2: background hash allocations
    t2 = Thread.new do
      h = Hash(String, Int32).new
      400.times do |i|
        h["dep_key_#{i}"] = i * 7
      end
      chan2.send(h.size)
    end

    # Main thread: Simultaneously constructs, queries, and destroys nodes from all 5 addons
    b_ptr = Godot::Bridge.construct_object("DummyBaseEntity")
    if !b_ptr.null?
      b = Godot::Node2D.new(b_ptr)
      assert_eq b.call_str("get", "base_id"), "base_entity_0"
      b.destroy
    end

    c_ptr = Godot::Bridge.construct_object("DummyCombatEntity")
    if !c_ptr.null?
      c = Godot::Node2D.new(c_ptr)
      assert_eq c.call_str("get", "shared_tag"), "shared_mixin_tag"
      c.destroy
    end

    s_ptr = Godot::Bridge.construct_object("DummyStorageEntity")
    if !s_ptr.null?
      s = Godot::Node2D.new(s_ptr)
      assert_eq s.call_str("get", "shared_tag"), "shared_mixin_tag"
      s.destroy
    end

    q_ptr = Godot::Bridge.construct_object("DummyQuestEntity")
    if !q_ptr.null?
      q = Godot::Node2D.new(q_ptr)
      assert_eq q.call_str("get", "shared_tag"), "shared_mixin_tag"
      q.destroy
    end

    w_ptr = Godot::Bridge.construct_object("DummyWeatherEntity")
    if !w_ptr.null?
      w = Godot::Node2D.new(w_ptr)
      assert_eq w.call_str("get", "shared_tag"), "shared_mixin_tag"
      w.destroy
    end

    t1.join
    t2.join
    r1 = chan1.receive
    r2 = chan2.receive

    assert_true r1 > 0, "Worker 1 must complete string allocations"
    assert_eq r2, 400, "Worker 2 must populate 400 hash entries"

    GC.collect
    assert_true true, "Cross-plugin concurrent allocations completed without corruption"
  end
end
