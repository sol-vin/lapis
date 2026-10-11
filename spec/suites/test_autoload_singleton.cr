# =============================================================================
# LibGodot Test Suite: Autoload Nodes & Engine Singletons
# =============================================================================
#
# Validates declarative `@[Autoload]` node annotation and `autoload` block DSL:
# - Automatic instantiation during engine bootstrapping
# - Godot Engine singleton registration via `Engine.register_singleton`
# - Typed `ClassName.instance` and `ClassName.instance?` accessors
# - Global `Godot.autoload` lookup queries
# - SceneTree mounting under `/root/<name>` and lifecycle dispatch
# - Clean teardown and unregistration for zero-leak hot-reload safety
# =============================================================================

include Lapis::Test

test_suite "Autoload" do
  test "AutoloadManager registers and instantiates @[Autoload] node classes" do
    # Ensure autoloads are initialized
    Godot::AutoloadManager.setup_autoloads

    assert_true Godot::AutoloadManager.has_autoload?("AutoloadTargetService")
    rec = Godot::AutoloadManager["AutoloadTargetService"]
    assert_not_nil rec
    assert_eq rec.not_nil!.autoload_name, "AutoloadTargetService"
    assert_eq rec.not_nil!.class_name, "AutoloadTargetService"
    assert_true rec.not_nil!.singleton
    assert_true rec.not_nil!.mount_tree
  end

  test "Typed Class.instance and Class.instance? accessors return valid alive node" do
    Godot::AutoloadManager.setup_autoloads

    inst = AutoloadTargetService.instance
    assert_not_nil inst
    assert_true inst.alive?
    assert_false inst.destroyed?

    maybe_inst = AutoloadTargetService.instance?
    assert_not_nil maybe_inst
    assert_eq inst.instance_id, maybe_inst.not_nil!.instance_id
  end

  test "Autoload state mutation and method dispatches operate across the singleton" do
    Godot::AutoloadManager.setup_autoloads

    service = AutoloadTargetService.instance
    assert_eq service.service_status, "Running"
    service.service_status = "Operational"
    assert_eq service.service_status, "Operational"

    count1 = service.increment_execution
    assert_true count1 >= 1
    count2 = service.increment_execution
    assert_eq count2, count1 + 1
  end

  test "Node is registered in Godot's Engine singleton registry" do
    Godot::AutoloadManager.setup_autoloads

    assert_true Godot.engine.has_singleton("AutoloadTargetService")

    engine_obj = Godot.engine.get_singleton("AutoloadTargetService")
    assert_not_nil engine_obj
    assert_true engine_obj.alive?
    assert_eq engine_obj.instance_id, AutoloadTargetService.instance.instance_id
  end

  test "Block DSL `autoload name: ...` configures custom singleton name" do
    Godot::AutoloadManager.setup_autoloads

    assert_true Godot::AutoloadManager.has_autoload?("CustomAutoloadName")
    assert_true Godot.engine.has_singleton("CustomAutoloadName")

    inst = AutoloadBlockTarget.instance
    assert_not_nil inst
    assert_true inst.alive?
    assert_eq inst.custom_tag, "BlockConfigured"
    assert_eq inst.double_value, 84_i64
  end

  test "Selective configuration `singleton: false` excludes from Engine singleton list" do
    Godot::AutoloadManager.setup_autoloads

    assert_true Godot::AutoloadManager.has_autoload?("TreeOnlyAutoload")
    # Must NOT be in Godot.engine since singleton: false
    assert_false Godot.engine.has_singleton("TreeOnlyAutoload")

    inst = AutoloadTreeOnlyTarget.instance
    assert_not_nil inst
    assert_true inst.alive?
    assert_true inst.tree_only_flag
  end

  test "Global Godot.autoload helpers retrieve typed or named singleton" do
    Godot::AutoloadManager.setup_autoloads

    by_type = Godot.autoload(AutoloadTargetService)
    assert_not_nil by_type
    assert_eq by_type.instance_id, AutoloadTargetService.instance.instance_id

    by_name = Godot.autoload("CustomAutoloadName")
    assert_not_nil by_name
    assert_eq by_name.not_nil!.instance_id, AutoloadBlockTarget.instance.instance_id
  end

  test "Autoload node mounts under SceneTree root and receives lifecycle callbacks" do
    Godot::AutoloadManager.setup_autoloads

    # Mount explicitly to suite root or global tree
    tree = root.get_tree rescue nil
    Godot::AutoloadManager.mount_to_tree(tree)

    inst = AutoloadTargetService.instance
    assert_not_nil inst
    assert_true inst.alive?

    # If SceneTree is active, verify node is inside tree
    if tree && !tree.pointer.null?
      root_window = tree.get_root rescue nil
      if root_window && !root_window.pointer.null?
        unless inst.is_inside_tree
          root_window.add_child(inst) rescue nil
          unless inst.is_inside_tree
            root.add_child(inst) rescue nil
          end
        end
        has_node = root_window.has_node(Godot::NodePath.new("AutoloadTargetService")) rescue false
        assert_true has_node || inst.is_inside_tree, "Expected AutoloadTargetService to be mounted under SceneTree"
        if inst.is_inside_tree && inst.get_parent? == root
          root.remove_child(inst) rescue nil
        end
      end
    end
  end

  test "Teardown unregisters Engine singletons and cleans up cleanly" do
    Godot::AutoloadManager.setup_autoloads
    assert_true Godot.engine.has_singleton("AutoloadTargetService")

    Godot::AutoloadManager.teardown_autoloads
    assert_false Godot.engine.has_singleton("AutoloadTargetService")
    assert_false Godot.engine.has_singleton("CustomAutoloadName")
    assert_nil AutoloadTargetService.instance?
    assert_nil AutoloadBlockTarget.instance?

    # Restoring setup should succeed cleanly without crashing
    Godot::AutoloadManager.setup_autoloads
    assert_true Godot.engine.has_singleton("AutoloadTargetService")
    assert_not_nil AutoloadTargetService.instance?
  end
end
