# =============================================================================
# Lapis Core Engine Tier: Linear Frame Scratchpad Allocator (FrameArena)
# =============================================================================
# Provides a deterministic, fixed-capacity pointer-bump frame arena allocator
# that resets in O(1) at the end of each engine tick (`tick!` / `reset!`).
# Eliminates Boehm GC heap allocations for per-frame signal payloads, immediate
# debug geometry batches (Diorite), and transient frame scratch buffers.
#
# Assigned Specialist: Gamma (Godot 4.8 GDExtension Lead)
# Work Order: WO-064 ([AS-1])
# =============================================================================

module Lapis
  module Core
    # Value-type telemetry snapshot of a `FrameArena` at a point in time.
    struct FrameArenaStats
      getter capacity : Int32
      getter offset : Int32
      getter remaining : Int32
      getter high_water_mark : Int32
      getter frame_count : UInt64
      getter allocation_count : Int32
      getter total_allocations : UInt64
      getter overflow_count : UInt64

      def initialize(
        @capacity : Int32,
        @offset : Int32,
        @remaining : Int32,
        @high_water_mark : Int32,
        @frame_count : UInt64,
        @allocation_count : Int32,
        @total_allocations : UInt64,
        @overflow_count : UInt64
      )
      end

      def utilization : Float64
        @capacity > 0 ? (@offset.to_f64 / @capacity.to_f64) : 0.0
      end

      def peak_utilization : Float64
        @capacity > 0 ? (@high_water_mark.to_f64 / @capacity.to_f64) : 0.0
      end
    end

    # Stack-allocated, zero-GC appendable typed buffer view backed by a `Slice(T)`
    # carved out of a `FrameArena`. Ideal for building per-frame vertex, color,
    # and line batches in `sol-vin/diorite` or signal argument scratch arrays.
    struct ArenaBuffer(T)
      getter raw_slice : Slice(T)
      getter size : Int32

      def initialize(@raw_slice : Slice(T), @size : Int32 = 0)
      end

      def self.from_slice(slice : Slice(T), size : Int32 = 0) : ArenaBuffer(T)
        new(slice, size)
      end

      @[ZeroAllocation]
      def capacity : Int32
        @raw_slice.size
      end

      @[ZeroAllocation]
      def remaining : Int32
        @raw_slice.size - @size
      end

      @[ZeroAllocation]
      def empty? : Bool
        @size == 0
      end

      @[ZeroAllocation]
      def full? : Bool
        @size >= @raw_slice.size
      end

      # Appends a single element to the arena buffer if space remains.
      # Returns true if written, false if capacity was reached.
      @[ZeroAllocation]
      def push(value : T) : Bool
        if @size < @raw_slice.size
          @raw_slice.to_unsafe[@size] = value
          @size += 1
          true
        else
          false
        end
      end

      # Fluent append operator (`buf << item`).
      @[ZeroAllocation]
      def <<(value : T) : self
        push(value)
        self
      end

      # Appends a pair of elements (e.g. start/end vertices for a 2D/3D line segment)
      # atomically if at least 2 slots remain.
      @[ZeroAllocation]
      def push_line(a : T, b : T) : Bool
        if @size + 2 <= @raw_slice.size
          ptr = @raw_slice.to_unsafe
          ptr[@size] = a
          ptr[@size + 1] = b
          @size += 2
          true
        else
          false
        end
      end

      @[ZeroAllocation]
      def unsafe_fetch(index : Int32) : T
        @raw_slice.to_unsafe[index]
      end

      @[ZeroAllocation]
      def [](index : Int32) : T
        @raw_slice.to_unsafe[index]
      end

      @[ZeroAllocation]
      def []?(index : Int32) : T?
        if index >= 0 && index < @size
          @raw_slice.to_unsafe[index]
        else
          nil
        end
      end

      @[ZeroAllocation]
      def []=(index : Int32, value : T) : T
        if index >= 0 && index < @size
          @raw_slice.to_unsafe[index] = value
        end
        value
      end

      # Resets the logical element count to 0 while retaining the underlying slice capacity.
      @[ZeroAllocation]
      def clear : self
        @size = 0
        self
      end

      # Returns a zero-allocation `Slice(T)` view over the written elements (`0...@size`).
      @[ZeroAllocation]
      def to_slice : Slice(T)
        Slice(T).new(@raw_slice.to_unsafe, @size)
      end

      @[ZeroAllocation]
      def to_unsafe : Pointer(T)
        @raw_slice.to_unsafe
      end

      @[ZeroAllocation]
      def each(& : T ->) : Nil
        i = 0
        ptr = @raw_slice.to_unsafe
        while i < @size
          yield ptr[i]
          i += 1
        end
      end
    end

    # Linear pointer-bump frame scratchpad allocator reset once per tick.
    #
    # All hot-path allocation methods (`alloc_bytes`, `alloc_slice`, `alloc_ptr`, `push`,
    # `copy_slice`, `copy_array`, `mark`, `rewind`, `reset!`, `tick!`) execute with
    # strictly ZERO GC heap allocations.
    class FrameArena
      DEFAULT_CAPACITY  = 1_048_576 # 1 MiB default frame scratchpad
      DEFAULT_ALIGNMENT =         8

      getter capacity : Int32
      getter offset : Int32 = 0
      getter high_water_mark : Int32 = 0
      getter frame_count : UInt64 = 0_u64
      getter allocation_count : Int32 = 0
      getter total_allocations : UInt64 = 0_u64
      getter overflow_count : UInt64 = 0_u64

      @buffer : Bytes

      @@current : FrameArena = FrameArena.new(DEFAULT_CAPACITY)

      # Returns the default active frame arena instance.
      @[ZeroAllocation]
      def self.current : FrameArena
        @@current
      end

      # Replaces or reconfigures the default frame arena with the given byte capacity.
      def self.configure(capacity : Int32 = DEFAULT_CAPACITY) : FrameArena
        @@current = FrameArena.new(capacity)
        @@current
      end

      # Resets the default frame arena for a new engine tick, incrementing its frame counter.
      @[ZeroAllocation]
      def self.tick! : FrameArena
        @@current.tick!
      end

      # Resets the default frame arena offset to zero without advancing the frame counter.
      @[ZeroAllocation]
      def self.reset! : FrameArena
        @@current.reset!
      end

      # Executes a block with the default frame arena and automatically calls `tick!` on completion.
      @[ZeroAllocation]
      def self.frame(&) : FrameArena
        arena = @@current
        yield arena
        arena.tick!
        arena
      end

      # Executes a scoped checkpoint block on the default frame arena, rewinding the bump pointer on exit.
      @[ZeroAllocation]
      def self.scope(&) : FrameArena
        arena = @@current
        m = arena.mark
        yield arena
        arena.rewind(m)
        arena
      end

      # Allocates a typed slice from the default frame arena.
      @[ZeroAllocation]
      def self.alloc_slice(type : T.class, count : Int32, *, alignment : Int32 = DEFAULT_ALIGNMENT) : Slice(T) forall T
        @@current.alloc_slice(T, count, alignment: alignment)
      end

      # Allocates an appendable `ArenaBuffer(T)` from the default frame arena.
      def self.buffer(type : T.class, capacity : Int32, alignment : Int32 = DEFAULT_ALIGNMENT) : ArenaBuffer(T) forall T
        @@current.buffer(T, capacity, alignment)
      end

      # Aligns `offset` upward to the nearest multiple of `alignment`.
      @[ZeroAllocation]
      def self.align_up(offset : Int32, alignment : Int32 = DEFAULT_ALIGNMENT) : Int32
        align = alignment > 1 ? alignment : 1
        mask = align - 1
        if (align & mask) == 0
          (offset + mask) & ~mask
        else
          rem = offset % align
          rem == 0 ? offset : offset + (align - rem)
        end
      end

      def initialize(capacity : Int32 = DEFAULT_CAPACITY)
        cap = capacity > 64 ? capacity : 64
        @capacity = cap
        @buffer = Bytes.new(cap)
      end

      # Bytes currently consumed in the active frame.
      @[ZeroAllocation]
      def used : Int32
        @offset
      end

      # Alias for `used`.
      @[ZeroAllocation]
      def bytes_used : Int32
        @offset
      end

      # Bytes remaining before the arena reaches capacity.
      @[ZeroAllocation]
      def remaining : Int32
        @capacity - @offset
      end

      # Alias for `remaining`.
      @[ZeroAllocation]
      def bytes_remaining : Int32
        @capacity - @offset
      end

      # Alias for `high_water_mark`.
      @[ZeroAllocation]
      def peak_bytes : Int32
        @high_water_mark
      end

      # Alias for `frame_count`.
      @[ZeroAllocation]
      def tick_count : UInt64
        @frame_count
      end

      # Returns true if no bytes are currently allocated in this frame.
      @[ZeroAllocation]
      def empty? : Bool
        @offset == 0
      end

      # Current frame utilization ratio (`0.0..1.0`).
      @[ZeroAllocation]
      def utilization : Float64
        @capacity > 0 ? (@offset.to_f64 / @capacity.to_f64) : 0.0
      end

      # Checks whether `size` bytes with `alignment` can fit in the remaining capacity.
      @[ZeroAllocation]
      def can_allocate?(size : Int32, alignment : Int32 = DEFAULT_ALIGNMENT) : Bool
        return false if size < 0
        return true if size == 0
        aligned = FrameArena.align_up(@offset, alignment)
        aligned + size <= @capacity
      end

      # Carves a contiguous `Bytes` slice of `size` bytes aligned to `alignment`.
      # Returns `Bytes.empty` and increments `overflow_count` if capacity is exceeded.
      @[ZeroAllocation]
      def alloc_bytes(size : Int32, alignment : Int32 = DEFAULT_ALIGNMENT) : Bytes
        return Bytes.empty if size <= 0
        aligned = FrameArena.align_up(@offset, alignment)
        next_offset = aligned + size
        if next_offset > @capacity
          @overflow_count += 1_u64
          return Bytes.empty
        end

        @offset = next_offset
        if next_offset > @high_water_mark
          @high_water_mark = next_offset
        end
        @allocation_count += 1
        @total_allocations += 1_u64
        Bytes.new(@buffer.to_unsafe + aligned, size)
      end

      # Carves a contiguous `Slice(T)` of `count` elements from the linear scratchpad.
      # Returns `Slice(T).empty` if `count <= 0` or capacity is exceeded.
      @[ZeroAllocation]
      def alloc_slice(type : T.class, count : Int32, *, alignment : Int32 = DEFAULT_ALIGNMENT) : Slice(T) forall T
        return Slice(T).empty if count <= 0
        elem_size = sizeof(T)
        byte_size = elem_size * count
        eff_align = alignment >= alignof(T) ? alignment : alignof(T)
        raw = alloc_bytes(byte_size, eff_align)
        return Slice(T).empty if raw.size < byte_size
        raw_bytes_to_slice(T, raw, count)
      end

      @[AlwaysInline]
      private def raw_bytes_to_slice(type : T.class, raw : Bytes, count : Int32) : Slice(T) forall T
        Slice(T).new(raw.to_unsafe.as(Pointer(T)), count)
      end

      # Carves a contiguous `Slice(T)` of `count` elements and initializes every slot to `value`.
      @[ZeroAllocation]
      def alloc_slice(type : T.class, count : Int32, value : T, *, alignment : Int32 = DEFAULT_ALIGNMENT) : Slice(T) forall T
        s = alloc_slice(T, count, alignment: alignment)
        ptr = s.to_unsafe
        i = 0
        n = s.size
        while i < n
          ptr[i] = value
          i += 1
        end
        s
      end

      # Carves space for `count` elements of `T` and returns a typed `Pointer(T)`
      # (or `Pointer(T).null` if capacity is exceeded).
      @[ZeroAllocation]
      def alloc_ptr(type : T.class, count : Int32 = 1, alignment : Int32 = DEFAULT_ALIGNMENT) : Pointer(T) forall T
        s = alloc_slice(T, count, alignment: alignment)
        s.empty? ? Pointer(T).null : s.to_unsafe
      end

      # Writes a single value `T` into the arena and returns a `Pointer(T)` to its slot.
      @[ZeroAllocation]
      def push(value : T, alignment : Int32 = DEFAULT_ALIGNMENT) : Pointer(T) forall T
        ptr = alloc_ptr(T, 1, alignment)
        unless ptr.null?
          ptr.value = value
        end
        ptr
      end

      # Copies a `Slice(T)` into the frame arena and returns the arena-backed `Slice(T)`.
      @[ZeroAllocation]
      def copy_slice(src : Slice(T), alignment : Int32 = DEFAULT_ALIGNMENT) : Slice(T) forall T
        n = src.size
        return Slice(T).empty if n == 0
        dst = alloc_slice(T, n, alignment: alignment)
        return Slice(T).empty if dst.size < n
        src_ptr = src.to_unsafe
        dst_ptr = dst.to_unsafe
        i = 0
        while i < n
          dst_ptr[i] = src_ptr[i]
          i += 1
        end
        dst
      end

      # Copies an `Array(T)` into the frame arena and returns the arena-backed `Slice(T)`.
      @[ZeroAllocation]
      def copy_array(src : Array(T), alignment : Int32 = DEFAULT_ALIGNMENT) : Slice(T) forall T
        n = src.size
        return Slice(T).empty if n == 0
        dst = alloc_slice(T, n, alignment: alignment)
        return Slice(T).empty if dst.size < n
        src_ptr = src.to_unsafe
        dst_ptr = dst.to_unsafe
        i = 0
        while i < n
          dst_ptr[i] = src_ptr[i]
          i += 1
        end
        dst
      end

      # Carves an appendable `ArenaBuffer(T)` with fixed `capacity` from the frame arena.
      def buffer(type : T.class, capacity : Int32, alignment : Int32 = DEFAULT_ALIGNMENT) : ArenaBuffer(T) forall T
        s = alloc_slice(T, capacity, alignment: alignment)
        ArenaBuffer(T).from_slice(s, 0)
      end

      # Returns the current bump pointer offset for later `rewind`.
      @[ZeroAllocation]
      def mark : Int32
        @offset
      end

      # Rewinds the bump pointer to a previous `mark_offset` within `[0, @offset]`.
      @[ZeroAllocation]
      def rewind(mark_offset : Int32) : self
        if mark_offset >= 0 && mark_offset <= @offset
          @offset = mark_offset
        end
        self
      end

      # Executes a nested block and rewinds the arena bump pointer back to its pre-block mark.
      @[ZeroAllocation]
      def scope(&) : self
        m = @offset
        yield self
        @offset = m
        self
      end

      # Resets the linear scratchpad offset and per-frame allocation counter in O(1) time.
      @[ZeroAllocation]
      def reset! : self
        @offset = 0
        @allocation_count = 0
        self
      end

      # Advances the frame tick counter and resets the bump pointer to 0 in O(1) time.
      @[ZeroAllocation]
      def tick! : self
        @frame_count += 1_u64
        @offset = 0
        @allocation_count = 0
        self
      end

      # Alias for `tick!` (scanned by the Zero-Allocation AST Linter as a hot-path tick method).
      @[ZeroAllocation]
      def tick : self
        tick!
      end

      # Alias for `reset!`.
      @[ZeroAllocation]
      def clear! : self
        reset!
      end

      # Resets both the active bump pointer and all historical telemetry counters.
      @[ZeroAllocation]
      def reset_stats! : self
        @offset = 0
        @high_water_mark = 0
        @frame_count = 0_u64
        @allocation_count = 0
        @total_allocations = 0_u64
        @overflow_count = 0_u64
        self
      end

      # Captures a value-struct telemetry snapshot of this arena.
      def stats : FrameArenaStats
        FrameArenaStats.new(
          capacity: @capacity,
          offset: @offset,
          remaining: @capacity - @offset,
          high_water_mark: @high_water_mark,
          frame_count: @frame_count,
          allocation_count: @allocation_count,
          total_allocations: @total_allocations,
          overflow_count: @overflow_count
        )
      end
    end
  end

  alias FrameArena = Core::FrameArena
  alias ArenaBuffer = Core::ArenaBuffer
  alias FrameArenaStats = Core::FrameArenaStats
end

module Godot
  alias FrameArena = ::Lapis::Core::FrameArena
  alias ArenaBuffer = ::Lapis::Core::ArenaBuffer
  alias FrameArenaStats = ::Lapis::Core::FrameArenaStats
end
