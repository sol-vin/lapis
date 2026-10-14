# =============================================================================
# Lapis Declarative DSL Layer (Tier 2) — FrameArena & StaticSignalTable Builders
# =============================================================================
# Ergonomic builders and node-level helpers wrapping Tier 1 `Lapis::Core::FrameArena`
# and `Lapis::Core::StaticSignalTable` in accordance with the Two-Tier DSL Codex.
#
# Work Order: WO-064 ([AS-1])
# Specialist: Gamma (Godot Lead Engineer)
# Target Branch: 4.8-dev7
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
  end
end
