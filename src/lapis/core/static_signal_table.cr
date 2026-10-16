# =============================================================================
# Lapis::Core::StaticSignalTable — Zero-Allocation Signal Dispatch Engine
# =============================================================================
# Tier 1 Core Engine Layer:
# Pre-allocated, open-addressed static signal dispatch table and compile-time
# typed slot handles (`StaticSignalSlot(*T)`).
#
# Eliminates all GC heap allocations on the signal emission hot path:
#   - Zero `Variant` boxing on typed emissions
#   - Zero `Array(Variant)` heap allocations
#   - Zero `list.dup` array cloning during listener notification
#   - Zero closure wrapper allocations per emission
#   - Optional `FrameArena` staging for raw C-ABI / struct payload broadcasts
#
# Work Order: WO-064 ([AS-1])
# Specialist: Gamma (Godot Lead Engineer)
# Target Branch: 4.8-beta1
# =============================================================================

require "./frame_arena"

module Lapis
  module Core
    # Low-level C-ABI compatible callback receiving `(emitter_id, payload_ptr, payload_bytes)`.
    alias RawSignalCallback = Proc(UInt64, Pointer(Void), Int32, Void)

    # Telemetry snapshot for `StaticSignalTable`.
    struct StaticSignalTableStats
      getter active_slots : Int32
      getter active_listeners : Int32
      getter total_emissions : UInt64
      getter slot_capacity : Int32
      getter listener_capacity : Int32

      def initialize(
        @active_slots : Int32,
        @active_listeners : Int32,
        @total_emissions : UInt64,
        @slot_capacity : Int32,
        @listener_capacity : Int32,
      )
      end
    end

    # Flat open-addressed hash bucket representing a unique `(emitter_id, signal_hash)` slot.
    struct SignalSlotEntry
      property emitter_id : UInt64
      property signal_hash : UInt64
      property head_index : Int32
      property tail_index : Int32
      property active_count : Int32
      property emission_count : UInt64
      property occupied : Bool

      def initialize(
        @emitter_id : UInt64 = 0_u64,
        @signal_hash : UInt64 = 0_u64,
        @head_index : Int32 = -1,
        @tail_index : Int32 = -1,
        @active_count : Int32 = 0,
        @emission_count : UInt64 = 0_u64,
        @occupied : Bool = false,
      )
      end

      @[AlwaysInline]
      def self.empty : self
        new
      end
    end

    # Pre-allocated listener record stored in the flat listener pool of `StaticSignalTable`.
    struct SignalListenerRecord
      property emitter_id : UInt64
      property signal_hash : UInt64
      property proc_pointer : Pointer(Void)
      property proc_closure_data : Pointer(Void)
      property match_proc_pointer : Pointer(Void)
      property match_closure_data : Pointer(Void)
      property raw_callback : RawSignalCallback?
      property subscription : ::Godot::SignalSubscription?
      property token : UInt64
      property slot_index : Int32
      property next_index : Int32
      property arity : Int32
      property once : Bool
      property active : Bool

      def initialize(
        @emitter_id : UInt64 = 0_u64,
        @signal_hash : UInt64 = 0_u64,
        @proc_pointer : Pointer(Void) = Pointer(Void).null,
        @proc_closure_data : Pointer(Void) = Pointer(Void).null,
        @match_proc_pointer : Pointer(Void) = Pointer(Void).null,
        @match_closure_data : Pointer(Void) = Pointer(Void).null,
        @raw_callback : RawSignalCallback? = nil,
        @subscription : ::Godot::SignalSubscription? = nil,
        @token : UInt64 = 0_u64,
        @slot_index : Int32 = -1,
        @next_index : Int32 = -1,
        @arity : Int32 = 0,
        @once : Bool = false,
        @active : Bool = false,
      )
      end

      @[AlwaysInline]
      def self.empty : self
        new
      end
    end

    # Zero-allocation static signal dispatch table.
    #
    # Stores all signal slots and listener records in pre-allocated flat `Slice`
    # pools with an intrusive free-list for recycled listener records.
    class StaticSignalTable
      DEFAULT_MAX_SLOTS     = 1024
      DEFAULT_MAX_LISTENERS = 4096
      MAX_STACK_SNAPSHOT    =   64

      FNV_OFFSET_BASIS = 0xcbf29ce484222325_u64
      FNV_PRIME        = 0x00000100000001b3_u64

      getter slot_capacity : Int32
      getter listener_capacity : Int32
      getter active_slots : Int32 = 0
      getter active_listeners : Int32 = 0
      getter total_emissions : UInt64 = 0_u64

      @slots : Slice(SignalSlotEntry)
      @listeners : Slice(SignalListenerRecord)
      @slot_mask : UInt64
      @listener_cursor : Int32 = 0
      @free_listener_head : Int32 = -1
      @next_token : UInt64 = 1_u64

      @@global : StaticSignalTable? = nil
      @@anon_emitter_counter : UInt64 = 0x8000_0000_0000_0000_u64

      def initialize(max_slots : Int32 = DEFAULT_MAX_SLOTS, max_listeners : Int32 = DEFAULT_MAX_LISTENERS)
        pow2 = 16
        while pow2 < max_slots
          pow2 <<= 1
        end
        @slot_capacity = pow2
        @slot_mask = (pow2 - 1).to_u64
        @listener_capacity = max_listeners > 16 ? max_listeners : 16
        @slots = Slice(SignalSlotEntry).new(@slot_capacity, SignalSlotEntry.empty)
        @listeners = Slice(SignalListenerRecord).new(@listener_capacity, SignalListenerRecord.empty)
      end

      # Global singleton dispatch table used by Lapis `TypedSignal` and `signal` macros.
      @[AlwaysInline]
      def self.global : StaticSignalTable
        @@global ||= new
      end

      # Alias for `StaticSignalTable.global`.
      @[AlwaysInline]
      def self.current : StaticSignalTable
        global
      end

      # Resets the global dispatch table state in-place without reallocating backing slices.
      def self.reset_global! : Void
        if tbl = @@global
          tbl.clear!
        end
      end

      # Generates a unique monotonic emitter ID for standalone `StaticSignalSlot` instances.
      def self.next_anonymous_emitter_id : UInt64
        @@anon_emitter_counter &+= 1_u64
        @@anon_emitter_counter
      end

      # Computes the 64-bit FNV-1a hash of a signal name with zero heap allocations.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def self.fnv1a_64(name : String) : UInt64
        hash = FNV_OFFSET_BASIS
        bytes = name.to_slice
        idx = 0
        len = bytes.size
        while idx < len
          hash ^= bytes.unsafe_fetch(idx).to_u64
          hash &*= FNV_PRIME
          idx += 1
        end
        hash
      end

      # Alias for `fnv1a_64` used by synthesized `signal` and `on_signal` macros.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def self.hash_signal_name(name : String) : UInt64
        fnv1a_64(name)
      end

      # Mixes `(emitter_id, signal_hash)` into a well-distributed 64-bit probe key.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def self.combine_key(emitter_id : UInt64, signal_hash : UInt64) : UInt64
        z = emitter_id ^ (signal_hash &+ 0x9e3779b97f4a7c15_u64 &+ (emitter_id << 6) &+ (emitter_id >> 2))
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9_u64
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb_u64
        z ^ (z >> 31)
      end

      # Returns a typed `StaticSignalSlot(*T)` handle bound to `(emitter_id, signal_name)`.
      @[AlwaysInline]
      def slot(emitter_id : UInt64, signal_name : String) : StaticSignalSlot()
        StaticSignalSlot().from_table(self, emitter_id, signal_name, self.class.fnv1a_64(signal_name))
      end

      @[AlwaysInline]
      def slot(emitter_id : UInt64, signal_name : String, t0 : T0.class) : StaticSignalSlot(T0) forall T0
        StaticSignalSlot(T0).from_table(self, emitter_id, signal_name, self.class.fnv1a_64(signal_name))
      end

      @[AlwaysInline]
      def slot(emitter_id : UInt64, signal_name : String, t0 : T0.class, t1 : T1.class) : StaticSignalSlot(T0, T1) forall T0, T1
        StaticSignalSlot(T0, T1).from_table(self, emitter_id, signal_name, self.class.fnv1a_64(signal_name))
      end

      @[AlwaysInline]
      def slot(emitter_id : UInt64, signal_name : String, t0 : T0.class, t1 : T1.class, t2 : T2.class) : StaticSignalSlot(T0, T1, T2) forall T0, T1, T2
        StaticSignalSlot(T0, T1, T2).from_table(self, emitter_id, signal_name, self.class.fnv1a_64(signal_name))
      end

      @[AlwaysInline]
      def slot(emitter_id : UInt64, signal_name : String, t0 : T0.class, t1 : T1.class, t2 : T2.class, t3 : T3.class) : StaticSignalSlot(T0, T1, T2, T3) forall T0, T1, T2, T3
        StaticSignalSlot(T0, T1, T2, T3).from_table(self, emitter_id, signal_name, self.class.fnv1a_64(signal_name))
      end

      # Binds a compile-time typed `Proc(*T, R)` to `(emitter_id, signal_name)`.
      # Returns a unique 64-bit listener token that can be passed to `#unbind`.
      def bind(
        emitter_id : UInt64,
        signal_name : String,
        callback : Proc(*T, R),
        once : Bool = false,
        subscription : ::Godot::SignalSubscription? = nil,
        match_proc_pointer : Pointer(Void) = Pointer(Void).null,
        match_closure_data : Pointer(Void) = Pointer(Void).null,
      ) : UInt64 forall T, R
        sig_hash = self.class.fnv1a_64(signal_name)
        bind_by_hash(
          emitter_id,
          sig_hash,
          callback,
          once: once,
          subscription: subscription,
          match_proc_pointer: match_proc_pointer,
          match_closure_data: match_closure_data
        )
      end

      # Binds a compile-time typed `Proc(*T, R)` using a precomputed `signal_hash`.
      def bind_by_hash(
        emitter_id : UInt64,
        signal_hash : UInt64,
        callback : Proc(*T, R),
        once : Bool = false,
        subscription : ::Godot::SignalSubscription? = nil,
        match_proc_pointer : Pointer(Void) = Pointer(Void).null,
        match_closure_data : Pointer(Void) = Pointer(Void).null,
      ) : UInt64 forall T, R
        slot_idx = find_or_create_slot(emitter_id, signal_hash)
        return 0_u64 if slot_idx < 0

        rec_idx = acquire_listener_record
        return 0_u64 if rec_idx < 0

        token = @next_token
        @next_token &+= 1_u64

        mp = match_proc_pointer.null? ? callback.pointer : match_proc_pointer
        mc = match_proc_pointer.null? ? callback.closure_data : match_closure_data

        rec = SignalListenerRecord.new(
          emitter_id: emitter_id,
          signal_hash: signal_hash,
          proc_pointer: callback.pointer,
          proc_closure_data: callback.closure_data,
          match_proc_pointer: mp,
          match_closure_data: mc,
          raw_callback: nil,
          subscription: subscription,
          token: token,
          slot_index: slot_idx,
          next_index: -1,
          arity: {{ T.size }},
          once: once,
          active: true
        )

        append_record_to_slot(slot_idx, rec_idx, rec)
        token
      end

      # Block-based typed connection helpers (0..4 arguments).
      def connect(emitter_id : UInt64, signal_name : String, once : Bool = false, &block : -> Void) : UInt64
        bind(emitter_id, signal_name, block, once: once)
      end

      def connect(emitter_id : UInt64, signal_name : String, type0 : T0.class, once : Bool = false, &block : T0 -> Void) : UInt64 forall T0
        bind(emitter_id, signal_name, block, once: once)
      end

      def connect(emitter_id : UInt64, signal_name : String, type0 : T0.class, type1 : T1.class, once : Bool = false, &block : (T0, T1) -> Void) : UInt64 forall T0, T1
        bind(emitter_id, signal_name, block, once: once)
      end

      def connect(emitter_id : UInt64, signal_name : String, type0 : T0.class, type1 : T1.class, type2 : T2.class, once : Bool = false, &block : (T0, T1, T2) -> Void) : UInt64 forall T0, T1, T2
        bind(emitter_id, signal_name, block, once: once)
      end

      def connect(emitter_id : UInt64, signal_name : String, type0 : T0.class, type1 : T1.class, type2 : T2.class, type3 : T3.class, once : Bool = false, &block : (T0, T1, T2, T3) -> Void) : UInt64 forall T0, T1, T2, T3
        bind(emitter_id, signal_name, block, once: once)
      end

      # One-shot block connection helpers (0..4 arguments).
      def once(emitter_id : UInt64, signal_name : String, &block : -> Void) : UInt64
        bind(emitter_id, signal_name, block, once: true)
      end

      def once(emitter_id : UInt64, signal_name : String, type0 : T0.class, &block : T0 -> Void) : UInt64 forall T0
        bind(emitter_id, signal_name, block, once: true)
      end

      def once(emitter_id : UInt64, signal_name : String, type0 : T0.class, type1 : T1.class, &block : (T0, T1) -> Void) : UInt64 forall T0, T1
        bind(emitter_id, signal_name, block, once: true)
      end

      def once(emitter_id : UInt64, signal_name : String, type0 : T0.class, type1 : T1.class, type2 : T2.class, &block : (T0, T1, T2) -> Void) : UInt64 forall T0, T1, T2
        bind(emitter_id, signal_name, block, once: true)
      end

      def once(emitter_id : UInt64, signal_name : String, type0 : T0.class, type1 : T1.class, type2 : T2.class, type3 : T3.class, &block : (T0, T1, T2, T3) -> Void) : UInt64 forall T0, T1, T2, T3
        bind(emitter_id, signal_name, block, once: true)
      end

      # Binds a raw C-ABI / arena-staged callback `Proc(UInt64, Pointer(Void), Int32, R)`.
      def bind_raw(emitter_id : UInt64, signal_name : String, callback : Proc(UInt64, Pointer(Void), Int32, R), once : Bool = false) : UInt64 forall R
        sig_hash = self.class.fnv1a_64(signal_name)
        slot_idx = find_or_create_slot(emitter_id, sig_hash)
        return 0_u64 if slot_idx < 0

        rec_idx = acquire_listener_record
        return 0_u64 if rec_idx < 0

        token = @next_token
        @next_token &+= 1_u64

        raw_cb = RawSignalCallback.new(callback.pointer, callback.closure_data)
        rec = SignalListenerRecord.new(
          emitter_id: emitter_id,
          signal_hash: sig_hash,
          proc_pointer: callback.pointer,
          proc_closure_data: callback.closure_data,
          match_proc_pointer: callback.pointer,
          match_closure_data: callback.closure_data,
          raw_callback: raw_cb,
          subscription: nil,
          token: token,
          slot_index: slot_idx,
          next_index: -1,
          arity: -1,
          once: once,
          active: true
        )

        append_record_to_slot(slot_idx, rec_idx, rec)
        token
      end

      # Emits a strongly-typed signal by name with strictly ZERO GC heap allocations.
      # Returns the number of active listeners invoked.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def emit(emitter_id : UInt64, signal_name : String, *args : *T) : Int32 forall T
        sig_hash = self.class.fnv1a_64(signal_name)
        emit_by_hash(emitter_id, sig_hash, *args)
      end

      # Emits a strongly-typed signal using a precomputed 64-bit `signal_hash`
      # with strictly ZERO GC heap allocations.
      @[ZeroAllocation]
      @[HotPath]
      def emit_by_hash(emitter_id : UInt64, signal_hash : UInt64, *args : *T) : Int32 forall T
        return 0 if emitter_id == 0_u64 || @active_slots == 0
        slot_idx = find_slot_index(emitter_id, signal_hash)
        return 0 if slot_idx < 0

        slot = @slots.unsafe_fetch(slot_idx)
        return 0 if slot.active_count <= 0

        slot.emission_count &+= 1_u64
        @slots.unsafe_put(slot_idx, slot)
        @total_emissions &+= 1_u64

        if slot.active_count <= MAX_STACK_SNAPSHOT
          snapshot = uninitialized StaticArray(Int32, MAX_STACK_SNAPSHOT)
          snap_count = collect_active_indices(slot_idx, snapshot.to_unsafe, MAX_STACK_SNAPSHOT)
          return dispatch_typed_indices(emitter_id, snapshot.to_unsafe, snap_count, *args)
        end

        # Overflow path (> 64 listeners on a single signal): stage index buffer in FrameArena
        arena = FrameArena.current
        mark = arena.mark
        overflow_slice = arena.alloc_slice(Int32, slot.active_count)
        snap_count = collect_active_indices(slot_idx, overflow_slice.to_unsafe, overflow_slice.size)
        invoked = dispatch_typed_indices(emitter_id, overflow_slice.to_unsafe, snap_count, *args)
        arena.rewind(mark)
        invoked
      end

      # Emits a raw pointer / byte-sized payload to all `RawSignalCallback` listeners
      # registered on `(emitter_id, signal_name)` with zero GC heap allocations.
      @[ZeroAllocation]
      @[HotPath]
      def emit_raw(
        emitter_id : UInt64,
        signal_name : String,
        payload_ptr : Pointer(Void) = Pointer(Void).null,
        payload_bytes : Int32 = 0,
      ) : Int32
        return 0 if emitter_id == 0_u64 || @active_slots == 0
        sig_hash = self.class.fnv1a_64(signal_name)
        slot_idx = find_slot_index(emitter_id, sig_hash)
        return 0 if slot_idx < 0

        slot = @slots.unsafe_fetch(slot_idx)
        return 0 if slot.active_count <= 0

        slot.emission_count &+= 1_u64
        @slots.unsafe_put(slot_idx, slot)
        @total_emissions &+= 1_u64

        snapshot = uninitialized StaticArray(Int32, MAX_STACK_SNAPSHOT)
        snap_count = collect_active_indices(slot_idx, snapshot.to_unsafe, MAX_STACK_SNAPSHOT)
        invoked = 0
        idx = 0
        while idx < snap_count
          rec_idx = snapshot.to_unsafe[idx]
          rec = @listeners.unsafe_fetch(rec_idx)
          if rec.active
            if sub = rec.subscription
              sub.mark_completed!
            end
            if rec.once
              deactivate_record(slot_idx, rec_idx)
            end
            if raw_cb = rec.raw_callback
              raw_cb.call(emitter_id, payload_ptr, payload_bytes)
              invoked += 1
            elsif rec.arity == 0 && !rec.proc_pointer.null?
              invoke_zero_arg_proc(rec.proc_pointer, rec.proc_closure_data)
              invoked += 1
            end
          end
          idx += 1
        end
        invoked
      end

      # Stages `value : T` into `FrameArena` (linear frame scratchpad) and dispatches
      # both typed `Proc(T, Void)` listeners and raw `RawSignalCallback` listeners
      # receiving the arena-allocated pointer and `sizeof(T)` with zero GC heap allocations.
      @[ZeroAllocation]
      @[HotPath]
      def emit_payload(
        emitter_id : UInt64,
        signal_name : String,
        value : T,
        arena : FrameArena = FrameArena.current,
      ) : Int32 forall T
        return 0 if emitter_id == 0_u64 || @active_slots == 0
        sig_hash = self.class.fnv1a_64(signal_name)
        slot_idx = find_slot_index(emitter_id, sig_hash)
        return 0 if slot_idx < 0

        slot = @slots.unsafe_fetch(slot_idx)
        return 0 if slot.active_count <= 0

        staged_ptr = arena.push(value)
        payload_ptr = to_void_ptr(staged_ptr)
        payload_size = sizeof(T).to_i32

        slot.emission_count &+= 1_u64
        @slots.unsafe_put(slot_idx, slot)
        @total_emissions &+= 1_u64

        snapshot = uninitialized StaticArray(Int32, MAX_STACK_SNAPSHOT)
        snap_count = collect_active_indices(slot_idx, snapshot.to_unsafe, MAX_STACK_SNAPSHOT)
        invoked = 0
        idx = 0
        while idx < snap_count
          rec_idx = snapshot.to_unsafe[idx]
          rec = @listeners.unsafe_fetch(rec_idx)
          if rec.active && is_record_live?(rec)
            if sub = rec.subscription
              sub.mark_completed!
            end
            if rec.once
              deactivate_record(slot_idx, rec_idx)
            end
            if raw_cb = rec.raw_callback
              raw_cb.call(emitter_id, payload_ptr, payload_size)
              invoked += 1
            elsif rec.arity == 1 && !rec.proc_pointer.null?
              invoke_typed_proc(rec.proc_pointer, rec.proc_closure_data, staged_ptr.value)
              invoked += 1
            elsif rec.arity == 0 && !rec.proc_pointer.null?
              invoke_zero_arg_proc(rec.proc_pointer, rec.proc_closure_data)
              invoked += 1
            end
          elsif rec.active
            deactivate_record(slot_idx, rec_idx)
          end
          idx += 1
        end
        invoked
      end

      @[AlwaysInline]
      private def to_void_ptr(ptr : Pointer(T)) : Pointer(Void) forall T
        ptr.as(Pointer(Void))
      end

      # Dispatches 0-arg listeners bound directly to `StaticSignalTable` (without a mirroring
      # `SignalSubscription`) when a signal is emitted via dynamic `Object#emit_signal(name)`.
      @[ZeroAllocation]
      @[HotPath]
      def emit_standalone_zero_arg(emitter_id : UInt64, signal_name : String) : Int32
        return 0 if emitter_id == 0_u64 || @active_slots == 0
        sig_hash = self.class.fnv1a_64(signal_name)
        slot_idx = find_slot_index(emitter_id, sig_hash)
        return 0 if slot_idx < 0

        slot = @slots.unsafe_fetch(slot_idx)
        return 0 if slot.active_count <= 0

        snapshot = uninitialized StaticArray(Int32, MAX_STACK_SNAPSHOT)
        snap_count = collect_active_indices(slot_idx, snapshot.to_unsafe, MAX_STACK_SNAPSHOT)
        invoked = 0
        idx = 0
        while idx < snap_count
          rec_idx = snapshot.to_unsafe[idx]
          rec = @listeners.unsafe_fetch(rec_idx)
          if rec.active && rec.subscription.nil?
            if rec.once
              deactivate_record(slot_idx, rec_idx)
            end
            if rec.arity == 0 && !rec.proc_pointer.null?
              invoke_zero_arg_proc(rec.proc_pointer, rec.proc_closure_data)
              invoked += 1
            elsif raw_cb = rec.raw_callback
              raw_cb.call(emitter_id, Pointer(Void).null, 0)
              invoked += 1
            end
          end
          idx += 1
        end
        if invoked > 0
          slot = @slots.unsafe_fetch(slot_idx)
          slot.emission_count &+= 1_u64
          @slots.unsafe_put(slot_idx, slot)
          @total_emissions &+= 1_u64
        end
        invoked
      end

      # Unbinds a listener by its 64-bit registration token.
      def unbind(token : UInt64) : Bool
        return false if token == 0_u64 || @active_listeners == 0
        idx = 0
        limit = @listener_cursor
        while idx < limit
          rec = @listeners.unsafe_fetch(idx)
          if rec.active && rec.token == token
            deactivate_record(rec.slot_index, idx)
            return true
          end
          idx += 1
        end
        false
      end

      # Unbinds the most recently registered active listener matching `callback`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def unbind_proc(
        emitter_id : UInt64,
        signal_name : String,
        callback : Proc(*T, R),
      ) : Bool forall T, R
        unbind_proc(emitter_id, signal_name, callback.pointer, callback.closure_data)
      end

      # Unbinds the most recently registered active listener matching `callback` by precomputed hash.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def unbind_proc_by_hash(
        emitter_id : UInt64,
        signal_hash : UInt64,
        callback : Proc(*T, R),
      ) : Bool forall T, R
        unbind_proc_by_hash(emitter_id, signal_hash, callback.pointer, callback.closure_data)
      end

      # Unbinds the most recently registered active listener matching `(proc_ptr, closure_ptr)`.
      @[ZeroAllocation]
      @[HotPath]
      def unbind_proc(
        emitter_id : UInt64,
        signal_name : String,
        proc_ptr : Pointer(Void),
        closure_ptr : Pointer(Void),
      ) : Bool
        sig_hash = self.class.fnv1a_64(signal_name)
        unbind_proc_by_hash(emitter_id, sig_hash, proc_ptr, closure_ptr)
      end

      @[ZeroAllocation]
      @[HotPath]
      def unbind_proc_by_hash(
        emitter_id : UInt64,
        signal_hash : UInt64,
        proc_ptr : Pointer(Void),
        closure_ptr : Pointer(Void),
      ) : Bool
        slot_idx = find_slot_index(emitter_id, signal_hash)
        return false if slot_idx < 0

        slot = @slots.unsafe_fetch(slot_idx)
        curr = slot.head_index
        matched_idx = -1
        while curr >= 0
          rec = @listeners.unsafe_fetch(curr)
          if rec.active
            if (rec.match_proc_pointer == proc_ptr && rec.match_closure_data == closure_ptr) ||
               (rec.proc_pointer == proc_ptr && rec.proc_closure_data == closure_ptr)
              matched_idx = curr
            end
          end
          curr = rec.next_index
        end

        if matched_idx >= 0
          deactivate_record(slot_idx, matched_idx)
          return true
        end
        false
      end

      # Unbinds any listener associated with the given `Godot::SignalSubscription`.
      def unbind_subscription(sub : ::Godot::SignalSubscription) : Bool
        return false if @active_listeners == 0
        sig_hash = self.class.fnv1a_64(sub.signal_name)
        slot_idx = find_slot_index(sub.target_id, sig_hash)
        return false if slot_idx < 0

        slot = @slots.unsafe_fetch(slot_idx)
        curr = slot.head_index
        removed = false
        while curr >= 0
          rec = @listeners.unsafe_fetch(curr)
          next_idx = rec.next_index
          if rec.active && rec.subscription.same?(sub)
            deactivate_record(slot_idx, curr)
            removed = true
          end
          curr = next_idx
        end
        removed
      end

      # Clears all listeners registered for `(emitter_id, signal_name)`.
      def clear_signal(emitter_id : UInt64, signal_name : String) : Int32
        sig_hash = self.class.fnv1a_64(signal_name)
        slot_idx = find_slot_index(emitter_id, sig_hash)
        return 0 if slot_idx < 0
        clear_slot_at(slot_idx)
      end

      # Clears all signal slots and listeners associated with `emitter_id` (as emitter or receiver).
      def clear_emitter(emitter_id : UInt64) : Int32
        return 0 if emitter_id == 0_u64 || @active_slots == 0
        removed = 0
        idx = 0
        cap = @slot_capacity
        while idx < cap
          slot = @slots.unsafe_fetch(idx)
          if slot.occupied && slot.active_count > 0
            if slot.emitter_id == emitter_id
              removed += clear_slot_at(idx)
            else
              curr = slot.head_index
              while curr >= 0
                rec = @listeners.unsafe_fetch(curr)
                next_idx = rec.next_index
                if rec.active
                  if sub = rec.subscription
                    if sub.receiver_id == emitter_id
                      deactivate_record(idx, curr)
                      removed += 1
                    end
                  end
                end
                curr = next_idx
              end
            end
          end
          idx += 1
        end
        removed
      end

      # Resets the entire table in-place with zero heap allocations.
      @[ZeroAllocation]
      def clear! : Void
        idx = 0
        cap = @slot_capacity
        while idx < cap
          @slots.unsafe_put(idx, SignalSlotEntry.empty)
          idx += 1
        end

        l_idx = 0
        l_limit = @listener_cursor
        while l_idx < l_limit
          @listeners.unsafe_put(l_idx, SignalListenerRecord.empty)
          l_idx += 1
        end

        @active_slots = 0
        @active_listeners = 0
        @listener_cursor = 0
        @free_listener_head = -1
        @total_emissions = 0_u64
      end

      # Returns the number of active listeners for `(emitter_id, signal_name)`.
      @[ZeroAllocation]
      def active_listener_count(emitter_id : UInt64, signal_name : String) : Int32
        active_listener_count_by_hash(emitter_id, self.class.fnv1a_64(signal_name))
      end

      @[ZeroAllocation]
      def active_listener_count_by_hash(emitter_id : UInt64, signal_hash : UInt64) : Int32
        slot_idx = find_slot_index(emitter_id, signal_hash)
        return 0 if slot_idx < 0
        @slots.unsafe_fetch(slot_idx).active_count
      end

      # Returns the count of active listeners bound directly to `StaticSignalTable`
      # without a mirroring `Godot::SignalSubscription`.
      @[ZeroAllocation]
      def standalone_listener_count(emitter_id : UInt64, signal_name : String) : Int32
        slot_idx = find_slot_index(emitter_id, self.class.fnv1a_64(signal_name))
        return 0 if slot_idx < 0
        slot = @slots.unsafe_fetch(slot_idx)
        count = 0
        curr = slot.head_index
        while curr >= 0
          rec = @listeners.unsafe_fetch(curr)
          if rec.active && rec.subscription.nil?
            count += 1
          end
          curr = rec.next_index
        end
        count
      end

      # Returns `true` if `(emitter_id, signal_name)` has at least one active listener.
      @[ZeroAllocation]
      @[AlwaysInline]
      def has_listeners?(emitter_id : UInt64, signal_name : String) : Bool
        active_listener_count(emitter_id, signal_name) > 0
      end

      # Returns the total number of emissions recorded for `(emitter_id, signal_name)`.
      @[ZeroAllocation]
      def emission_count(emitter_id : UInt64, signal_name : String) : UInt64
        emission_count_by_hash(emitter_id, self.class.fnv1a_64(signal_name))
      end

      @[ZeroAllocation]
      def emission_count_by_hash(emitter_id : UInt64, signal_hash : UInt64) : UInt64
        slot_idx = find_slot_index(emitter_id, signal_hash)
        return 0_u64 if slot_idx < 0
        @slots.unsafe_fetch(slot_idx).emission_count
      end

      # Captures a value-type telemetry snapshot of the table.
      def stats : StaticSignalTableStats
        StaticSignalTableStats.new(
          active_slots: @active_slots,
          active_listeners: @active_listeners,
          total_emissions: @total_emissions,
          slot_capacity: @slot_capacity,
          listener_capacity: @listener_capacity
        )
      end

      # -------------------------------------------------------------------------
      # Internal Zero-Allocation Dispatch & Open-Addressing Helpers
      # -------------------------------------------------------------------------

      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      private def find_slot_index(emitter_id : UInt64, signal_hash : UInt64) : Int32
        probe = self.class.combine_key(emitter_id, signal_hash) & @slot_mask
        steps = 0
        cap = @slot_capacity
        while steps < cap
          idx = probe.to_i32
          entry = @slots.unsafe_fetch(idx)
          return -1 unless entry.occupied
          if entry.emitter_id == emitter_id && entry.signal_hash == signal_hash
            return idx
          end
          probe = (probe &+ 1_u64) & @slot_mask
          steps += 1
        end
        -1
      end

      private def find_or_create_slot(emitter_id : UInt64, signal_hash : UInt64) : Int32
        probe = self.class.combine_key(emitter_id, signal_hash) & @slot_mask
        steps = 0
        cap = @slot_capacity
        while steps < cap
          idx = probe.to_i32
          entry = @slots.unsafe_fetch(idx)
          if !entry.occupied
            entry.occupied = true
            entry.emitter_id = emitter_id
            entry.signal_hash = signal_hash
            entry.head_index = -1
            entry.tail_index = -1
            entry.active_count = 0
            entry.emission_count = 0_u64
            @slots.unsafe_put(idx, entry)
            @active_slots += 1
            return idx
          elsif entry.emitter_id == emitter_id && entry.signal_hash == signal_hash
            return idx
          end
          probe = (probe &+ 1_u64) & @slot_mask
          steps += 1
        end
        -1
      end

      private def acquire_listener_record : Int32
        if @free_listener_head >= 0
          rec_idx = @free_listener_head
          free_rec = @listeners.unsafe_fetch(rec_idx)
          @free_listener_head = free_rec.next_index
          return rec_idx
        end

        if @listener_cursor >= @listener_capacity
          grow_listener_pool(@listener_capacity * 2)
        end

        rec_idx = @listener_cursor
        @listener_cursor += 1
        rec_idx
      end

      private def grow_listener_pool(new_capacity : Int32) : Void
        new_slice = Slice(SignalListenerRecord).new(new_capacity, SignalListenerRecord.empty)
        idx = 0
        while idx < @listener_capacity
          new_slice.unsafe_put(idx, @listeners.unsafe_fetch(idx))
          idx += 1
        end
        @listeners = new_slice
        @listener_capacity = new_capacity
      end

      private def append_record_to_slot(slot_idx : Int32, rec_idx : Int32, rec : SignalListenerRecord) : Void
        slot = @slots.unsafe_fetch(slot_idx)
        if slot.head_index < 0
          slot.head_index = rec_idx
          slot.tail_index = rec_idx
        else
          tail_idx = slot.tail_index
          if tail_idx >= 0
            tail_rec = @listeners.unsafe_fetch(tail_idx)
            tail_rec.next_index = rec_idx
            @listeners.unsafe_put(tail_idx, tail_rec)
          end
          slot.tail_index = rec_idx
        end
        slot.active_count += 1
        @slots.unsafe_put(slot_idx, slot)
        @listeners.unsafe_put(rec_idx, rec)
        @active_listeners += 1
      end

      @[ZeroAllocation]
      @[HotPath]
      private def collect_active_indices(slot_idx : Int32, out_ptr : Pointer(Int32), max_count : Int32) : Int32
        slot = @slots.unsafe_fetch(slot_idx)
        curr = slot.head_index
        count = 0
        while curr >= 0 && count < max_count
          rec = @listeners.unsafe_fetch(curr)
          next_idx = rec.next_index
          if rec.active
            if is_record_live?(rec)
              out_ptr[count] = curr
              count += 1
            else
              deactivate_record(slot_idx, curr)
            end
          end
          curr = next_idx
        end
        count
      end

      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      private def is_record_live?(rec : SignalListenerRecord) : Bool
        if sub = rec.subscription
          return false unless sub.active?
        end
        true
      end

      @[ZeroAllocation]
      @[HotPath]
      private def dispatch_typed_indices(
        emitter_id : UInt64,
        indices_ptr : Pointer(Int32),
        count : Int32,
        *args : *T,
      ) : Int32 forall T
        invoked = 0
        idx = 0
        while idx < count
          rec_idx = indices_ptr[idx]
          rec = @listeners.unsafe_fetch(rec_idx)
          if rec.active && is_record_live?(rec)
            if sub = rec.subscription
              sub.mark_completed!
            end
            if rec.once
              deactivate_record(rec.slot_index, rec_idx)
            end
            if rec.arity == {{ T.size }} && !rec.proc_pointer.null?
              invoke_typed_proc(rec.proc_pointer, rec.proc_closure_data, *args)
              invoked += 1
            elsif rec.arity == 0 && !rec.proc_pointer.null?
              invoke_zero_arg_proc(rec.proc_pointer, rec.proc_closure_data)
              invoked += 1
            elsif raw_cb = rec.raw_callback
              raw_cb.call(emitter_id, Pointer(Void).null, 0)
              invoked += 1
            end
          elsif rec.active
            deactivate_record(rec.slot_index, rec_idx)
          end
          idx += 1
        end
        invoked
      end

      @[AlwaysInline]
      private def invoke_typed_proc(
        proc_ptr : Pointer(Void),
        closure_ptr : Pointer(Void),
        *args : *T,
      ) : Void forall T
        cb = Proc(*T, Void).new(proc_ptr, closure_ptr)
        cb.call(*args)
      end

      @[AlwaysInline]
      private def invoke_zero_arg_proc(
        proc_ptr : Pointer(Void),
        closure_ptr : Pointer(Void),
      ) : Void
        cb = Proc(Void).new(proc_ptr, closure_ptr)
        cb.call
      end

      @[ZeroAllocation]
      private def deactivate_record(slot_idx : Int32, target_rec_idx : Int32) : Void
        rec = @listeners.unsafe_fetch(target_rec_idx)
        return unless rec.active

        if sub = rec.subscription
          sub.mark_unsubscribed!
        end

        slot = @slots.unsafe_fetch(slot_idx)
        prev_idx = -1
        curr = slot.head_index
        while curr >= 0
          curr_rec = @listeners.unsafe_fetch(curr)
          if curr == target_rec_idx
            if prev_idx < 0
              slot.head_index = curr_rec.next_index
            else
              prev_rec = @listeners.unsafe_fetch(prev_idx)
              prev_rec.next_index = curr_rec.next_index
              @listeners.unsafe_put(prev_idx, prev_rec)
            end
            if slot.tail_index == target_rec_idx
              slot.tail_index = prev_idx
            end
            break
          end
          prev_idx = curr
          curr = curr_rec.next_index
        end

        if slot.active_count > 0
          slot.active_count -= 1
        end
        @slots.unsafe_put(slot_idx, slot)

        rec.active = false
        rec.proc_pointer = Pointer(Void).null
        rec.proc_closure_data = Pointer(Void).null
        rec.match_proc_pointer = Pointer(Void).null
        rec.match_closure_data = Pointer(Void).null
        rec.raw_callback = nil
        rec.subscription = nil
        rec.token = 0_u64
        rec.next_index = @free_listener_head
        @listeners.unsafe_put(target_rec_idx, rec)
        @free_listener_head = target_rec_idx

        if @active_listeners > 0
          @active_listeners -= 1
        end
      end

      private def clear_slot_at(slot_idx : Int32) : Int32
        slot = @slots.unsafe_fetch(slot_idx)
        curr = slot.head_index
        removed = 0
        while curr >= 0
          rec = @listeners.unsafe_fetch(curr)
          next_idx = rec.next_index
          if rec.active
            if sub = rec.subscription
              sub.mark_unsubscribed!
            end
            if @active_listeners > 0
              @active_listeners -= 1
            end
            removed += 1
          end
          rec.active = false
          rec.proc_pointer = Pointer(Void).null
          rec.proc_closure_data = Pointer(Void).null
          rec.match_proc_pointer = Pointer(Void).null
          rec.match_closure_data = Pointer(Void).null
          rec.raw_callback = nil
          rec.subscription = nil
          rec.token = 0_u64
          rec.next_index = @free_listener_head
          @listeners.unsafe_put(curr, rec)
          @free_listener_head = curr
          curr = next_idx
        end

        slot.head_index = -1
        slot.tail_index = -1
        slot.active_count = 0
        @slots.unsafe_put(slot_idx, slot)
        removed
      end
    end

    # Stack-allocated, compile-time typed handle to a slot in `StaticSignalTable`.
    #
    # Provides zero-allocation emission (`#emit(*args : *T)`) and direct binding
    # (`#bind`, `#connect`, `#once`, `#+`, `#-`).
    struct StaticSignalSlot(*T)
      getter table : StaticSignalTable
      getter emitter_id : UInt64
      getter name : String
      getter signal_hash : UInt64

      def initialize(
        @name : String = "signal",
        @table : StaticSignalTable = StaticSignalTable.global,
        @emitter_id : UInt64 = StaticSignalTable.next_anonymous_emitter_id,
      )
        @signal_hash = StaticSignalTable.fnv1a_64(@name)
      end

      protected def initialize(
        @table : StaticSignalTable,
        @emitter_id : UInt64,
        @name : String,
        @signal_hash : UInt64,
      )
      end

      @[AlwaysInline]
      def self.from_table(
        table : StaticSignalTable,
        emitter_id : UInt64,
        name : String,
        signal_hash : UInt64,
      ) : self
        new(table, emitter_id, name, signal_hash)
      end

      @[AlwaysInline]
      def self.from_table(
        table : StaticSignalTable,
        emitter_id : UInt64,
        signal_hash : UInt64,
      ) : self
        new(table, emitter_id, "signal", signal_hash)
      end

      # Binds a typed `Proc(*T, R)` directly to this static signal slot.
      @[AlwaysInline]
      def bind(
        callback : Proc(*T, R),
        once : Bool = false,
        subscription : ::Godot::SignalSubscription? = nil,
        match_proc_pointer : Pointer(Void) = Pointer(Void).null,
        match_closure_data : Pointer(Void) = Pointer(Void).null,
      ) : UInt64 forall R
        @table.bind_by_hash(
          @emitter_id,
          @signal_hash,
          callback,
          once: once,
          subscription: subscription,
          match_proc_pointer: match_proc_pointer,
          match_closure_data: match_closure_data
        )
      end

      # Connects a typed block to this static signal slot.
      @[AlwaysInline]
      def connect(once : Bool = false, &block : *T -> Void) : UInt64
        bind(block, once: once)
      end

      # Block overload for `bind` delegating directly to `StaticSignalTable#bind_by_hash`.
      @[AlwaysInline]
      def bind(once : Bool = false, &block : *T -> Void) : UInt64
        bind(block, once: once)
      end

      # Connects a one-shot typed block that automatically unbinds after its first invocation.
      @[AlwaysInline]
      def once(&block : *T -> Void) : UInt64
        bind(block, once: true)
      end

      # Compound operator `+` for subscribing a typed `Proc(*T, R)`.
      @[AlwaysInline]
      def +(callback : Proc(*T, R)) : self forall R
        bind(callback)
        self
      end

      # Compound operator `-` for unbinding a typed `Proc(*T, R)`.
      @[AlwaysInline]
      def -(callback : Proc(*T, R)) : self forall R
        @table.unbind_proc_by_hash(@emitter_id, @signal_hash, callback.pointer, callback.closure_data)
        self
      end

      # Emits `*args` to all active listeners in this slot with zero GC heap allocations.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def emit(*args : *T) : Int32
        @table.emit_by_hash(@emitter_id, @signal_hash, *args)
      end

      # Unbinds a listener by its 64-bit token.
      @[AlwaysInline]
      def unbind(token : UInt64) : Bool
        @table.unbind(token)
      end

      # Unbinds the most recently registered listener matching `callback`.
      @[AlwaysInline]
      def unbind(callback : Proc(*T, R)) : Bool forall R
        @table.unbind_proc_by_hash(@emitter_id, @signal_hash, callback.pointer, callback.closure_data)
      end

      # Clears all listeners registered in this slot.
      @[AlwaysInline]
      def clear! : Int32
        @table.clear_signal(@emitter_id, @name)
      end

      # Returns the number of active listeners bound to this slot.
      @[ZeroAllocation]
      @[AlwaysInline]
      def active_count : Int32
        @table.active_listener_count_by_hash(@emitter_id, @signal_hash)
      end

      # Returns `true` if no listeners are currently bound to this slot.
      @[ZeroAllocation]
      @[AlwaysInline]
      def empty? : Bool
        active_count == 0
      end

      # Returns `true` if at least one listener is currently bound to this slot.
      @[ZeroAllocation]
      @[AlwaysInline]
      def connected? : Bool
        active_count > 0
      end

      # Returns the total number of emissions dispatched through this slot.
      @[ZeroAllocation]
      @[AlwaysInline]
      def emission_count : UInt64
        @table.emission_count_by_hash(@emitter_id, @signal_hash)
      end
    end
  end

  alias StaticSignalTable = Core::StaticSignalTable
  alias StaticSignalSlot = Core::StaticSignalSlot
  alias StaticSignalTableStats = Core::StaticSignalTableStats
end

module Godot
  alias StaticSignalTable = ::Lapis::Core::StaticSignalTable
  alias StaticSignalSlot = ::Lapis::Core::StaticSignalSlot
  alias StaticSignalTableStats = ::Lapis::Core::StaticSignalTableStats
end
