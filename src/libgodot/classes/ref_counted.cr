module Godot
  class RefCounted < Object
    @@mb_ref_init_ref : Void* = Pointer(Void).null
    @@mb_ref_reference : Void* = Pointer(Void).null
    @@mb_ref_unreference : Void* = Pointer(Void).null
    @@mb_ref_get_reference_count : Void* = Pointer(Void).null
    @_ref_initialized : Bool = false

    # Returns true for RefCounted subclasses whose raw ClassDB construction should
    # eagerly invoke `#ensure_ref_initialized!` so stack-temporary `Ref<T>` wrappers
    # inside transient Godot C++ methods do not `memdelete` the instance mid-call.
    def _needs_eager_ref_init? : Bool
      false
    end

    # Idempotently calls `#init_ref` at most once on this `RefCounted` wrapper so
    # stack-temporary `Ref<T>` conversions inside Godot `ptrcall` do not free it on return.
    def ensure_ref_initialized! : Void
      return if @_ref_initialized || @pointer.null?
      @_ref_initialized = true
      init_ref
    end

    def init_ref : Bool
      check_alive!
      @_ref_initialized = true
      godot_bind(@@mb_ref_init_ref, "RefCounted", "init_ref", 2240911060_i64)
      godot_ptrcall_bool(@@mb_ref_init_ref, @pointer, Pointer(Pointer(Void)).null)
    end

    # Predicate alias for `init_ref`
    def init_ref? : Bool
      init_ref
    end

    def reference : Bool
      check_alive!
      godot_bind(@@mb_ref_reference, "RefCounted", "reference", 2240911060_i64)
      godot_ptrcall_bool(@@mb_ref_reference, @pointer, Pointer(Pointer(Void)).null)
    end

    # Predicate alias for `reference`
    def reference? : Bool
      reference
    end

    def unreference : Bool
      return false if !alive?
      godot_bind(@@mb_ref_unreference, "RefCounted", "unreference", 2240911060_i64)
      target_ptr = @pointer
      target_id = signal_target_id
      should_free = godot_ptrcall_bool(@@mb_ref_unreference, target_ptr, Pointer(Pointer(Void)).null)
      if should_free
        inst_id = @instance_id
        @destroyed = true
        @pointer = Pointer(Void).null
        Godot.clear_signal_subscriptions(target_id)
        if Bridge.is_instance_valid(inst_id)
          Bridge.object_destroy(target_ptr)
        end
      end
      should_free
    end

    # Predicate alias for `unreference`
    def unreference? : Bool
      unreference
    end

    def get_reference_count : Int64
      check_alive!
      godot_bind(@@mb_ref_get_reference_count, "RefCounted", "get_reference_count", 3905245786_i64)
      godot_ptrcall_int(@@mb_ref_get_reference_count, @pointer, Pointer(Pointer(Void)).null)
    end

    # Safely destroys or unreferences this RefCounted object.
    def destroy : Void
      return if @destroyed
      target_ptr = @pointer
      inst_id = @instance_id
      target_id = signal_target_id
      @destroyed = true
      @pointer = Pointer(Void).null
      Godot.clear_signal_subscriptions(target_id)
      if !target_ptr.null?
        Bridge.unregister_alive_instance_by_ptr(target_ptr)
        is_alive = inst_id > 0 ? Bridge.is_instance_valid(inst_id) : true
        if is_alive
          if @@mb_ref_unreference.null?
            @@mb_ref_unreference = Bridge.get_method_bind("RefCounted", "unreference", 2240911060_i64)
          end
          if !@@mb_ref_unreference.null?
            # Unreference repeatedly until Godot frees the object or refcount reaches 0
            10.times do |iter|
              should_free = 0_u8
              Bridge.ptrcall(@@mb_ref_unreference, target_ptr, Pointer(Pointer(Void)).null, pointerof(should_free).as(Void*))
              valid = inst_id > 0 ? Bridge.is_instance_valid(inst_id) : false
              if should_free != 0_u8
                if valid
                  Bridge.object_destroy(target_ptr)
                end
                break
              end
              if !valid
                break
              end
              if @@mb_ref_get_reference_count.null?
                @@mb_ref_get_reference_count = Bridge.get_method_bind("RefCounted", "get_reference_count", 3905245786_i64)
              end
              rc = 0_i64
              if !@@mb_ref_get_reference_count.null?
                Bridge.ptrcall(@@mb_ref_get_reference_count, target_ptr, Pointer(Pointer(Void)).null, pointerof(rc).as(Void*))
              end
              if rc <= 0
                if inst_id == 0 || Bridge.is_instance_valid(inst_id)
                  Bridge.object_destroy(target_ptr)
                end
                break
              end
            end
          else
            if inst_id == 0 || Bridge.is_instance_valid(inst_id)
              Bridge.object_destroy(target_ptr)
            end
          end
        end
      end
    end
  end

  struct ::Nil
    def ==(other : Godot::Object) : Bool
      other.pointer.null?
    end
  end

end
