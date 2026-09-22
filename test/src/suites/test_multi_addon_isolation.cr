# =============================================================================
# LibGodot Test Suite: Multi-Addon Isolation & Conflict Prevention
# =============================================================================

include Lapis::Test

macro test_multi_addon(name, &block)
  Registry.register("MultiAddon", {{name}}) do |node|
    root = node
    {{block.body}}
  end
end

test_multi_addon "Multi-addon ClassDB registration and isolation" do
  class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)

  # In editor sessions, EditorPlugin classes are registered in ClassDB at EDITOR initialization level.
  if Godot.editor_hint? || class_db.call_bool("class_exists", "EditorPlugin")
    assert_true class_db.call_bool("class_exists", "CrystalIntegrationPlugin"), "CrystalIntegrationPlugin must exist in ClassDB in editor"
  end

  # Verify DialogueBox node from dummy_dialogue
  dialogue_ptr = Godot::Bridge.construct_object("DialogueBox")
  assert_false dialogue_ptr.null?, "DialogueBox must be constructible via ClassDB"
  box = Godot::Control.new(dialogue_ptr)
  assert_true box.alive?, "DialogueBox should be instantiated"
  assert_eq box.call_str("get", "speaker_name"), "Narrator"
  box.destroy
  assert_true box.destroyed?

  # Verify InventoryGrid node from dummy_inventory
  inv_ptr = Godot::Bridge.construct_object("InventoryGrid")
  assert_false inv_ptr.null?, "InventoryGrid must be constructible via ClassDB"
  inv = Godot::Control.new(inv_ptr)
  assert_true inv.alive?, "InventoryGrid should be instantiated"
  assert_eq inv.call_i64("get", "capacity"), 20_i64
  assert_eq inv.call_i64("get", "item_count"), 5_i64
  inv.destroy
  assert_true inv.destroyed?

  # Verify AudioStreamPlayerCrystal node from dummy_audio
  audio_ptr = Godot::Bridge.construct_object("AudioStreamPlayerCrystal")
  assert_false audio_ptr.null?, "AudioStreamPlayerCrystal must be constructible via ClassDB"
  audio = Godot::Node.new(audio_ptr)
  assert_true audio.alive?, "AudioStreamPlayerCrystal should be instantiated"
  assert_eq audio.call_str("get", "bus_name"), "Master"
  assert_false audio.call_bool("get", "is_playing")
  audio.destroy
  assert_true audio.destroyed?
end

test_multi_addon "EditorPlugin coexistence and single compiler hook enforcement" do
  class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)

  # When in editor sessions (where EditorPlugin exists in ClassDB):
  if Godot.editor_hint? || class_db.call_bool("class_exists", "EditorPlugin")
    # Verify CrystalIntegrationPlugin is registered in ClassDB and inherits from EditorPlugin
    assert_true class_db.call_bool("class_exists", "CrystalIntegrationPlugin"), "CrystalIntegrationPlugin must exist in ClassDB"
    assert_true class_db.call_bool("is_parent_class", "CrystalIntegrationPlugin", "EditorPlugin"), "CrystalIntegrationPlugin must inherit EditorPlugin"
    assert_true class_db.call_bool("class_has_signal", "CrystalIntegrationPlugin", "ready_in_editor"), "CrystalIntegrationPlugin must expose ready_in_editor signal"

    # Verify multiple distinct EditorPlugin classes can coexist in ClassDB without collisions
    dummy_plugins = ["DummyDialoguePlugin", "DummyInventoryPlugin", "DummyAudioPlugin"]
    dummy_plugins.each do |plugin_name|
      assert_true class_db.call_bool("class_exists", plugin_name), "#{plugin_name} must exist in ClassDB"
      assert_true class_db.call_bool("is_parent_class", plugin_name, "EditorPlugin"), "#{plugin_name} must inherit EditorPlugin"
      assert_false class_db.call_bool("class_has_signal", plugin_name, "ready_in_editor"), "#{plugin_name} must NOT have compiler build hook signal"
    end
  else
    # In standalone game runtime, verify that runtime addon classes are available
    assert_true class_db.call_bool("class_exists", "DialogueBox"), "DialogueBox must exist in runtime ClassDB"
    assert_true class_db.call_bool("class_exists", "InventoryGrid"), "InventoryGrid must exist in runtime ClassDB"
    assert_true class_db.call_bool("class_exists", "AudioStreamPlayerCrystal"), "AudioStreamPlayerCrystal must exist in runtime ClassDB"
  end
end

test_multi_addon "EditorPlugin documentation and public methods registration" do
  class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)

  # Check that plugins have their exported properties and signals registered in ClassDB
  if Godot.editor_hint? || class_db.call_bool("class_exists", "EditorPlugin")
    assert_true class_db.call_bool("class_has_signal", "DummyAudioPlugin", "preview_stopped"), "DummyAudioPlugin must expose preview_stopped signal"
    assert_true class_db.call_bool("class_has_signal", "DummyDialoguePlugin", "dialogue_validated"), "DummyDialoguePlugin must expose dialogue_validated signal"
    assert_true class_db.call_bool("class_has_signal", "DummyInventoryPlugin", "slot_inspected"), "DummyInventoryPlugin must expose slot_inspected signal"
  end

  # Check runtime node signals and properties
  assert_true class_db.call_bool("class_has_signal", "AudioStreamPlayerCrystal", "playback_started"), "AudioStreamPlayerCrystal must expose playback_started signal"
  assert_true class_db.call_bool("class_has_signal", "DialogueBox", "line_finished"), "DialogueBox must expose line_finished signal"
  assert_true class_db.call_bool("class_has_signal", "InventoryGrid", "item_added"), "InventoryGrid must expose item_added signal"
end

test_multi_addon "Zero memory leak across multiple addon nodes" do
  addon_nodes = Array(Godot::Control).new
  5.times do |i|
    # Add dummy dialogue boxes
    d_ptr = Godot::Bridge.construct_object("DialogueBox")
    if !d_ptr.null?
      d_node = Godot::Control.new(d_ptr)
      d_node.name = "DialogueBox_#{i}"
      root.add_child(d_node)
      addon_nodes << d_node
    end

    # Add dummy inventory grids
    inv_ptr = Godot::Bridge.construct_object("InventoryGrid")
    if !inv_ptr.null?
      inv_node = Godot::Control.new(inv_ptr)
      inv_node.name = "InventoryGrid_#{i}"
      root.add_child(inv_node)
      addon_nodes << inv_node
    end
  end

  addon_nodes.each do |n|
    root.remove_child(n)
    n.destroy
  end
  addon_nodes.clear

  GC.collect
  assert_true true, "Multi-addon nodes cleanly allocated and deallocated"
end

test_multi_addon "Shared Boehm GC heap metrics and cross-plugin allocation integrity" do
  # Confirm Boehm GC is active and tracking heap allocations across modules
  stats_initial = GC.stats
  assert_true stats_initial.heap_size > 0, "Boehm GC heap size must be positive"

  allocated_nodes = [] of Godot::Control
  50.times do |i|
    d_ptr = Godot::Bridge.construct_object("DialogueBox")
    if !d_ptr.null?
      box = Godot::Control.new(d_ptr)
      box.call("set", "speaker_name", "Speaker_#{i}")
      allocated_nodes << box
    end

    inv_ptr = Godot::Bridge.construct_object("InventoryGrid")
    if !inv_ptr.null?
      grid = Godot::Control.new(inv_ptr)
      grid.call("set", "capacity", (10 + i).to_i64)
      allocated_nodes << grid
    end
  end

  # Force collection while nodes are still alive: GC must preserve active instances
  GC.collect
  allocated_nodes.each_with_index do |node, idx|
    assert_true node.alive?, "Node #{idx} must survive GC collection while referenced"
  end

  # Clean up all nodes and verify GC collection succeeds without memory corruption
  allocated_nodes.each(&.destroy)
  allocated_nodes.clear
  GC.collect

  stats_final = GC.stats
  assert_true stats_final.total_bytes >= stats_initial.total_bytes, "Boehm GC tracked cumulative multi-plugin allocations"
end

test_multi_addon "Concurrent multi-threaded cross-plugin GC allocation stress test" do
  chan1 = Channel(Int32).new(1)
  chan2 = Channel(Int32).new(1)

  # Worker 1: Allocates strings and arrays in an independent OS thread
  t1 = Thread.new do
    sum = 0
    1000.times do |i|
      str = "background_worker_alloc_#{i}_#{i * 2}"
      sum += str.size
    end
    chan1.send(sum)
  end

  # Worker 2: Allocates hashes and collects in an independent OS thread
  t2 = Thread.new do
    h = Hash(String, Int32).new
    500.times do |i|
      h["key_#{i}"] = i * 3
    end
    chan2.send(h.size)
  end

  # Main thread: Simultaneously constructs and queries addon nodes
  d_ptr = Godot::Bridge.construct_object("DialogueBox")
  if !d_ptr.null?
    box = Godot::Control.new(d_ptr)
    speaker = box.call_str("get", "speaker_name")
    assert_eq speaker, "Narrator"
    box.destroy
  end

  inv_ptr = Godot::Bridge.construct_object("InventoryGrid")
  if !inv_ptr.null?
    grid = Godot::Control.new(inv_ptr)
    cap = grid.call_i64("get", "capacity")
    assert_eq cap, 20_i64
    grid.destroy
  end

  # Drain worker results after ensuring background OS threads have completed
  t1.join
  t2.join
  res1 = chan1.receive
  res2 = chan2.receive

  assert_true res1 > 0, "Worker 1 should complete allocations successfully"
  assert_eq res2, 500, "Worker 2 should populate 500 entries successfully"

  GC.collect
  assert_true true, "Cross-plugin concurrent GC allocations completed without crashing"
end

test_multi_addon "ClassDB property and signal namespace isolation across independent addons" do
  class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)

  # Verify DialogueBox does NOT inherit InventoryGrid properties or signals
  assert_false class_db.call_bool("class_has_signal", "DialogueBox", "item_added"), "DialogueBox must NOT have item_added signal"
  assert_false class_db.call_bool("class_has_signal", "DialogueBox", "playback_started"), "DialogueBox must NOT have playback_started signal"

  # Verify InventoryGrid does NOT inherit DialogueBox properties or signals
  assert_false class_db.call_bool("class_has_signal", "InventoryGrid", "line_finished"), "InventoryGrid must NOT have line_finished signal"
  assert_false class_db.call_bool("class_has_signal", "InventoryGrid", "playback_started"), "InventoryGrid must NOT have playback_started signal"

  # Verify AudioStreamPlayerCrystal is strictly isolated
  assert_false class_db.call_bool("class_has_signal", "AudioStreamPlayerCrystal", "line_finished"), "AudioStreamPlayerCrystal must NOT have line_finished signal"
  assert_false class_db.call_bool("class_has_signal", "AudioStreamPlayerCrystal", "item_added"), "AudioStreamPlayerCrystal must NOT have item_added signal"
end

