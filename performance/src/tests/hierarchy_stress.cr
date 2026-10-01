# =============================================================================
# Stress Test 5: Deep Hierarchy & Reparenting Stress
# =============================================================================

require "../framework/perf_base"
require "../framework/perf_registry"

module PerfFramework
  node HierarchyStress < Godot::Node do
    include PerfTestLifecycle
    @container : Godot::Node2D?
    @root_branches = Array(Godot::Node2D).new
    @tree_depth : Int32 = 25
    @num_trees : Int32 = 40

    def on_setup : Void
      @test_name = "DeepHierarchyChurn"
      @test_description = "Creates 40 trees of depth 25, reparents branches across subtrees, and destroys root nodes to test cascading cleanup."

      c = Godot.create(Godot::Node2D)
      c.call("set_name", "HierarchyContainer")
      add_child(c)
      @container = c
      @root_branches.clear

      build_trees
    end

    private def build_trees : Void
      return unless cont = @container

      @num_trees.times do |t|
        root_branch = Godot.create(Godot::Node2D)
        cont.add_child(root_branch)
        @root_branches << root_branch

        curr_parent = root_branch
        @tree_depth.times do |d|
          child = Godot.create(Godot::Node2D)
          curr_parent.add_child(child)
          curr_parent = child
        end
      end
    end

    def on_step(delta : Float64) : Void
      return unless cont = @container
      return if @root_branches.empty?

      # Reparent a branch from one root to another
      if @root_branches.size >= 2
        src_idx = rand(@root_branches.size)
        dst_idx = (src_idx + 1) % @root_branches.size

        src_root = @root_branches[src_idx]
        dst_root = @root_branches[dst_idx]

        # Find first child of src_root
        child_count = src_root.get_child_count
        if child_count > 0
          child = src_root.get_child(0_i64)
          src_root.remove_child(child)
          dst_root.add_child(child)
        end
      end

      # Periodically destroy a random tree and recreate it to test cascading deallocation
      if @completed_cycles % 10 == 0 && !@root_branches.empty?
        del_idx = rand(@root_branches.size)
        old_tree = @root_branches.delete_at(del_idx)
        cont.remove_child(old_tree)
        old_tree.destroy # Cascades to all nested children

        # Re-create a fresh tree
        new_root = Godot.create(Godot::Node2D)
        cont.add_child(new_root)
        @root_branches << new_root

        curr = new_root
        @tree_depth.times do |d|
          c = Godot.create(Godot::Node2D)
          curr.add_child(c)
          curr = c
        end
      end
    end

    def on_teardown : Void
      if cont = @container
        @root_branches.each do |tree|
          cont.remove_child(tree)
          tree.destroy
        end
        @root_branches.clear
        remove_child(cont)
        cont.destroy
        @container = nil
      end
    end
  end

  TestRegistry.register(
    id: "hierarchy",
    title: "Deep Hierarchy & Reparenting",
    category: "SceneTree",
    description: "Stresses recursive child deletion, transform inheritance propagation, and live reparenting.",
    scene_path: "res://scenes/tests/test_deep_hierarchy.tscn",
    default_count: 1000,
    default_duration: 15.0
  )
end
