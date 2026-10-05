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

  # Fluent builder for constructing and executing 2D raycasts.
  class RaycastBuilder2D
    getter origin_node : Node2D
    getter from_pos : Vector2
    getter to_pos : Vector2?
    getter mask_val : UInt32 = 0xFFFFFFFF_u32
    getter exclude_list : Array(Godot::Object | Godot::RID) = Array(Godot::Object | Godot::RID).new
    getter? collide_with_areas : Bool = false
    getter? collide_with_bodies : Bool = true

    def initialize(@origin_node : Node2D, @to_pos : Vector2? = nil)
      @from_pos = @origin_node.global_position
    end

    def from(pos : Vector2) : self
      @from_pos = pos
      self
    end

    def to(pos : Vector2) : self
      @to_pos = pos
      self
    end

    def direction(dir : Vector2, distance : Float64 = 100.0) : self
      @to_pos = @from_pos + (dir.normalized * distance.to_f32)
      self
    end

    def mask(mask : UInt32 | Int) : self
      @mask_val = mask.to_u32
      self
    end

    def exclude(*objects : Godot::Object | Godot::RID) : self
      objects.each { |o| @exclude_list << o }
      self
    end

    def exclude(list : Enumerable(Godot::Object | Godot::RID)) : self
      list.each { |o| @exclude_list << o }
      self
    end

    def areas(enable : Bool = true) : self
      @collide_with_areas = enable
      self
    end

    def bodies(enable : Bool = true) : self
      @collide_with_bodies = enable
      self
    end

    def query : PhysicsHit2D?
      target = @to_pos || @from_pos
      @origin_node.raycast_to(
        target_pos: target,
        mask: @mask_val,
        exclude: @exclude_list.empty? ? nil : @exclude_list,
        collide_with_areas: @collide_with_areas,
        collide_with_bodies: @collide_with_bodies,
        from_pos: @from_pos
      )
    end

    def collide? : Bool
      !query.nil?
    end
  end

  # Fluent builder for constructing and executing 3D raycasts.
  class RaycastBuilder3D
    getter origin_node : Node3D
    getter from_pos : Vector3
    getter to_pos : Vector3?
    getter mask_val : UInt32 = 0xFFFFFFFF_u32
    getter exclude_list : Array(Godot::Object | Godot::RID) = Array(Godot::Object | Godot::RID).new
    getter? collide_with_areas : Bool = false
    getter? collide_with_bodies : Bool = true

    def initialize(@origin_node : Node3D, @to_pos : Vector3? = nil)
      @from_pos = @origin_node.global_position
    end

    def from(pos : Vector3) : self
      @from_pos = pos
      self
    end

    def to(pos : Vector3) : self
      @to_pos = pos
      self
    end

    def direction(dir : Vector3, distance : Float64 = 10.0) : self
      @to_pos = @from_pos + (dir.normalized * distance.to_f32)
      self
    end

    def mask(mask : UInt32 | Int) : self
      @mask_val = mask.to_u32
      self
    end

    def exclude(*objects : Godot::Object | Godot::RID) : self
      objects.each { |o| @exclude_list << o }
      self
    end

    def exclude(list : Enumerable(Godot::Object | Godot::RID)) : self
      list.each { |o| @exclude_list << o }
      self
    end

    def areas(enable : Bool = true) : self
      @collide_with_areas = enable
      self
    end

    def bodies(enable : Bool = true) : self
      @collide_with_bodies = enable
      self
    end

    def query : PhysicsHit3D?
      target = @to_pos || @from_pos
      @origin_node.raycast_to(
        target_pos: target,
        mask: @mask_val,
        exclude: @exclude_list.empty? ? nil : @exclude_list,
        collide_with_areas: @collide_with_areas,
        collide_with_bodies: @collide_with_bodies,
        from_pos: @from_pos
      )
    end

    def collide? : Bool
      !query.nil?
    end
  end

  class Node2D < CanvasItem
    # Performs a direct 2D raycast to the specified global target position.
    def raycast_to(target_pos : Vector2, mask : UInt32 | Int = 0xFFFFFFFF_u32, exclude : ::Array(Godot::Object | Godot::RID)? = nil, collide_with_areas : Bool = false, collide_with_bodies : Bool = true, from_pos : Vector2? = nil) : PhysicsHit2D?
      return nil unless alive?
      return nil if @pointer.null?
      w2d = get_world_2d
      return nil if w2d.pointer.null?
      space = w2d.get_direct_space_state
      return nil if space.pointer.null?

      start_pos = from_pos || global_position
      params = PhysicsRayQueryParameters2D.new
      params.set_from(start_pos)
      params.set_to(target_pos)
      params.set_collision_mask(mask.to_i64)
      params.set_collide_with_areas(collide_with_areas)
      params.set_collide_with_bodies(collide_with_bodies)

      result = Godot.create(PhysicsIntersectRayResult2D)
      return nil if result.pointer.null?
      has_hit = space.intersect_ray_into(params, result)
      return nil unless has_hit

      col = result.get_collider
      valid_col = (col.nil? || col.pointer.null? || !col.alive?) ? nil : col

      if exclude && !exclude.empty?
        exclude.each do |ex|
          if ex.is_a?(Godot::Object)
            return nil if valid_col && ex.alive? && ex.object_id == valid_col.object_id
          elsif ex.is_a?(Godot::RID)
            return nil if ex.id == result.get_collider_rid.to_u64
          end
        end
      end

      PhysicsHit2D.new(result.get_position, result.get_normal, valid_col, RID.new(result.get_collider_rid), result.get_collider_shape.to_i32)
    end

    # Performs a direct 2D raycast in the given direction and distance.
    def raycast(direction : Vector2, distance : Float64 = 100.0, mask : UInt32 | Int = 0xFFFFFFFF_u32, exclude : ::Array(Godot::Object | Godot::RID)? = nil, collide_with_areas : Bool = false, collide_with_bodies : Bool = true) : PhysicsHit2D?
      target = global_position + (direction.normalized * distance.to_f32)
      raycast_to(target, mask: mask, exclude: exclude, collide_with_areas: collide_with_areas, collide_with_bodies: collide_with_bodies)
    end

    # Returns a fluent builder for configuring and executing a 2D raycast query.
    def raycast2d(to : Vector2? = nil) : RaycastBuilder2D
      RaycastBuilder2D.new(self, to)
    end
  end

  class Node3D < Node
    # Performs a direct 3D raycast to the specified global target position.
    def raycast_to(target_pos : Vector3, mask : UInt32 | Int = 0xFFFFFFFF_u32, exclude : ::Array(Godot::Object | Godot::RID)? = nil, collide_with_areas : Bool = false, collide_with_bodies : Bool = true, from_pos : Vector3? = nil) : PhysicsHit3D?
      return nil unless alive?
      return nil if @pointer.null?
      w3d = get_world_3d
      return nil if w3d.pointer.null?
      space = w3d.get_direct_space_state
      return nil if space.pointer.null?

      start_pos = from_pos || global_position
      params = PhysicsRayQueryParameters3D.new
      params.set_from(start_pos)
      params.set_to(target_pos)
      params.set_collision_mask(mask.to_i64)
      params.set_collide_with_areas(collide_with_areas)
      params.set_collide_with_bodies(collide_with_bodies)

      result = Godot.create(PhysicsIntersectRayResult3D)
      return nil if result.pointer.null?
      has_hit = space.intersect_ray_into(params, result)
      return nil unless has_hit

      col = result.get_collider
      valid_col = (col.nil? || col.pointer.null? || !col.alive?) ? nil : col

      if exclude && !exclude.empty?
        exclude.each do |ex|
          if ex.is_a?(Godot::Object)
            return nil if valid_col && ex.alive? && ex.object_id == valid_col.object_id
          elsif ex.is_a?(Godot::RID)
            return nil if ex.id == result.get_collider_rid.to_u64
          end
        end
      end

      PhysicsHit3D.new(result.get_position, result.get_normal, valid_col, RID.new(result.get_collider_rid), result.get_collider_shape.to_i32)
    end

    # Performs a direct 3D raycast in the given direction and distance.
    def raycast(direction : Vector3, distance : Float64 = 10.0, mask : UInt32 | Int = 0xFFFFFFFF_u32, exclude : ::Array(Godot::Object | Godot::RID)? = nil, collide_with_areas : Bool = false, collide_with_bodies : Bool = true) : PhysicsHit3D?
      target = global_position + (direction.normalized * distance.to_f32)
      raycast_to(target, mask: mask, exclude: exclude, collide_with_areas: collide_with_areas, collide_with_bodies: collide_with_bodies)
    end

    # Returns a fluent builder for configuring and executing a 3D raycast query.
    def raycast3d(to : Vector3? = nil) : RaycastBuilder3D
      RaycastBuilder3D.new(self, to)
    end
  end
end
