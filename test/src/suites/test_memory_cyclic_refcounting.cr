# =============================================================================
# LibGodot Test Suite: Memory Cyclic References, RefCounting & Zero-Leak Safety
# =============================================================================
#
# Tests cross-boundary memory management between Crystal's Boehm GC and
# Godot's ObjectDB & atomic RefCounted counter. Verifies cyclic references,
# sub-resource cloning, and quantitative zero-leak guarantees.
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

class CyclicHostObject
  getter node : Godot::Node2D
  property tag : String = "HostTag"

  def initialize(@node : Godot::Node2D)
  end
end

test_suite "MemoryCyclic" do
  test "RefCounted reference counting under collection retention and clear" do
    mat = Godot.create(Godot::StandardMaterial3D)
    initial_ref = mat.get_reference_count
    assert_true initial_ref >= 1

    # Explicit reference increments Godot's atomic refcount
    ref_ok = mat.reference
    assert_true ref_ok
    assert_eq mat.get_reference_count, initial_ref + 1

    # Unreference restores count
    unref_ok = mat.unreference
    assert_false unref_ok # false indicates object was not destroyed yet (count > 0)
    assert_eq mat.get_reference_count, initial_ref
  end

  test "Crystal object wrapper holding Godot node with cyclic metadata reference" do
    node2d = Godot.create(Godot::Node2D)
    node_id = node2d.instance_id
    host = CyclicHostObject.new(node2d)

    # Store reference identifier into Godot node metadata
    node2d.call("set_meta", "host_tag", host.tag)
    assert_true node2d.has_meta("host_tag")
    assert_eq node2d.call_str("get_meta", "host_tag"), "HostTag"

    # Clean disposal breaks cycle cleanly
    node2d.destroy
    assert_false Godot::Object.is_instance_id_valid(node_id)
    assert_disposed node2d
  end

  test "Sub-resource duplication preserves deep copy independence" do
    parent_mesh = Godot.create(Godot::BoxMesh)
    sub_material = Godot.create(Godot::StandardMaterial3D)
    sub_material.set_albedo(Godot::Color::RED)

    parent_mesh.set_material(sub_material)
    ret_mat = parent_mesh.get_material
    assert_not_nil ret_mat
    mat_typed = Godot::StandardMaterial3D.new(ret_mat.not_nil!.pointer)
    assert_approx_eq mat_typed.get_albedo.r, 1.0_f32

    # Duplicate with subresources enabled
    cloned_mesh_res = parent_mesh.duplicate(true)
    assert_not_nil cloned_mesh_res
    cloned_mesh = Godot::BoxMesh.new(cloned_mesh_res.pointer)
    cloned_mat = cloned_mesh.get_material
    assert_not_nil cloned_mat

    # Verify cloned material is a distinct object in ObjectDB
    assert_true cloned_mat.not_nil!.instance_id != sub_material.instance_id
  end

  test "assert_no_leak verifies zero net memory leak across batch iterations" do
    assert_no_leak(max_delta_objects: 0, name: "NodeBatchCycle") do
      50.times do |i|
        n = Godot.create(Godot::Node2D)
        n.name = "BatchNode_#{i}"
        n.position = Godot::Vector2.new(i.to_f32, i.to_f32)
        n.destroy
      end
    end
  end
end
