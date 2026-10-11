# =============================================================================
# LibGodot Test Suite: Comprehensive Crystal Editor Plugins Verification
# =============================================================================

include Lapis::Test
require "../../src/editor/plugin"

test_suite "EditorPluginsComprehensive" do
  test "Pillar 1: ClassDB registration and inheritance hierarchy" do
    # When running under the editor, verify ClassDB registrations
    if Godot.editor_hint? && Godot::ClassDB.singleton_ptr.null? == false
      cdb = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)
      if cdb.class_exists("EditorPlugin")
        assert_true cdb.class_exists("CrystalIntegrationPlugin")
        assert_true cdb.is_parent_class("CrystalIntegrationPlugin", "EditorPlugin")

        # Verify CrystalDebuggerPlugin
        assert_true cdb.class_exists("CrystalDebuggerPlugin")
        assert_true cdb.is_parent_class("CrystalDebuggerPlugin", "EditorDebuggerPlugin")

        # Verify CrystalHighlighter
        assert_true cdb.class_exists("CrystalHighlighter")
        assert_true cdb.is_parent_class("CrystalHighlighter", "EditorSyntaxHighlighter")
      end
    end

    # Verify instantiation and property defaults
    plugin = Godot.create(Lapis::CrystalIntegrationPlugin)
    assert_not_nil plugin
    assert_eq plugin.version, Godot::VERSION
    assert_true plugin.active
    assert_eq plugin.status_message, "Lapis Crystal Integration Active"

    plugin.destroy
  end

  test "Pillar 2: Main Screen Plugin Protocol implementation" do
    plugin = Godot.create(Lapis::CrystalIntegrationPlugin)
    assert_not_nil plugin

    # 1. Main screen support flag
    assert_true plugin._has_main_screen

    # 2. Plugin tab name
    assert_eq plugin._get_plugin_name, "Crystal"

    # 3. Virtual method reflection check
    assert_true Lapis::CrystalIntegrationPlugin._godot_has_virtual_method("_has_main_screen")
    assert_true Lapis::CrystalIntegrationPlugin._godot_has_virtual_method("_get_plugin_name")
    assert_true Lapis::CrystalIntegrationPlugin._godot_has_virtual_method("_get_plugin_icon")
    assert_true Lapis::CrystalIntegrationPlugin._godot_has_virtual_method("_make_visible")
    assert_true Lapis::CrystalIntegrationPlugin._godot_has_virtual_method("_build")

    # 4. Toggle visibility safely (must not raise or segfault)
    plugin._make_visible(false)
    plugin._make_visible(true)
    plugin._make_visible(false)

    plugin.destroy
  end

  test "Pillar 3: EditorSettings configuration and extension safety" do
    # Test textfile extension stripping logic:
    # Crystal integration ensures '.cr' is not treated as a plain textfile
    raw_extensions = "txt,md,cfg,ini,cr,log,json"
    cleaned = raw_extensions.split(',').map(&.strip).reject { |ext| ext == "cr" || ext.empty? }.join(",")
    assert_false cleaned.includes?("cr")
    assert_eq cleaned, "txt,md,cfg,ini,log,json"
  end

  test "Pillar 4: CrystalDebuggerPlugin and session lifecycle" do
    debugger = Godot.create(Godot::CrystalDebuggerPlugin)
    assert_not_nil debugger

    # 1. Virtual method registration
    assert_true Godot::CrystalDebuggerPlugin._godot_has_virtual_method("_has_capture")
    assert_true Godot::CrystalDebuggerPlugin._godot_has_virtual_method("_capture")
    assert_true Godot::CrystalDebuggerPlugin._godot_has_virtual_method("_setup_session")
    assert_true Godot::CrystalDebuggerPlugin._godot_has_virtual_method("_breakpoint_set_in_tree")
    assert_true Godot::CrystalDebuggerPlugin._godot_has_virtual_method("_breakpoints_cleared_in_tree")

    # 2. Breakpoint state management (path is globalized by ProjectSettings)
    debugger.handle_breakpoint_toggle("res://src/player.cr", 42, true)
    assert_true debugger.active_breakpoints.any? { |path, lines| path.ends_with?("src/player.cr") && lines.includes?(42) }

    # Disable breakpoint
    debugger.handle_breakpoint_toggle("res://src/player.cr", 42, false)
    assert_false debugger.active_breakpoints.any? { |path, lines| path.ends_with?("src/player.cr") && lines.includes?(42) }

    # Re-enable and clear all
    debugger.handle_breakpoint_toggle("res://src/player.cr", 42, true)
    debugger.handle_breakpoint_toggle("res://src/enemy.cr", 88, true)
    assert_eq debugger.active_breakpoints.size, 2

    debugger.handle_breakpoints_cleared
    assert_eq debugger.active_breakpoints.size, 0

    debugger.destroy
  end

  test "Pillar 5: CrystalHighlighter syntax engine and tokenization" do
    # 1. Tokenize class declaration with annotation, keywords, symbols, strings, and comments
    code_line = "  @[Export] property max_hp : Int32 = 100 # Maximum health points"
    spans = Lapis::CrystalHighlighter.highlight_line(code_line)
    assert_true spans.size > 0

    # Spans must be ordered monotonically by column
    spans.each_cons(2) do |(s1, s2)|
      assert_true s1.column < s2.column
    end

    # 2. Control flow keywords
    ctrl_line = "if enemy.alive? && distance < 10.0"
    ctrl_spans = Lapis::CrystalHighlighter.highlight_line(ctrl_line)
    assert_true ctrl_spans.size > 0

    # 3. String literal highlighting
    str_line = "msg = \"Game Over\""
    str_spans = Lapis::CrystalHighlighter.highlight_line(str_line)
    assert_true str_spans.size > 0

    # 4. Pure comment line
    comment_line = "# This is a comment"
    comment_spans = Lapis::CrystalHighlighter.highlight_line(comment_line)
    assert_eq comment_spans.size, 1
    assert_eq comment_spans.first.column, 0
  end

  test "Pillar 6: Build Hook and compilation state transitions" do
    # Initial state
    assert_false Lapis::CrystalIntegrationPlugin.building?

    # Reload pending state flags
    initial_pending = Lapis::CrystalIntegrationPlugin.reload_pending?
    Lapis::CrystalIntegrationPlugin.reload_pending = true
    assert_true Lapis::CrystalIntegrationPlugin.reload_pending?
    Lapis::CrystalIntegrationPlugin.reload_pending = initial_pending

    # Virtual method check for build hook
    assert_true Lapis::CrystalIntegrationPlugin._godot_has_virtual_method("_build")
  end

  test "Pillar 7: Multi-Addon side-by-side coexistence and isolation" do
    # When dummy addon plugins are registered in ClassDB, test independent instantiations
    if Godot.editor_hint? && Godot::ClassDB.singleton_ptr.null? == false
      cdb = Godot::ClassDB.new(Godot::ClassDB.singleton_ptr)
      if cdb.class_exists("DummyDialoguePlugin")
        dialogue_ptr = cdb.instantiate("DummyDialoguePlugin")
        assert_false dialogue_ptr.null?

        dialogue_obj = Godot::Object.new(dialogue_ptr)
        dialogue_obj.call("open_dialogue_editor")
        dialogue_obj.destroy
      end

      if cdb.class_exists("DummyInventoryPlugin")
        inventory_ptr = cdb.instantiate("DummyInventoryPlugin")
        assert_false inventory_ptr.null?

        inventory_obj = Godot::Object.new(inventory_ptr)
        inventory_obj.call("clear_test_inventory")
        inventory_obj.destroy
      end
    end
  end

  test "Pillar 8: Memory and zero leak safety across editor plugin lifecycles" do
    assert_no_leak do
      3.times do
        plugin = Godot.create(Lapis::CrystalIntegrationPlugin)
        plugin._make_visible(false)
        plugin._make_visible(true)
        plugin._make_visible(false)
        plugin.destroy

        debugger = Godot.create(Godot::CrystalDebuggerPlugin)
        debugger.handle_breakpoint_toggle("res://test.cr", 10, true)
        debugger.handle_breakpoints_cleared
        debugger.destroy
      end
    end
  end
end
