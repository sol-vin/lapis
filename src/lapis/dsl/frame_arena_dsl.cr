# =============================================================================
# Lapis Declarative DSL Layer (Tier 2) — FrameArena & StaticSignalTable Builders
# =============================================================================
# Ergonomic builders and node-level helpers wrapping Tier 1 `Lapis::Core::FrameArena`
# and `Lapis::Core::StaticSignalTable` in accordance with the Two-Tier DSL Codex.
#
# Work Orders: WO-064 ([AS-1]) & WO-065 ([AS-2])
# Specialists: Gamma (Godot Lead Engineer) & Alpha (Principal Systems Architect)
# Target Branch: 4.8-beta1
# =============================================================================

require "../core"

module Lapis
  module DSL
    # Declarative configuration builder for `Lapis::Core::FrameArena`.
    struct FrameArenaBuilder
      getter capacity : Int32
      getter arena : ::Lapis::Core::FrameArena

      def initialize(@arena : ::Lapis::Core::FrameArena = ::Lapis::Core::FrameArena.current)
        @capacity = @arena.capacity
      end

      # Allocates a typed contiguous `Slice(T)` from the underlying `FrameArena`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def slice(type : T.class, count : Int32) : Slice(T) forall T
        @arena.alloc_slice(type, count)
      end

      # Allocates a bounded appendable `ArenaBuffer(T)` from the underlying `FrameArena`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def buffer(type : T.class, max_elements : Int32) : ::Lapis::Core::ArenaBuffer(T) forall T
        @arena.buffer(type, max_elements)
      end

      # Copies `value` into the arena and returns a typed `Pointer(T)`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def push(value : T) : Pointer(T) forall T
        @arena.push(value)
      end

      # Executes a nested sub-frame scope that automatically rewinds on block exit.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def scope(&block : ::Lapis::Core::FrameArena -> _)
        @arena.scope do |inner|
          yield inner
        end
      end

      # Resets the arena cursor to zero and advances the frame counter.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def tick! : ::Lapis::Core::FrameArena
        @arena.tick!
      end

      # Resets the arena cursor to zero without advancing the frame counter.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def reset! : ::Lapis::Core::FrameArena
        @arena.reset!
      end
    end

    # Declarative builder wrapping Tier 1 `Lapis::Core::StaticSignalTable` for
    # compile-time typed proc binding, slot construction, and zero-allocation emission.
    struct StaticSignalBuilder
      getter table : ::Lapis::Core::StaticSignalTable

      def initialize(@table : ::Lapis::Core::StaticSignalTable = ::Lapis::Core::StaticSignalTable.global)
      end

      # Returns a typed `StaticSignalSlot(*T)` bound to `(emitter_id, signal_name)`.
      @[AlwaysInline]
      def slot(emitter_id : UInt64, signal_name : String, *types : *T) forall T
        @table.slot(emitter_id, signal_name, *types)
      end

      # Returns a typed `StaticSignalSlot(*T)` bound to `(emitter, signal_name)`.
      @[AlwaysInline]
      def slot(emitter : ::Godot::Object, signal_name : String | Symbol, *types : *T) forall T
        @table.slot(emitter.signal_target_id, signal_name.to_s, *types)
      end

      # Binds a compile-time typed `Proc(*T, R)` to `(emitter_id, signal_name)`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def bind(emitter_id : UInt64, signal_name : String, callback : Proc(*T, R), once : Bool = false) : UInt64 forall T, R
        @table.bind(emitter_id, signal_name, callback, once: once)
      end

      # Binds a compile-time typed `Proc(*T, R)` to `(emitter, signal_name)`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def bind(emitter : ::Godot::Object, signal_name : String, callback : Proc(*T, R), once : Bool = false) : UInt64 forall T, R
        @table.bind(emitter.signal_target_id, signal_name, callback, once: once)
      end

      # Binds a compile-time typed `Proc(*T, R)` to `(emitter_id, signal_hash)`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def bind_by_hash(emitter_id : UInt64, signal_hash : UInt64, callback : Proc(*T, R), once : Bool = false) : UInt64 forall T, R
        @table.bind_by_hash(emitter_id, signal_hash, callback, once: once)
      end

      # Unbinds a listener slot by `token`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def unbind(token : UInt64) : Bool
        @table.unbind(token)
      end

      # Unbinds a matching `Proc(*T, R)` from `(emitter_id, signal_name)`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def unbind(emitter_id : UInt64, signal_name : String, callback : Proc(*T, R)) : Bool forall T, R
        @table.unbind_proc(emitter_id, signal_name, callback)
      end

      # Unbinds a matching `Proc(*T, R)` from `(emitter, signal_name)`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def unbind(emitter : ::Godot::Object, signal_name : String, callback : Proc(*T, R)) : Bool forall T, R
        @table.unbind_proc(emitter.signal_target_id, signal_name, callback)
      end

      # Emits `(emitter_id, signal_name)` with `*args` with strictly zero GC heap allocations.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def emit(emitter_id : UInt64, signal_name : String, *args : *T) : Int32 forall T
        @table.emit(emitter_id, signal_name, *args)
      end

      # Emits `(emitter, signal_name)` with `*args` with strictly zero GC heap allocations.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def emit(emitter : ::Godot::Object, signal_name : String, *args : *T) : Int32 forall T
        @table.emit(emitter.signal_target_id, signal_name, *args)
      end

      # Clears all signal bindings for `emitter_id`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def clear_emitter(emitter_id : UInt64) : Int32
        @table.clear_emitter(emitter_id)
      end

      # Clears all signal bindings for `emitter`.
      @[ZeroAllocation]
      @[HotPath]
      @[AlwaysInline]
      def clear_emitter(emitter : ::Godot::Object) : Int32
        @table.clear_emitter(emitter.signal_target_id)
      end
    end
  end

  # Executes a scoped scratchpad block on `Lapis::Core::FrameArena.current`,
  # rewinding the arena cursor to its previous mark when the block exits.
  @[ZeroAllocation]
  @[HotPath]
  @[AlwaysInline]
  def self.frame_scope(&block : Core::FrameArena -> _)
    Core::FrameArena.scope do |arena|
      yield arena
    end
  end

  # Yields a declarative `FrameArenaBuilder` for the current thread's `FrameArena`.
  @[AlwaysInline]
  def self.frame_arena(&block : DSL::FrameArenaBuilder -> _)
    builder = DSL::FrameArenaBuilder.new(Core::FrameArena.current)
    yield builder
  end

  # Returns the current thread's `Lapis::Core::FrameArena`.
  @[ZeroAllocation]
  @[HotPath]
  @[AlwaysInline]
  def self.frame_arena : Core::FrameArena
    Core::FrameArena.current
  end

  # Advances the global `FrameArena` tick (resets cursor to 0 and increments `frame_id`).
  @[ZeroAllocation]
  @[HotPath]
  @[AlwaysInline]
  def self.tick_frame_arena! : Core::FrameArena
    Core::FrameArena.tick!
  end

  # Yields a declarative `StaticSignalBuilder` wrapping `Lapis::Core::StaticSignalTable`.
  @[AlwaysInline]
  def self.static_signals(table : Core::StaticSignalTable = Core::StaticSignalTable.global, &block : DSL::StaticSignalBuilder -> _)
    builder = DSL::StaticSignalBuilder.new(table)
    yield builder
  end

  # Returns the global `Lapis::Core::StaticSignalTable`.
  @[ZeroAllocation]
  @[HotPath]
  @[AlwaysInline]
  def self.static_signals : Core::StaticSignalTable
    Core::StaticSignalTable.global
  end
end

module Godot
  class Object
    # Returns the active `Lapis::Core::FrameArena` scratchpad for the current frame.
    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def frame_arena : ::Lapis::Core::FrameArena
      ::Lapis::Core::FrameArena.current
    end

    # Executes a temporary scratch allocation scope on the current `FrameArena`
    # that automatically rewinds when the block finishes.
    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def frame_scope(&block : ::Lapis::Core::FrameArena -> _)
      ::Lapis::Core::FrameArena.scope do |arena|
        yield arena
      end
    end

    # Allocates a per-frame scratch `Slice(T)` of `count` elements from `FrameArena.current`.
    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def frame_slice(type : T.class, count : Int32) : Slice(T) forall T
      ::Lapis::Core::FrameArena.alloc_slice(type, count)
    end

    # Allocates a per-frame appendable `ArenaBuffer(T)` of `max_elements` from `FrameArena.current`.
    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def frame_buffer(type : T.class, max_elements : Int32) : ::Lapis::Core::ArenaBuffer(T) forall T
      ::Lapis::Core::FrameArena.buffer(type, max_elements)
    end

    # Returns a compile-time typed `StaticSignalSlot(*T)` bound to this object in `StaticSignalTable.global`.
    @[AlwaysInline]
    def static_signal_slot(signal_name : String, *types : *T) forall T
      ::Lapis::Core::StaticSignalTable.global.slot(signal_target_id, signal_name, *types)
    end

    # Returns a compile-time typed `StaticSignalSlot(*T)` bound to this object by symbol name.
    @[AlwaysInline]
    def static_signal_slot(signal_name : Symbol, *types : *T) forall T
      static_signal_slot(signal_name.to_s, *types)
    end

    # Binds a compile-time typed `Proc(*T, R)` directly to this object's `StaticSignalTable` slot.
    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def bind_static_signal(signal_name : String, callback : Proc(*T, R), once : Bool = false) : UInt64 forall T, R
      ::Lapis::Core::StaticSignalTable.global.bind(signal_target_id, signal_name, callback, once: once)
    end

    # Binds a compile-time typed `Proc(*T, R)` directly to this object's `StaticSignalTable` slot (Symbol overload).
    @[AlwaysInline]
    def bind_static_signal(signal_name : Symbol, callback : Proc(*T, R), once : Bool = false) : UInt64 forall T, R
      bind_static_signal(signal_name.to_s, callback, once: once)
    end

    # Unbinds a `StaticSignalTable` listener token.
    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def unbind_static_signal(token : UInt64) : Bool
      ::Lapis::Core::StaticSignalTable.global.unbind(token)
    end

    # Unbinds a matching compile-time typed `Proc(*T, R)` from this object's `StaticSignalTable` slot.
    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def unbind_static_signal(signal_name : String, callback : Proc(*T, R)) : Bool forall T, R
      ::Lapis::Core::StaticSignalTable.global.unbind_proc(signal_target_id, signal_name, callback)
    end

    # Unbinds a matching compile-time typed `Proc(*T, R)` from this object's `StaticSignalTable` slot (Symbol overload).
    @[AlwaysInline]
    def unbind_static_signal(signal_name : Symbol, callback : Proc(*T, R)) : Bool forall T, R
      unbind_static_signal(signal_name.to_s, callback)
    end

    # Emits a typed signal directly through `StaticSignalTable.global` with zero GC heap allocations.
    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def emit_static_signal(signal_name : String, *args : *T) : Int32 forall T
      ::Lapis::Core::StaticSignalTable.global.emit(signal_target_id, signal_name, *args)
    end

    # Emits a typed signal directly through `StaticSignalTable.global` (Symbol overload).
    @[AlwaysInline]
    def emit_static_signal(signal_name : Symbol, *args : *T) : Int32 forall T
      emit_static_signal(signal_name.to_s, *args)
    end
  end
end
