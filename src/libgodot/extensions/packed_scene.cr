module Godot
  # ===========================================================================
  # PackedScene Generic Extensions
  # ===========================================================================
  class PackedScene
    # Convenience zero-argument instantiate defaulting edit_state to 0
    def instantiate : Node
      instantiate(0_i64)
    end

    # Instantiates the scene and casts directly to wrapper type T
    def instantiate_as(type : T.class, edit_state : Int64 = 0_i64) : T forall T
      node = instantiate(edit_state)
      if node.is_a?(T)
        return node
      elsif alive = Bridge.find_alive_instance(node.pointer)
        if typed = alive.as?(T)
          return typed
        end
      end
      if !node.pointer.null? && Bridge.object_is_class(node.pointer, T.name.split("::").last)
        return T.new(node.pointer)
      end
      T.new(node.pointer)
    end

    # Instantiates the scene and casts directly to wrapper type T (named argument alias)
    def instantiate(as type : T.class, edit_state : Int64 = 0_i64) : T forall T
      instantiate_as(type, edit_state)
    end
  end
end
