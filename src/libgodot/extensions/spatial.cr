module Godot
  # ===========================================================================
  # Node2D Spatial Conveniences
  # ===========================================================================
  class Node2D
    def x : Float32
      position.x
    end

    def x=(val : Number) : Void
      self.position = Vector2.new(val.to_f32, position.y)
    end

    def y : Float32
      position.y
    end

    def y=(val : Number) : Void
      self.position = Vector2.new(position.x, val.to_f32)
    end

    def global_x : Float32
      global_position.x
    end

    def global_x=(val : Number) : Void
      self.global_position = Vector2.new(val.to_f32, global_position.y)
    end

    def global_y : Float32
      global_position.y
    end

    def global_y=(val : Number) : Void
      self.global_position = Vector2.new(global_position.x, val.to_f32)
    end

    def look_at_pos(target : Vector2) : Void
      look_at(target)
    end

    # Returns distance from this node's global_position to another node's global_position
    def distance_to(other : Node2D) : Float32
      global_position.distance_to(other.global_position)
    end

    # Returns distance from this node's global_position to a 2D point
    def distance_to(point : Vector2) : Float32
      global_position.distance_to(point)
    end

    # Returns normalized direction vector from this node to another node
    def direction_to(other : Node2D) : Vector2
      global_position.direction_to(other.global_position)
    end

    # Returns normalized direction vector from this node to a 2D point
    def direction_to(point : Vector2) : Vector2
      global_position.direction_to(point)
    end

    # Returns angle in radians from this node to another node
    def angle_to_point(other : Node2D) : Float32
      global_position.angle_to_point(other.global_position)
    end

    # Returns angle in radians from this node to a 2D point
    def angle_to_point(point : Vector2) : Float32
      global_position.angle_to_point(point)
    end
  end

  # ===========================================================================
  # Node3D Spatial Conveniences
  # ===========================================================================
  class Node3D
    def x : Float32
      position.x
    end

    def x=(val : Number) : Void
      self.position = Vector3.new(val.to_f32, position.y, position.z)
    end

    def y : Float32
      position.y
    end

    def y=(val : Number) : Void
      self.position = Vector3.new(position.x, val.to_f32, position.z)
    end

    def z : Float32
      position.z
    end

    def z=(val : Number) : Void
      self.position = Vector3.new(position.x, position.y, val.to_f32)
    end

    def global_x : Float32
      global_position.x
    end

    def global_x=(val : Number) : Void
      self.global_position = Vector3.new(val.to_f32, global_position.y, global_position.z)
    end

    def global_y : Float32
      global_position.y
    end

    def global_y=(val : Number) : Void
      self.global_position = Vector3.new(global_position.x, val.to_f32, global_position.z)
    end

    def global_z : Float32
      global_position.z
    end

    def global_z=(val : Number) : Void
      self.global_position = Vector3.new(global_position.x, global_position.y, val.to_f32)
    end

    def look_at_pos(target : Vector3, up : Vector3 = Vector3::UP) : Void
      look_at(target, up)
    end

    # Returns distance from this node's global_position to another node's global_position
    def distance_to(other : Node3D) : Float32
      global_position.distance_to(other.global_position)
    end

    # Returns distance from this node's global_position to a 3D point
    def distance_to(point : Vector3) : Float32
      global_position.distance_to(point)
    end

    # Returns normalized direction vector from this node to another node
    def direction_to(other : Node3D) : Vector3
      global_position.direction_to(other.global_position)
    end

    # Returns normalized direction vector from this node to a 3D point
    def direction_to(point : Vector3) : Vector3
      global_position.direction_to(point)
    end

    # Out-of-tree safe override for `to_global` (avoids Godot C++ `!is_inside_tree()` error spam)
    def to_global(local_point : Vector3) : Vector3
      if !@pointer.null? && is_inside_tree
        previous_def(local_point)
      else
        global_transform * local_point
      end
    end

    # Out-of-tree safe override for `to_local` (avoids Godot C++ `!is_inside_tree()` error spam)
    def to_local(global_point : Vector3) : Vector3
      if !@pointer.null? && is_inside_tree
        previous_def(global_point)
      else
        global_transform.affine_inverse * global_point
      end
    end

    # Computes the accumulated transform of `self` relative to `ancestor` by walking parent links.
    # Safe to call both inside and outside the SceneTree.
    def relative_transform_to(ancestor : Node?) : Transform3D
      return Transform3D.identity if ancestor && ancestor.pointer == @pointer
      xf = transform
      curr = get_parent
      depth = 0
      while curr && !curr.pointer.null? && depth < 64
        break if ancestor && curr.pointer == ancestor.pointer
        if p3d = curr.godot_as?(Node3D)
          xf = p3d.transform * xf
        end
        curr = curr.get_parent
        depth += 1
      end
      xf
    end

    # Reparents this `Node3D` to `new_parent` while preserving its world/relative `Transform3D`
    # even when outside the SceneTree, and optionally assigns `owner`.
    def reparent_preserving_transform(new_parent : Node, owner : Node? = nil) : Void
      saved_global = global_transform
      if old_parent = get_parent
        if !old_parent.pointer.null? && old_parent.pointer != new_parent.pointer
          old_parent.remove_child(self)
        end
      end
      if get_parent.nil? || get_parent.try(&.pointer) != new_parent.pointer
        new_parent.add_child(self)
      end
      self.global_transform = saved_global
      if target_owner = owner
        set_owner(target_owner) if !target_owner.pointer.null? && target_owner.pointer != @pointer
      end
    end
  end

  # ===========================================================================
  # Control UI Conveniences
  # ===========================================================================
  class Control
    def rect : Rect2
      Rect2.new(position, size)
    end

    def rect=(r : Rect2) : Void
      self.position = r.position
      self.size = r.size
    end

    def mouse_in_rect?(screen_pos : Vector2) : Bool
      get_global_rect.has_point(screen_pos)
    end
  end
end
