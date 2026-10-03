module Godot
  # ===========================================================================
  # RayCast & ShapeCast Query Extensions
  # ===========================================================================
  godot_collider_query RayCast2D, indexed: false
  godot_collider_query RayCast3D, indexed: false
  godot_collider_query ShapeCast2D, indexed: true
  godot_collider_query ShapeCast3D, indexed: true

  # Strongly-typed 2D physics intersection hit result.
  struct PhysicsHit2D
    getter point : Vector2
    getter normal : Vector2
    getter collider : Godot::Object?
    getter rid : RID
    getter shape : Int32

    def initialize(@point : Vector2, @normal : Vector2, @collider : Godot::Object? = nil, @rid : RID = RID.new, @shape : Int32 = 0)
    end

    # Returns the hit collider safely downcasted to type T, or nil if type mismatch
    def collider_as(type : T.class) : T? forall T
      if c = @collider
        if c.is_a?(T)
          c
        elsif node = c.as?(Godot::Node)
          Godot::Node.cast_to?(node, T)
        else
          nil
        end
      end
    end
  end

  # Strongly-typed 3D physics intersection hit result.
  struct PhysicsHit3D
    getter point : Vector3
    getter normal : Vector3
    getter collider : Godot::Object?
    getter rid : RID
    getter shape : Int32

    def initialize(@point : Vector3, @normal : Vector3, @collider : Godot::Object? = nil, @rid : RID = RID.new, @shape : Int32 = 0)
    end

    # Returns the hit collider safely downcasted to type T, or nil if type mismatch
    def collider_as(type : T.class) : T? forall T
      if c = @collider
        if c.is_a?(T)
          c
        elsif node = c.as?(Godot::Node)
          Godot::Node.cast_to?(node, T)
        else
          nil
        end
      end
    end
  end

  class Node2D < CanvasItem
    # Performs a direct 2D raycast to the specified global target position.
    def raycast_to(target_pos : Vector2, mask : UInt32 | Int = 0xFFFFFFFF_u32, exclude : ::Array(Godot::Object)? = nil, collide_with_areas : Bool = false, collide_with_bodies : Bool = true) : PhysicsHit2D?
      return nil unless alive?
      return nil if @pointer.null?
      w2d = get_world_2d
      return nil if w2d.pointer.null?
      space = w2d.get_direct_space_state
      return nil if space.pointer.null?

      params = PhysicsRayQueryParameters2D.new
      params.set_from(global_position)
      params.set_to(target_pos)
      params.set_collision_mask(mask.to_i64)
      params.set_collide_with_areas(collide_with_areas)
      params.set_collide_with_bodies(collide_with_bodies)

      dict_var = space.call("intersect_ray", params)
      if dict_var.is_nil?
        return nil
      end
      if raw = dict_var.raw
        if raw.is_a?(Godot::Dictionary)
          return nil if raw.is_empty
          pt = raw.get("position", as: Vector2, default: Vector2.new)
          norm = raw.get("normal", as: Vector2, default: Vector2.new)
          col = raw.get?("collider", as: Godot::Object)
          shp = raw.get("shape", as: Int32, default: 0)
          return PhysicsHit2D.new(pt, norm, col, RID.new, shp)
        end
      end
      nil
    end

    # Performs a direct 2D raycast in the given direction and distance.
    def raycast(direction : Vector2, distance : Float64 = 100.0, mask : UInt32 | Int = 0xFFFFFFFF_u32, exclude : ::Array(Godot::Object)? = nil, collide_with_areas : Bool = false, collide_with_bodies : Bool = true) : PhysicsHit2D?
      target = global_position + (direction.normalized * distance.to_f32)
      raycast_to(target, mask: mask, exclude: exclude, collide_with_areas: collide_with_areas, collide_with_bodies: collide_with_bodies)
    end
  end

  class Node3D < Node
    # Performs a direct 3D raycast to the specified global target position.
    def raycast_to(target_pos : Vector3, mask : UInt32 | Int = 0xFFFFFFFF_u32, exclude : ::Array(Godot::Object)? = nil, collide_with_areas : Bool = false, collide_with_bodies : Bool = true) : PhysicsHit3D?
      return nil unless alive?
      return nil if @pointer.null?
      w3d = get_world_3d
      return nil if w3d.pointer.null?
      space = w3d.get_direct_space_state
      return nil if space.pointer.null?

      params = PhysicsRayQueryParameters3D.new
      params.set_from(global_position)
      params.set_to(target_pos)
      params.set_collision_mask(mask.to_i64)
      params.set_collide_with_areas(collide_with_areas)
      params.set_collide_with_bodies(collide_with_bodies)

      dict_var = space.call("intersect_ray", params)
      if dict_var.is_nil?
        return nil
      end
      if raw = dict_var.raw
        if raw.is_a?(Godot::Dictionary)
          return nil if raw.is_empty
          pt = raw.get("position", as: Vector3, default: Vector3.new)
          norm = raw.get("normal", as: Vector3, default: Vector3.new)
          col = raw.get?("collider", as: Godot::Object)
          shp = raw.get("shape", as: Int32, default: 0)
          return PhysicsHit3D.new(pt, norm, col, RID.new, shp)
        end
      end
      nil
    end

    # Performs a direct 3D raycast in the given direction and distance.
    def raycast(direction : Vector3, distance : Float64 = 10.0, mask : UInt32 | Int = 0xFFFFFFFF_u32, exclude : ::Array(Godot::Object)? = nil, collide_with_areas : Bool = false, collide_with_bodies : Bool = true) : PhysicsHit3D?
      target = global_position + (direction.normalized * distance.to_f32)
      raycast_to(target, mask: mask, exclude: exclude, collide_with_areas: collide_with_areas, collide_with_bodies: collide_with_bodies)
    end
  end
end
