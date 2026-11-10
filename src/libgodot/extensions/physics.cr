module Godot
  class RefCounted < Object
    @_ref_initialized : Bool = false

    # Idempotently calls `#init_ref` at most once on this `RefCounted` wrapper so
    # stack-temporary `Ref<T>` conversions inside Godot `ptrcall` do not free it on return.
    def ensure_ref_initialized! : Void
      return if @_ref_initialized || @pointer.null?
      @_ref_initialized = true
      init_ref
    end
  end

  # ===========================================================================
  # Transient Physics Query & Collision RefCounted Ownership Protection
  # ===========================================================================
  # Godot C++ methods taking transient `const Ref<T> &` parameters (such as
  # `PhysicsBody3D::test_move(..., r_collision)`, `intersect_ray_into(query, result)`,
  # `intersect_shape_into(query, result)`) construct a stack-temporary `Ref<T>` inside
  # `MethodBind::ptrcall` and do NOT store `Ref<T>` in a member variable.
  # Calling `#ensure_ref_initialized!` upon creation transitions `refcount_init` from 1 -> 0 (`refcount == 1`),
  # so `ptrcall`'s temporary `Ref<T>` increments `refcount` to 2 during the call and
  # decrements it back to 1 on return instead of `memdelete`-ing the object mid-call.
  {% for cls in [
       KinematicCollision2D,
       KinematicCollision3D,
       PhysicsRayQueryParameters2D,
       PhysicsRayQueryParameters3D,
       PhysicsShapeQueryParameters2D,
       PhysicsShapeQueryParameters3D,
       PhysicsPointQueryParameters2D,
       PhysicsPointQueryParameters3D,
       PhysicsTestMotionParameters2D,
       PhysicsTestMotionParameters3D,
       PhysicsTestMotionResult2D,
       PhysicsTestMotionResult3D,
       PhysicsIntersectRayResult2D,
       PhysicsIntersectRayResult3D,
       PhysicsIntersectPointResult2D,
       PhysicsIntersectPointResult3D,
       PhysicsIntersectShapeResult2D,
       PhysicsIntersectShapeResult3D,
       PhysicsCastMotionResult2D,
       PhysicsCastMotionResult3D,
       PhysicsCollideShapeResult2D,
       PhysicsCollideShapeResult3D,
       PhysicsGetRestInfoResult2D,
       PhysicsGetRestInfoResult3D,
     ] %}
    class {{cls.id}}
      def self.create : self
        inst = ::Godot.create(self)
        inst.ensure_ref_initialized!
        inst
      end
    end
  {% end %}

  class PhysicsBody2D < CollisionObject2D
    def test_move(from : Transform2D, motion : Vector2, collision : KinematicCollision2D? = nil, safe_margin : Float64 = 0.08_f64, recovery_as_collision : Bool = false) : Bool
      return false if @pointer.null? || !is_inside_tree
      collision.try(&.ensure_ref_initialized!)
      godot_bind(@@mb_test_move, "PhysicsBody2D", "test_move", 3322999442_i64)
      val_0 = from
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = motion
      arg_1 = pointerof(val_1).as(Void*)
      arg_ptr_2 = collision ? collision.pointer : Pointer(Void).null
      arg_2 = pointerof(arg_ptr_2).as(Void*)
      val_3 = safe_margin.to_f64
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = recovery_as_collision
      arg_4 = pointerof(val_4).as(Void*)
      args = StaticArray[arg_0, arg_1, arg_2, arg_3, arg_4]
      godot_ptrcall_bool(@@mb_test_move, @pointer, args.to_unsafe.as(Void**))
    end
  end

  class PhysicsBody3D < CollisionObject3D
    def test_move(from : Transform3D, motion : Vector3, collision : KinematicCollision3D? = nil, safe_margin : Float64 = 0.001_f64, recovery_as_collision : Bool = false, max_collisions : Int64 = 1_i64) : Bool
      return false if @pointer.null? || !is_inside_tree
      collision.try(&.ensure_ref_initialized!)
      godot_bind(@@mb_test_move, "PhysicsBody3D", "test_move", 2481691619_i64)
      val_0 = from
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = motion
      arg_1 = pointerof(val_1).as(Void*)
      arg_ptr_2 = collision ? collision.pointer : Pointer(Void).null
      arg_2 = pointerof(arg_ptr_2).as(Void*)
      val_3 = safe_margin.to_f64
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = recovery_as_collision
      arg_4 = pointerof(val_4).as(Void*)
      val_5 = max_collisions.to_i64
      arg_5 = pointerof(val_5).as(Void*)
      args = StaticArray[arg_0, arg_1, arg_2, arg_3, arg_4, arg_5]
      godot_ptrcall_bool(@@mb_test_move, @pointer, args.to_unsafe.as(Void**))
    end
  end

  class PhysicsDirectSpaceState2D < Godot::Object
    def intersect_ray_into(parameters : PhysicsRayQueryParameters2D, result : PhysicsIntersectRayResult2D) : Bool
      parameters.ensure_ref_initialized!
      result.ensure_ref_initialized!
      godot_bind(@@mb_intersect_ray_into, "PhysicsDirectSpaceState2D", "intersect_ray_into", 2480877099_i64)
      arg_ptr_0 = parameters ? parameters.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      arg_ptr_1 = result ? result.pointer : Pointer(Void).null
      arg_1 = pointerof(arg_ptr_1).as(Void*)
      args = StaticArray[arg_0, arg_1]
      godot_ptrcall_bool(@@mb_intersect_ray_into, @pointer, args.to_unsafe.as(Void**))
    end

    def intersect_point_into(parameters : PhysicsPointQueryParameters2D, result : PhysicsIntersectPointResult2D) : Bool
      parameters.ensure_ref_initialized!
      result.ensure_ref_initialized!
      godot_bind(@@mb_intersect_point_into, "PhysicsDirectSpaceState2D", "intersect_point_into", 2338147429_i64)
      arg_ptr_0 = parameters ? parameters.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      arg_ptr_1 = result ? result.pointer : Pointer(Void).null
      arg_1 = pointerof(arg_ptr_1).as(Void*)
      args = StaticArray[arg_0, arg_1]
      godot_ptrcall_bool(@@mb_intersect_point_into, @pointer, args.to_unsafe.as(Void**))
    end

    def intersect_shape_into(parameters : PhysicsShapeQueryParameters2D, result : PhysicsIntersectShapeResult2D) : Bool
      parameters.ensure_ref_initialized!
      result.ensure_ref_initialized!
      godot_bind(@@mb_intersect_shape_into, "PhysicsDirectSpaceState2D", "intersect_shape_into", 1052395953_i64)
      arg_ptr_0 = parameters ? parameters.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      arg_ptr_1 = result ? result.pointer : Pointer(Void).null
      arg_1 = pointerof(arg_ptr_1).as(Void*)
      args = StaticArray[arg_0, arg_1]
      godot_ptrcall_bool(@@mb_intersect_shape_into, @pointer, args.to_unsafe.as(Void**))
    end
  end

  class PhysicsDirectSpaceState3D < Godot::Object
    def intersect_ray_into(parameters : PhysicsRayQueryParameters3D, result : PhysicsIntersectRayResult3D) : Bool
      parameters.ensure_ref_initialized!
      result.ensure_ref_initialized!
      godot_bind(@@mb_intersect_ray_into, "PhysicsDirectSpaceState3D", "intersect_ray_into", 1101524092_i64)
      arg_ptr_0 = parameters ? parameters.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      arg_ptr_1 = result ? result.pointer : Pointer(Void).null
      arg_1 = pointerof(arg_ptr_1).as(Void*)
      args = StaticArray[arg_0, arg_1]
      godot_ptrcall_bool(@@mb_intersect_ray_into, @pointer, args.to_unsafe.as(Void**))
    end

    def intersect_point_into(parameters : PhysicsPointQueryParameters3D, result : PhysicsIntersectPointResult3D) : Bool
      parameters.ensure_ref_initialized!
      result.ensure_ref_initialized!
      godot_bind(@@mb_intersect_point_into, "PhysicsDirectSpaceState3D", "intersect_point_into", 4224456912_i64)
      arg_ptr_0 = parameters ? parameters.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      arg_ptr_1 = result ? result.pointer : Pointer(Void).null
      arg_1 = pointerof(arg_ptr_1).as(Void*)
      args = StaticArray[arg_0, arg_1]
      godot_ptrcall_bool(@@mb_intersect_point_into, @pointer, args.to_unsafe.as(Void**))
    end

    def intersect_shape_into(parameters : PhysicsShapeQueryParameters3D, result : PhysicsIntersectShapeResult3D) : Bool
      parameters.ensure_ref_initialized!
      result.ensure_ref_initialized!
      godot_bind(@@mb_intersect_shape_into, "PhysicsDirectSpaceState3D", "intersect_shape_into", 2386936143_i64)
      arg_ptr_0 = parameters ? parameters.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      arg_ptr_1 = result ? result.pointer : Pointer(Void).null
      arg_1 = pointerof(arg_ptr_1).as(Void*)
      args = StaticArray[arg_0, arg_1]
      godot_ptrcall_bool(@@mb_intersect_shape_into, @pointer, args.to_unsafe.as(Void**))
    end
  end

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
      params = PhysicsRayQueryParameters2D.create
      return nil if params.pointer.null?
      result = PhysicsIntersectRayResult2D.create
      if result.pointer.null?
        params.destroy
        return nil
      end
      begin
        params.set_from(start_pos)
        params.set_to(target_pos)
        params.set_collision_mask(mask.to_i64)
        params.set_collide_with_areas(collide_with_areas)
        params.set_collide_with_bodies(collide_with_bodies)

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
      ensure
        params.destroy
        result.destroy
      end
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
      params = PhysicsRayQueryParameters3D.create
      return nil if params.pointer.null?
      result = PhysicsIntersectRayResult3D.create
      if result.pointer.null?
        params.destroy
        return nil
      end
      begin
        params.set_from(start_pos)
        params.set_to(target_pos)
        params.set_collision_mask(mask.to_i64)
        params.set_collide_with_areas(collide_with_areas)
        params.set_collide_with_bodies(collide_with_bodies)

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
      ensure
        params.destroy
        result.destroy
      end
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
