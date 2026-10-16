module Godot
  class PackedScene < Resource
    # Instantiates the scene's node hierarchy.
    def instantiate(edit_state : Int64 = 0_i64) : Node
      ptr = Bridge.packed_scene_instantiate(@pointer, edit_state)
      Node.new(ptr)
    end
  end

end
