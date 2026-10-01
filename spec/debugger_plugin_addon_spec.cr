require "spec"
require "../src/editor/debugger/crystal_debugger_plugin"
require "../src/editor/debugger/session_controller"

describe "Addon Debugging & Context Mapping" do
  describe "Addon Registration & Module Discovery" do
    it "registers addons across active sessions" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)
      ctrl = Godot::DebuggerSessionController.new(0, dummy_session)
      plugin.register_session_controller(ctrl)

      plugin.register_addon("custom_physics", "custom_physics.dll")

      ctrl.driver.classifier.addon_modules.has_key?("custom_physics.dll").should be_true
      ctrl.driver.classifier.addon_modules["custom_physics.dll"].should eq("custom_physics")

      plugin.cleanup
    end

    it "handles lapis:addon capture messages to register runtime addon modules" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)
      ctrl = Godot::DebuggerSessionController.new(0, dummy_session)
      plugin.register_session_controller(ctrl)

      plugin.handle_capture("lapis:addon:magic_spells:spells_lib.dll", 0).should be_true
      ctrl.driver.classifier.addon_modules.has_key?("spells_lib.dll").should be_true
      ctrl.driver.classifier.addon_modules["spells_lib.dll"].should eq("magic_spells")

      plugin.cleanup
    end
  end

  describe "Addon Breakpoints & Source Localization" do
    it "sets breakpoints in addon source files under res://addons/" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)
      ctrl = Godot::DebuggerSessionController.new(0, dummy_session)
      plugin.register_session_controller(ctrl)

      addon_script = "res://addons/dialogue_node/src/dialogue_box.cr"
      plugin.handle_breakpoint_toggle(addon_script, 24, true)

      ctrl.driver.breakpoints.size.should eq(1)
      bp = ctrl.driver.breakpoints.values.first
      bp.file.should eq(addon_script)
      bp.line.should eq(24)

      plugin.handle_breakpoint_toggle(addon_script, 24, false)
      ctrl.driver.breakpoints.empty?.should be_true

      plugin.cleanup
    end
  end

  describe "Addon Context Classification in Execution Stop" do
    it "classifies stop frame in addon code as ContextDomain::Addon" do
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)
      ctrl = Godot::DebuggerSessionController.new(0, dummy_session)
      ctrl.debug_addon("inventory_system", "inventory_system.dll")

      # Simulate stop frame inside addon code
      stop_info = Godot::Debugger::StopInfo.new(
        reason: Godot::Debugger::StopReason::Breakpoint,
        thread_id: 1,
        frame: Godot::Debugger::StackFrame.new(
          0,
          "Inventory#add_item",
          "addons/inventory_system/src/inventory.cr",
          42,
          module_name: "inventory_system.dll",
          context: ctrl.driver.classifier.classify("addons/inventory_system/src/inventory.cr", "Inventory#add_item", "inventory_system.dll")
        )
      )

      ctrl.driver.on_stop.try(&.call(stop_info))

      ctrl.active_context.should_not be_nil
      if ctx = ctrl.active_context
        ctx.domain.should eq(Godot::Debugger::ContextDomain::Addon)
        ctx.addon_name.should eq("inventory_system")
        ctx.badge.should eq("[Context: Addon 'inventory_system']")
      end

      ctrl.cleanup
    end

    it "distinguishes between multiple isolated addons in the same project" do
      classifier = Godot::Debugger::ContextClassifier.new
      classifier.register_addon("audio_bus", "audio_bus.dll")
      classifier.register_addon("quest_log", "quest_log.dll")

      ctx_audio = classifier.classify("addons/audio_bus/mixer.cr", "Mixer#set_volume", "audio_bus.dll")
      ctx_audio.domain.should eq(Godot::Debugger::ContextDomain::Addon)
      ctx_audio.addon_name.should eq("audio_bus")

      ctx_quest = classifier.classify("addons/quest_log/journal.cr", "Journal#add_entry", "quest_log.dll")
      ctx_quest.domain.should eq(Godot::Debugger::ContextDomain::Addon)
      ctx_quest.addon_name.should eq("quest_log")
    end
  end
end
