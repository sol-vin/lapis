module Godot
  # ===========================================================================
  # RayCast & ShapeCast Query Extensions
  # ===========================================================================
  godot_collider_query RayCast2D, indexed: false
  godot_collider_query RayCast3D, indexed: false
  godot_collider_query ShapeCast2D, indexed: true
  godot_collider_query ShapeCast3D, indexed: true

  # Strongly-typed 2D physics intersection hit result.
  #
  # Encapsulates collision location, surface normal, and hit object reference
  # with built-in dead-pointer protection.
  #
  # ### Usage Example:
  # ```crystal
  # if hit = raycast_to(target_pos)
  #   # Standard Crystal downcasting with dead-pointer safety:
  #   if enemy = hit.collider.as?(Enemy)
  #     enemy.take_damage(25)
  #   end
  # end
  # ```
  struct PhysicsHit2D
    # The global intersection coordinate
    getter point : Vector2

    # The surface normal vector at the intersection point
    getter normal : Vector2

    # The RID of the colliding physics body or shape
    getter rid : RID

    # The shape index within the colliding body
    getter shape : Int32

    def initialize(@point : Vector2, @normal : Vector2, @collider : Godot::Object? = nil, @rid : RID = RID.new, @shape : Int32 = 0)
    end

    # Returns the hit collider if alive, or `nil` if already freed or absent.
    #
    # ### Rationale & Dead-Pointer Protection:
    # If the collider node was destroyed by Godot or GDScript (e.g. via `queue_free()`)
    # during the current physics step, accessing a stale pointer causes a segmentation
    # fault (`0xC0000005`).
    # `collider` dynamically validates `#alive?` before returning, safely yielding `nil`
    # if the native instance was deallocated.
    #
    # Pair with `.as?(Type)` for idiomatic, type-safe downcasting:
    # ```crystal
    # if player = hit.collider.as?(Player)
    #   player.heal(10)
    # end
    # ```
    def collider : Godot::Object?
      if c = @collider
        c.alive? ? c : nil
      else
        nil
      end
    end
  end

  # Strongly-typed 3D physics intersection hit result.
  #
  # Encapsulates collision location, surface normal, and hit object reference
  # with built-in dead-pointer protection.
  #
  # ### Usage Example:
  # ```crystal
  # if hit = raycast(Vector3.forward, distance: 20.0)
  #   if destructible = hit.collider.as?(DestructibleProp)
  #     destructible.shatter!
  #   end
  # end
  # ```
  struct PhysicsHit3D
    # The global intersection coordinate
    getter point : Vector3

    # The surface normal vector at the intersection point
    getter normal : Vector3

    # The RID of the colliding physics body or shape
    getter rid : RID

    # The shape index within the colliding body
    getter shape : Int32

    def initialize(@point : Vector3, @normal : Vector3, @collider : Godot::Object? = nil, @rid : RID = RID.new, @shape : Int32 = 0)
    end

    # Returns the hit collider if alive, or `nil` if already freed or absent.
    #
    # Dynamically verifies `#alive?` to guarantee dead-pointer safety.
    # Pair with `.as?(Type)` for type-safe dispatch.
    def collider : Godot::Object?
      if c = @collider
        c.alive? ? c : nil
      else
        nil
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
