module Godot
  # Shared thread-local handoff slots for RefCounted ownership adoption.
  # Stored on a module because Crystal `@[ThreadLocal]` class variables on classes
  # are instantiated per-subclass rather than shared across inheritance hierarchies.
  module RefCountedTLS
    @[ThreadLocal]
    class_property adopting_ptr : Void* = Pointer(Void).null

    @[ThreadLocal]
    class_property constructed_ptr : Void* = Pointer(Void).null
  end

  class RefCounted < Object
    @@mb_ref_init_ref : Void* = Pointer(Void).null
    @@mb_ref_reference : Void* = Pointer(Void).null
    @@mb_ref_unreference : Void* = Pointer(Void).null
    @@mb_ref_get_reference_count : Void* = Pointer(Void).null

    @@_no_order_finalizer : LibGC::Finalizer = ->(obj : Void*, _cd : Void*) {
      obj.as(::Godot::RefCounted)._finalize_unrefs_no_order!
      nil
    }

    @_ref_initialized : Bool = false
    @_owned_refs : Int32 = 0
    @_is_extension_self : Bool = false
    @_finalizer_registered : Bool = false

    def self._record_constructed_ptr(ptr : Void*) : Void
      RefCountedTLS.constructed_ptr = ptr
    end

    def self._clear_constructed_ptr_if_matches(ptr : Void*) : Void
      if !ptr.null? && RefCountedTLS.constructed_ptr == ptr
        RefCountedTLS.constructed_ptr = Pointer(Void).null
      end
    end

    private def _ensure_no_order_finalizer! : Void
      return if @_finalizer_registered || @_is_extension_self
      @_finalizer_registered = true
      LibGC.register_finalizer_no_order(self.as(Void*), @@_no_order_finalizer, Pointer(Void).null, Pointer(LibGC::Finalizer).null, Pointer(Void*).null)
    end

    protected def _after_object_init! : Void
      if Bridge.creating_extension?
        @_is_extension_self = true
        return
      end
      if !@pointer.null? && @instance_id > 0_u64 && !@_is_extension_self && !Bridge.api.null?
        if RefCountedTLS.adopting_ptr == @pointer
          RefCountedTLS.adopting_ptr = Pointer(Void).null
          if RefCountedTLS.constructed_ptr == @pointer
            RefCountedTLS.constructed_ptr = Pointer(Void).null
          end
          @_ref_initialized = true
          @_owned_refs = 1
          _ensure_no_order_finalizer!
        elsif RefCountedTLS.constructed_ptr == @pointer
          RefCountedTLS.constructed_ptr = Pointer(Void).null
          @_ref_initialized = true
          @_owned_refs = 1
          _ensure_no_order_finalizer!
        else
          _raw_init_ref
          @_ref_initialized = true
          @_owned_refs = 1
          _ensure_no_order_finalizer!
        end
      end
    end

    # Marks this instance as a custom Crystal GDExtension instance whose lifetime is
    # mirrored in `Bridge.@@alive_instances` until Godot invokes `free_fn`.
    def _mark_extension_self! : Void
      @_is_extension_self = true
    end

    def _extension_self? : Bool
      @_is_extension_self
    end

    def _owned_refs : Int32
      @_owned_refs
    end

    # Adopts the +1 reference returned by `classdb_construct_object3` on a custom Crystal extension RefCounted.
    def _adopt_constructed_extension_ref! : Void
      return if @pointer.null? || @instance_id == 0_u64 || Bridge.api.null?
      @_ref_initialized = true
      @_owned_refs = 1 if @_owned_refs == 0
    end

    # Ensures the initial single reference for a custom Crystal `RefCounted` constructed
    # directly from Crystal (`Godot.create(MyResource)` / `Channel.new`).
    def _acquire_extension_self_ref! : Void
      return if @pointer.null? || @instance_id == 0_u64 || Bridge.api.null?
      unless @_ref_initialized
        if get_reference_count == 0
          _raw_init_ref
        end
        @_ref_initialized = true
      end
      @_owned_refs = 1 if @_owned_refs == 0
    end

    # Adopts a +1 C++ reference already transferred by ptrcall / ResourceLoader / object_call_ret_object
    # on a custom Crystal extension RefCounted, or releases the redundant extra C++ reference if already owned.
    def _adopt_or_release_returned_extension_ref! : Void
      return if @pointer.null? || @instance_id == 0_u64 || Bridge.api.null?
      @_ref_initialized = true
      if @_owned_refs == 0
        @_owned_refs = 1
      else
        Bridge.unref_raw_once(@pointer, @instance_id)
      end
    end

    # Releases any owned C++ references held on a custom Crystal extension RefCounted during shutdown.
    def _release_extension_self_refs! : Void
      return if @destroyed || @pointer.null?
      refs = @_owned_refs
      @_owned_refs = 0
      return if refs <= 0
      Bridge.unref_raw_n(@pointer, @instance_id, refs)
    end

    # Ensures a custom Crystal extension RefCounted unpacked into a Crystal property or collection
    # holds at least 1 Crystal-owned C++ reference so transient C++ Variant/Array containers
    # do not free it on scope exit, without inflating refcount on repeated property assignments.
    def _ensure_extension_borrowed_ref! : Void
      return if @pointer.null? || @instance_id == 0_u64 || Bridge.api.null?
      if @_owned_refs == 0
        @_ref_initialized = true
        reference
      end
    end

    def self._resolve_property_instance(type : T.class, ptr : Void*) : T forall T
      if ptr.null?
        return T.new(ptr)
      end
      if alive = Bridge.find_alive_instance(ptr)
        if casted = alive.as?(T)
          if alive.is_a?(RefCounted)
            alive._ensure_extension_borrowed_ref!
          end
          return casted
        end
      end
      T.new(ptr)
    end

    # Wraps a pointer returned by a C++ API that ALREADY transferred +1 strong reference
    # (`godot_ptrcall_obj`, `Bridge.resource_loader_load`, `Bridge.object_call_ret_object`).
    def self._wrap_returned_ref(type : T.class, ptr : Void*) : T forall T
      if ptr.null?
        return T.new(ptr)
      end
      if alive = Bridge.find_alive_instance(ptr)
        if casted = alive.as?(T)
          if alive.is_a?(RefCounted)
            alive._adopt_or_release_returned_extension_ref!
          end
          return casted
        end
      end
      prev = RefCountedTLS.adopting_ptr
      RefCountedTLS.adopting_ptr = ptr
      begin
        T.new(ptr)
      ensure
        RefCountedTLS.adopting_ptr = prev
      end
    end

    def self._wrap_returned_ref_or_nil(type : T.class, ptr : Void*) : T? forall T
      return nil if ptr.null?
      _wrap_returned_ref(type, ptr)
    end

    def self._wrap_ptrcall_return(ptr : Void*) : self
      _wrap_returned_ref(self, ptr)
    end

    def self._wrap_ptrcall_return_or_nil(ptr : Void*) : self?
      _wrap_returned_ref_or_nil(self, ptr)
    end

    protected def _raw_init_ref : Bool
      godot_bind(@@mb_ref_init_ref, "RefCounted", "init_ref", 2240911060_i64)
      return false if @@mb_ref_init_ref.null?
      godot_ptrcall_bool(@@mb_ref_init_ref, @pointer, Pointer(Pointer(Void)).null)
    end

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
      init_ref
    end

    def init_ref : Bool
      check_alive!
      return true if @_ref_initialized
      @_ref_initialized = true
      res = _raw_init_ref
      if @_owned_refs == 0 && res
        @_owned_refs = 1
        _ensure_no_order_finalizer!
      end
      res
    end

    # Predicate alias for `init_ref`
    def init_ref? : Bool
      init_ref
    end

    def reference : Bool
      check_alive!
      godot_bind(@@mb_ref_reference, "RefCounted", "reference", 2240911060_i64)
      res = godot_ptrcall_bool(@@mb_ref_reference, @pointer, Pointer(Pointer(Void)).null)
      if res
        @_owned_refs += 1
        _ensure_no_order_finalizer!
      end
      res
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
      @_owned_refs -= 1 if @_owned_refs > 0
      should_free = godot_ptrcall_bool(@@mb_ref_unreference, target_ptr, Pointer(Pointer(Void)).null)
      if should_free
        inst_id = @instance_id
        @_owned_refs = 0
        @destroyed = true
        Godot.clear_signal_subscriptions(target_id)
        begin
          if Bridge.is_instance_valid(inst_id)
            Bridge.object_destroy(target_ptr)
          end
        ensure
          @pointer = Pointer(Void).null
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

    # Safely releases references owned by this RefCounted wrapper, destroying the native
    # Godot object only when its total reference count reaches zero.
    def destroy : Void
      return if @destroyed
      target_ptr = @pointer
      inst_id = @instance_id
      target_id = signal_target_id
      refs_to_release = @_owned_refs
      @_owned_refs = 0
      @destroyed = true
      Godot.clear_signal_subscriptions(target_id)
      begin
        if !target_ptr.null? && !Bridge.api.null?
          if refs_to_release > 0
            Bridge.unref_raw_n(target_ptr, inst_id, refs_to_release)
          elsif @_is_extension_self
            Bridge.unref_raw_n(target_ptr, inst_id, 1)
          end
        end
      ensure
        @pointer = Pointer(Void).null
      end
    end

    # Lock-free cycle-safe GC finalizer queuing remaining owned references for main-thread release.
    def _finalize_unrefs_no_order! : Void
      return if @_is_extension_self || @destroyed
      refs = @_owned_refs
      ptr = @pointer
      id = @instance_id
      @_owned_refs = 0
      @pointer = Pointer(Void).null
      if refs > 0 && !ptr.null? && id > 0_u64
        Bridge.enqueue_deferred_unref(ptr, id, refs)
      end
    end
  end

  struct ::Nil
    def ==(other : Godot::Object) : Bool
      other.pointer.null?
    end
  end

end
