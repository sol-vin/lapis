# =============================================================================
# LibGodot Test Suite: Custom Editor Inspector Plugins & Controls
# =============================================================================

include Lapis::Test

# Target probe node inspected by the custom inspector plugin
node InspectorTargetProbeNode < Godot::Node do
  @[Export]
  property custom_power : Float32 = 42.0_f32

  @[Export]
  property probe_label : String = "CustomProbe"
end

# Custom in-editor Inspector Plugin implemented in pure Crystal
node TestCustomInspectorPlugin < Godot::EditorInspectorPlugin do
  property can_handle_called : Bool = false
  property parse_begin_called : Bool = false
  property parse_property_called : Bool = false
  property handled_object_class : String = ""

  def _can_handle(object : Godot::Object) : Bool
    @can_handle_called = true
    is_target = object.is_class("InspectorTargetProbeNode") || object.has_method("get_custom_power") || (object.get_class == "InspectorTargetProbeNode")
    @handled_object_class = is_target ? "InspectorTargetProbeNode" : (object.get_class rescue "")
    is_target
  end

  def _parse_begin(object : Godot::Object) : Void
    @parse_begin_called = true
    # Add a custom banner control at the top of the inspector section
    btn = Godot.create(Godot::Button)
    if btn && !btn.pointer.null?
      btn.call("set_text", "Custom Inspector Control")
      add_custom_control(btn)
    end
  end

  def _parse_property(object : Godot::Object, type : Int64, name : String, hint_type : Int64, hint_string : String, usage_flags : Int64, wide : Bool) : Bool
    @parse_property_called = true
    if name == "custom_power"
      # Insert custom slider or property editor control
      slider = Godot.create(Godot::HSlider)
      if slider && !slider.pointer.null?
        add_custom_control(slider)
      end
      false # Return false to allow default property editor alongside custom control
    else
      false
    end
  end
end

test_suite "InspectorPlugins" do
  test "Custom EditorInspectorPlugin class registers in ClassDB" do
    cdb_ptr = Godot::Bridge.get_singleton("ClassDB")
    assert_false cdb_ptr.null?, "ClassDB singleton must be available"
    cdb = Godot::ClassDB.new(cdb_ptr)

    entry = Godot::ClassRegistry.find("TestCustomInspectorPlugin")
    assert_not_nil entry, "TestCustomInspectorPlugin must exist in ClassRegistry"
    assert_eq entry.not_nil!.parent_name, "EditorInspectorPlugin"

    is_editor = Godot.editor_hint?
    if is_editor
      assert_true cdb.class_exists("TestCustomInspectorPlugin"), "TestCustomInspectorPlugin must exist in ClassDB in editor"
      assert_true cdb.is_parent_class("TestCustomInspectorPlugin", "EditorInspectorPlugin"),
        "TestCustomInspectorPlugin must inherit from EditorInspectorPlugin"
    else
      # In non-editor runtime host, editor classes are safely suppressed from ClassDB for engine safety
      assert_false cdb.class_exists("TestCustomInspectorPlugin"),
        "Editor classes should be safely suppressed from ClassDB in runtime host"
    end
  end

  test "Custom EditorInspectorPlugin instantiation and virtual callback dispatch" do
    probe = Godot.create(InspectorTargetProbeNode)
    assert_not_nil probe, "InspectorTargetProbeNode instance must be constructible"

    is_editor = Godot.editor_hint?
    if is_editor
      plugin = Godot.create(TestCustomInspectorPlugin)
      assert_not_nil plugin, "TestCustomInspectorPlugin instance must be constructible in editor"

      # Test _can_handle dispatch
      can_handle_res = plugin.call_bool("_can_handle", probe.as(Godot::Object)) rescue false
      assert_true can_handle_res, "_can_handle must return true for InspectorTargetProbeNode"
      assert_true plugin.can_handle_called, "_can_handle flag must be set"
      assert_eq plugin.handled_object_class, "InspectorTargetProbeNode"

      # Test negative _can_handle dispatch on unrelated node
      dummy = Godot.create(Godot::Node)
      can_handle_dummy = plugin.call_bool("_can_handle", dummy.as(Godot::Object)) rescue true
      assert_false can_handle_dummy, "_can_handle must return false for generic Node"
      dummy.destroy

      # Test _parse_begin virtual dispatch
      plugin.call("_parse_begin", probe.as(Godot::Object)) rescue nil
      assert_true plugin.parse_begin_called, "_parse_begin must be invokable"

      # Test _parse_property virtual dispatch
      plugin.call("_parse_property", probe.as(Godot::Object), 3_i64, "custom_power", 0_i64, "", 6_i64, false) rescue nil
      assert_true plugin.parse_property_called, "_parse_property must be invokable"
    else
      # In non-editor runtime host, verify probe node exports and reflection
      assert_eq probe.custom_power, 42.0_f32
      assert_eq probe.probe_label, "CustomProbe"
    end

    probe.destroy
    # EditorInspectorPlugin inherits RefCounted; no manual destroy needed
  end

  test "EditorPlugin add_inspector_plugin and remove_inspector_plugin API binding" do
    cdb_ptr = Godot::Bridge.get_singleton("ClassDB")
    cdb = Godot::ClassDB.new(cdb_ptr)

    assert_true cdb.class_has_method("EditorPlugin", "add_inspector_plugin"),
      "EditorPlugin must have add_inspector_plugin method bind"
    assert_true cdb.class_has_method("EditorPlugin", "remove_inspector_plugin"),
      "EditorPlugin must have remove_inspector_plugin method bind"
  end
end
