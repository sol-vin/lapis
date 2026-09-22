# =============================================================================
# LibGodot Test Suite: UndoRedo Action Management, Commit & State History
# Replicating godot's test_undo_redo.cpp
# =============================================================================

include Lapis::Test

test_undo_redo "UndoRedo action creation, property changes, and commit lifecycle" do
  ur = Godot.create(Godot::UndoRedo)
  target = Godot.create(Godot::Node2D)
  target.position = Godot::Vector2.new(0.0_f32, 0.0_f32)

  assert_false ur.has_undo
  assert_false ur.has_redo

  # 1. Create action and register do/undo properties
  ur.create_action("MoveTarget", Godot::UndoRedo::MergeMode::MergeDisable.to_i64, false)
  ur.call("add_do_property", target, "position", Godot::Vector2.new(150.0_f32, 250.0_f32))
  ur.call("add_undo_property", target, "position", Godot::Vector2.new(0.0_f32, 0.0_f32))

  # 2. Commit action (execute: true applies the 'do' state)
  ur.commit_action(true)

  assert_approx_eq target.position.x, 150.0_f32, 0.01, "Target X position must reflect do_property"
  assert_approx_eq target.position.y, 250.0_f32, 0.01, "Target Y position must reflect do_property"
  assert_true ur.has_undo, "UndoRedo must have an undo action available"
  assert_false ur.has_redo, "UndoRedo must NOT have redo available immediately after commit"

  # 3. Perform Undo
  undo_success = ur.undo
  assert_true undo_success, "Undo execution must return true"
  assert_approx_eq target.position.x, 0.0_f32, 0.01, "Position X must revert to undo_property"
  assert_approx_eq target.position.y, 0.0_f32, 0.01, "Position Y must revert to undo_property"
  assert_false ur.has_undo, "Undo should be exhausted"
  assert_true ur.has_redo, "Redo action must now be available"

  # 4. Perform Redo
  redo_success = ur.redo_val
  assert_true redo_success, "Redo execution must return true"
  assert_approx_eq target.position.x, 150.0_f32, 0.01, "Position X must re-apply do_property"
  assert_approx_eq target.position.y, 250.0_f32, 0.01, "Position Y must re-apply do_property"
  assert_true ur.has_undo
  assert_false ur.has_redo

  # 5. Clear history
  ur.clear_history(false)
  assert_false ur.has_undo
  assert_false ur.has_redo

  target.destroy
  ur.destroy
end
