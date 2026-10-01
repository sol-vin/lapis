require "spec"
require "../src/editor/debugger/crystal_debugger_plugin"

describe "Godot EditorDebuggerPlugin Direct Hooks" do
  describe "Virtual Method Discovery" do
    it "advertises support for all engine debugger virtual callbacks" do
      # All required EditorDebuggerPlugin virtual methods
      methods = [
        "_has_capture",
        "_capture",
        "_setup_session",
        "_breakpoint_set_in_tree",
        "_breakpoints_cleared_in_tree",
        "_goto_script_line"
      ]

      methods.each do |m|
        Godot::CrystalDebuggerPlugin._godot_has_virtual_method(m).should be_true, "Missing virtual hook: #{m}"
        # Test without leading underscore
        Godot::CrystalDebuggerPlugin._godot_has_virtual_method(m.lchop('_')).should be_true, "Missing virtual hook without underscore: #{m}"
      end

      # Non-existent method should return false
      Godot::CrystalDebuggerPlugin._godot_has_virtual_method("_unknown_debugger_method").should be_false
    end
  end

  describe "Message Capture Protocols" do
    it "handles capture filters for crystal_debugger, lapis, and godot prefixes" do
      plugin = Godot::CrystalDebuggerPlugin.new

      # Test direct handle_capture for ready and role
      plugin.handle_capture("crystal_debugger:ready:1234:Server", 0).should be_true
      plugin.handle_capture("lapis:ready:5678:Client", 0).should be_true
      plugin.handle_capture("crystal_debugger:role:1234:Server", 0).should be_true
      plugin.handle_capture("lapis:role:5678:Client 1", 0).should be_true

      # Test forensics and fault notifications
      plugin.handle_capture("lapis:fault:0x140023450", 0).should be_true
      plugin.handle_capture("godot:fault:0x140089abc", 0).should be_true
      plugin.handle_capture("lapis:dead_pointer:987654321:Player", 0).should be_true
      plugin.handle_capture("lapis:stale_vtable:0x1402a1000", 0).should be_true

      # Unknown message should return false
      plugin.handle_capture("unrecognized_prefix:action", 0).should be_false

      plugin.cleanup
    end
  end

  describe "Breakpoint Index & Path Harmonization" do
    it "correctly manages breakpoint file paths and 1-based line conversion" do
      plugin = Godot::CrystalDebuggerPlugin.new

      # Simulate setting breakpoint via gutter click on line 42 (1-based from editor)
      plugin.handle_breakpoint_toggle("res://src/player.cr", 42, true)
      plugin.active_breakpoints.has_key?("res://src/player.cr").should be_true
      plugin.active_breakpoints["res://src/player.cr"].includes?(42).should be_true

      # Toggle off
      plugin.handle_breakpoint_toggle("res://src/player.cr", 42, false)
      plugin.active_breakpoints["res://src/player.cr"].includes?(42).should be_false

      # Clear all
      plugin.handle_breakpoint_toggle("res://src/player.cr", 10, true)
      plugin.handle_breakpoint_toggle("res://src/main.cr", 20, true)
      plugin.handle_breakpoints_cleared
      plugin.active_breakpoints.empty?.should be_true

      plugin.cleanup
    end
  end
end
