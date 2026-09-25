# =============================================================================
# LibGodot Test Suite: Editor Signal Reflection & Dual-Identity Safety
# =============================================================================

include Lapis::Test

# Probe node demonstrating parameterless and multi-argument signals
node EditorSignalTargetNode < Godot::Node do
  signal action_triggered
  signal score_updated(score : Int32, multiplier : Float32)
  signal player_tagged(tagger_name : String, is_leader : Bool)

  @[Export]
  property label : String = "SignalTarget"

  def trigger_all : Void
    emit_action_triggered
    emit_score_updated(100, 1.5_f32)
    emit_player_tagged("Hero", true)
  end
end

{% if flag?(:release) %}
  test_suite "EditorSignals" do
    test "ClassRegistry signal metadata registration" do
      entry = Godot::ClassRegistry.find("EditorSignalTargetNode")
      assert_not_nil entry, "EditorSignalTargetNode must be registered in ClassRegistry"

      if e = entry
        assert_eq e.signals.size, 3, "Expected 3 registered signals"

        sig_names = e.signals.map(&.name)
        assert_true sig_names.includes?("action_triggered"), "Missing action_triggered signal"
        assert_true sig_names.includes?("score_updated"), "Missing score_updated signal"
        assert_true sig_names.includes?("player_tagged"), "Missing player_tagged signal"

        # Parameterless signal
        act_sig = e.signals.find { |s| s.name == "action_triggered" }.not_nil!
        assert_eq act_sig.args.size, 0, "action_triggered should have 0 arguments"

        # Multi-arg signal with types
        score_sig = e.signals.find { |s| s.name == "score_updated" }.not_nil!
        assert_eq score_sig.args.size, 2, "score_updated should have 2 arguments"
        assert_eq score_sig.args[0].name, "score"
        assert_eq score_sig.args[0].variant_type, 2 # INT
        assert_eq score_sig.args[1].name, "multiplier"
        assert_eq score_sig.args[1].variant_type, 3 # FLOAT

        # String and Bool signal
        tag_sig = e.signals.find { |s| s.name == "player_tagged" }.not_nil!
        assert_eq tag_sig.args.size, 2, "player_tagged should have 2 arguments"
        assert_eq tag_sig.args[0].name, "tagger_name"
        assert_eq tag_sig.args[0].variant_type, 4 # STRING
        assert_eq tag_sig.args[1].name, "is_leader"
        assert_eq tag_sig.args[1].variant_type, 1 # BOOL
      end
    end

    test "Template MainNode signal reflection" do
      # MainNode in template/ has signal initialized
      entry = Godot::ClassRegistry.find("MainNode")
      if e = entry
        assert_true e.signals.any? { |s| s.name == "initialized" }, "MainNode must declare 'initialized' signal in ClassRegistry"
      end
    end

    test "CrystalScript dual-identity reflection cleanly stripped in release mode" do
      class_db = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)
      assert_false class_db.call_bool("class_exists", "CrystalScript"), "CrystalScript must not be registered in release mode"
    end
  end
{% else %}
  test_suite "EditorSignals" do
    test "ClassRegistry signal metadata registration" do
      entry = Godot::ClassRegistry.find("EditorSignalTargetNode")
      assert_not_nil entry, "EditorSignalTargetNode must be registered in ClassRegistry"

      if e = entry
        assert_eq e.signals.size, 3, "Expected 3 registered signals"

        sig_names = e.signals.map(&.name)
        assert_true sig_names.includes?("action_triggered"), "Missing action_triggered signal"
        assert_true sig_names.includes?("score_updated"), "Missing score_updated signal"
        assert_true sig_names.includes?("player_tagged"), "Missing player_tagged signal"

        # Parameterless signal
        act_sig = e.signals.find { |s| s.name == "action_triggered" }.not_nil!
        assert_eq act_sig.args.size, 0, "action_triggered should have 0 arguments"

        # Multi-arg signal with types
        score_sig = e.signals.find { |s| s.name == "score_updated" }.not_nil!
        assert_eq score_sig.args.size, 2, "score_updated should have 2 arguments"
        assert_eq score_sig.args[0].name, "score"
        assert_eq score_sig.args[0].variant_type, 2 # INT
        assert_eq score_sig.args[1].name, "multiplier"
        assert_eq score_sig.args[1].variant_type, 3 # FLOAT

        # String and Bool signal
        tag_sig = e.signals.find { |s| s.name == "player_tagged" }.not_nil!
        assert_eq tag_sig.args.size, 2, "player_tagged should have 2 arguments"
        assert_eq tag_sig.args[0].name, "tagger_name"
        assert_eq tag_sig.args[0].variant_type, 4 # STRING
        assert_eq tag_sig.args[1].name, "is_leader"
        assert_eq tag_sig.args[1].variant_type, 1 # BOOL
      end
    end

    test "CrystalScript signal reflection MethodInfo schema compliance" do
      script = Godot.create(Godot::CrystalScript)
      assert_not_nil script, "CrystalScript instance must be created"

      if sc = script
        sc.script_class_name = "EditorSignalTargetNode"
        sc.sync_class_metadata

        assert_true sc.has_script_signal("action_triggered"), "Script should have action_triggered"
        assert_true sc.has_script_signal("score_updated"), "Script should have score_updated"
        assert_true sc.has_script_signal("player_tagged"), "Script should have player_tagged"
        assert_false sc.has_script_signal("nonexistent_signal"), "Script should not have nonexistent_signal"

        # Inspect signal definitions
        defs = sc.signal_defs
        assert_true defs.size >= 3, "signal_defs must contain at least 3 signals"

        act_sig = defs.find { |s| s.name == "action_triggered" }
        assert_not_nil act_sig
        assert_eq act_sig.not_nil!.args.size, 0

        score_sig = defs.find { |s| s.name == "score_updated" }
        assert_not_nil score_sig
        assert_eq score_sig.not_nil!.args.size, 2
        assert_eq score_sig.not_nil!.args[0].name, "score"
        assert_eq score_sig.not_nil!.args[0].variant_type, 2 # INT
        assert_eq score_sig.not_nil!.args[1].name, "multiplier"
        assert_eq score_sig.not_nil!.args[1].variant_type, 3 # FLOAT

        tag_sig = defs.find { |s| s.name == "player_tagged" }
        assert_not_nil tag_sig
        assert_eq tag_sig.not_nil!.args.size, 2
        assert_eq tag_sig.not_nil!.args[0].name, "tagger_name"
        assert_eq tag_sig.not_nil!.args[0].variant_type, 4 # STRING
        assert_eq tag_sig.not_nil!.args[1].name, "is_leader"
        assert_eq tag_sig.not_nil!.args[1].variant_type, 1 # BOOL

        # Verify virtual call return buffer does not crash
        sc.get_script_signal_list
        sc.get_script_property_list
      end
    end

    test "Virtual return buffer stack safety & zero leak verification" do
      script = Godot.create(Godot::CrystalScript)
      assert_not_nil script, "CrystalScript instance must be created"

      if sc = script
        sc.script_class_name = "EditorSignalTargetNode"
        sc.sync_class_metadata

        # Repeatedly query virtual signal list and property list to verify zero memory or object leaks
        assert_no_leak do
          100.times do
            sc.get_script_signal_list
            sc.get_script_property_list
          end
        end
      end
    end

    test "Dual-identity reflection simulation (connections_dialog.cpp parity)" do
      node = Godot.create(EditorSignalTargetNode)
      assert_not_nil node, "EditorSignalTargetNode instance must be created"

      if n = node
        entry = Godot::ClassRegistry.find("EditorSignalTargetNode")
        assert_not_nil entry, "EditorSignalTargetNode entry must be found"
        if e = entry
          script = Godot::ClassRegistry.get_or_load_script(e.script_path, e.class_name, e.parent_name, e.is_tool)
          assert_not_nil script, "Script must be loaded"
          if sc = script
            n.call("set_script", sc)
            script_obj = n.get_script
            assert_true !script_obj.null?, "Dual-identity script must be attached"

            # Simulate Godot Editor connections_dialog.cpp lines 1593-1610
            assert_true sc.signal_defs.size >= 3, "Editor connections dialog must receive signals"

            sc.signal_defs.each do |sdef|
              sig_name = sdef.name
              # Node and Script must agree on signal existence without crashing
              assert_true n.has_signal?(sig_name), "Node must report has_signal?(#{sig_name}) == true"
              assert_true sc.has_script_signal(sig_name), "Script must report has_script_signal(#{sig_name}) == true"
            end
          end
        end

        n.destroy
      end
    end

    test "Live signal emission and reception under dual-identity" do
      node = Godot.create(EditorSignalTargetNode)
      assert_not_nil node, "EditorSignalTargetNode instance must be created"

      if n = node
        if e = Godot::ClassRegistry.find("EditorSignalTargetNode")
          if sc = Godot::ClassRegistry.get_or_load_script(e.script_path, e.class_name, e.parent_name, e.is_tool)
            n.call("set_script", sc)
          end
        end

        action_received = false
        n.connect("action_triggered") do |_|
          action_received = true
        end

        score_received = 0
        multiplier_received = 0.0_f32
        n.connect("score_updated") do |args|
          score_received = args[0].as_i
          multiplier_received = args[1].as_f.to_f32
        end

        n.trigger_all

        assert_true action_received, "action_triggered signal listener must receive event"
        assert_eq score_received, 100, "score_updated listener must receive integer payload"
        assert_true (multiplier_received - 1.5_f32).abs < 0.001_f32, "score_updated listener must receive float payload"

        n.destroy
      end
    end

    test "Template MainNode signal reflection" do
      # MainNode in template/ has signal initialized
      entry = Godot::ClassRegistry.find("MainNode")
      if e = entry
        assert_true e.signals.any? { |s| s.name == "initialized" }, "MainNode must declare 'initialized' signal in ClassRegistry"
      end
    end
  end
{% end %}
