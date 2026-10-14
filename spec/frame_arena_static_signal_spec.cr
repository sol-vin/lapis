# =============================================================================
# Lapis::Core::FrameArena & StaticSignalTable — Zero-Allocation Spec Suite
# =============================================================================
# Verifies:
# 1. Lapis::Core::FrameArena linear bump-pointer allocation, alignment, mark/rewind,
#    scoped checkpoints, ArenaBuffer(T), overflow counters, and per-tick O(1) reset.
# 2. Lapis::Core::StaticSignalTable & StaticSignalSlot(*T) compile-time typed proc
#    binding, raw C-ABI callback dispatch, FrameArena-staged payload broadcasts,
#    one-shot listeners, token/proc unbinding, and >64 listener overflow handling.
# 3. TypedSignal(*T), `signal` macro, `on_signal` macro, and `Object#emit_signal`
#    executing with strictly ZERO GC heap allocations on signal emission.
#
# Assigned Specialist: Gamma (Godot Lead Engineer)
# Work Order: WO-064 ([AS-1])
# Target Branch: 4.8-dev7
# =============================================================================

require "./spec_helper"

class ArenaSignalTestNode < Godot::Node
  signal zero_arg_triggered
  signal health_changed(new_health : Int32, max_health : Int32)
  signal position_updated(pos : Godot::Vector3)
  signal complex_event(code : Int32, factor : Float64, vec : Godot::Vector2)
end

record DamageEventPayload,
  attacker_id : UInt64,
  damage : Int32,
  critical : Bool

describe "WO-064: Lapis::Core::FrameArena & StaticSignalTable (Zero-Allocation)" do
  describe "Lapis::Core::FrameArena (Tier 1 Core Engine)" do
    it "allocates aligned byte slices, typed slices, and pointers with O(1) per-tick reset" do
      arena = Lapis::Core::FrameArena.new(4096)
      arena.capacity.should eq(4096)
      arena.used.should eq(0)
      arena.empty?.should be_true
      arena.frame_count.should eq(0_u64)

      bytes = arena.alloc_bytes(24, alignment: 16)
      bytes.size.should eq(24)
      arena.used.should eq(24)

      floats = arena.alloc_slice(Float32, 8, 1.5_f32)
      floats.size.should eq(8)
      floats[0].should eq(1.5_f32)
      floats[7].should eq(1.5_f32)
      # 24 aligned up to 4/16 + 32 bytes
      arena.used.should be >= 56

      ptr = arena.push(Godot::Vector3.new(10.0_f32, 20.0_f32, 30.0_f32))
      ptr.null?.should be_false
      ptr.value.x.should eq(10.0_f32)
      ptr.value.y.should eq(20.0_f32)
      ptr.value.z.should eq(30.0_f32)

      peak = arena.peak_bytes
      peak.should be > 0

      arena.tick!
      arena.used.should eq(0)
      arena.empty?.should be_true
      arena.frame_count.should eq(1_u64)
      arena.peak_bytes.should eq(peak)
    end

    it "supports mark, rewind, and nested scope checkpoints without heap allocation" do
      arena = Lapis::Core::FrameArena.new(4096)
      base_slice = arena.alloc_slice(Int32, 4, 42)
      mark_pos = arena.mark
      mark_pos.should eq(16)

      arena.scope do |inner|
        temp = inner.alloc_slice(Int64, 16, 99_i64)
        temp.size.should eq(16)
        inner.used.should be > mark_pos
      end

      arena.used.should eq(mark_pos)
      base_slice[0].should eq(42)
      base_slice[3].should eq(42)
    end

    it "provides ArenaBuffer(T) for immediate-mode vertex and line batching" do
      arena = Lapis::Core::FrameArena.new(8192)
      buf = arena.buffer(Godot::Vector3, 16)
      buf.capacity.should eq(16)
      buf.size.should eq(0)
      buf.empty?.should be_true

      p1 = Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)
      p2 = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
      buf.push_line(p1, p2).should be_true
      buf.size.should eq(2)
      buf[0].should eq(p1)
      buf[1].should eq(p2)

      active_slice = buf.to_slice
      active_slice.size.should eq(2)
    end

    it "gracefully handles arena overflow without raising or allocating on the GC heap" do
      arena = Lapis::Core::FrameArena.new(128)
      s1 = arena.alloc_slice(Int64, 10)
      s1.size.should eq(10)

      # Exceeds remaining capacity
      s2 = arena.alloc_slice(Int64, 20)
      s2.empty?.should be_true
      arena.overflow_count.should eq(1_u64)
    end

    it "executes FrameArena hot-loop allocations and tick! resets with zero GC heap allocations" do
      arena = Lapis::Core::FrameArena.new(16_384)
      v_a = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)
      v_b = Godot::Vector3.new(4.0_f32, 5.0_f32, 6.0_f32)
      acc = 0.0_f32

      assert_zero_allocation("FrameArena Slice & Buffer Per-Tick Cycle", iterations: 10_000, warmup: 20) do
        slice = arena.alloc_slice(Godot::Vector3, 8)
        slice[0] = v_a
        slice[1] = v_b
        ptr = arena.push(v_a + v_b)
        acc += ptr.value.x + slice[0].y
        arena.tick!
      end

      acc.should be > 0.0_f32
      arena.frame_count.should be >= 10_000_u64
    end
  end

  describe "Lapis::DSL::FrameArenaBuilder (Tier 2 Declarative DSL)" do
    it "supports Lapis.frame_arena, Lapis.frame_scope, and Object#frame_slice / frame_buffer" do
      Lapis::Core::FrameArena.reset!
      node = ArenaSignalTestNode.new

      sum = 0
      node.frame_scope do |arena|
        ints = node.frame_slice(Int32, 4)
        ints[0] = 10
        ints[1] = 20
        ints[2] = 30
        ints[3] = 40
        sum = ints[0] + ints[1] + ints[2] + ints[3]

        vbuf = node.frame_buffer(Godot::Vector2, 4)
        vbuf << Godot::Vector2.new(1.0_f32, 2.0_f32)
        vbuf.size.should eq(1)
      end

      sum.should eq(100)
      Lapis::Core::FrameArena.current.used.should eq(0)
    end
  end

  describe "Lapis::Core::StaticSignalTable & StaticSignalSlot(*T)" do
    it "binds and dispatches compile-time typed procs with zero GC heap allocations" do
      table = Lapis::Core::StaticSignalTable.new
      emitter_id = 1001_u64
      slot = table.slot(emitter_id, "health_changed", Int32, Int32)

      last_hp = 0
      last_max = 0
      call_count = 0

      token = slot.connect do |hp, max|
        last_hp = hp
        last_max = max
        call_count += 1
      end

      token.should be > 0_u64
      slot.active_count.should eq(1)
      slot.connected?.should be_true

      assert_zero_allocation("StaticSignalSlot(Int32, Int32)#emit", iterations: 25_000, warmup: 20) do |i|
        slot.emit(i, 100)
      end

      call_count.should be >= 25_000
      last_max.should eq(100)
      slot.emission_count.should be >= 25_000_u64

      slot.unbind(token).should be_true
      slot.active_count.should eq(0)
      slot.empty?.should be_true
    end

    it "supports one-shot listeners, += / -= operators, and FrameArena-staged payload broadcasts" do
      table = Lapis::Core::StaticSignalTable.new
      arena = Lapis::Core::FrameArena.new(4096)
      emitter_id = 2002_u64

      once_calls = 0
      table.once(emitter_id, "ping", Int32) do |val|
        once_calls += val
      end

      table.emit(emitter_id, "ping", 7).should eq(1)
      table.emit(emitter_id, "ping", 7).should eq(0)
      once_calls.should eq(7)

      # FrameArena-staged struct payload broadcast to both typed and raw C-ABI listeners
      typed_damage = 0
      raw_bytes_seen = 0

      table.connect(emitter_id, "damage_event", DamageEventPayload) do |ev|
        typed_damage += ev.damage
      end

      table.bind_raw(emitter_id, "damage_event", ->(eid : UInt64, ptr : Pointer(Void), bytes : Int32) {
        if eid == 2002_u64 && !ptr.null?
          raw_bytes_seen = bytes
        end
        nil
      })

      payload = DamageEventPayload.new(attacker_id: 99_u64, damage: 45, critical: true)
      assert_zero_allocation("StaticSignalTable#emit_payload via FrameArena", iterations: 10_000, warmup: 20) do
        table.emit_payload(emitter_id, "damage_event", payload, arena)
        arena.tick!
      end

      typed_damage.should be >= 450_000
      raw_bytes_seen.should eq(sizeof(DamageEventPayload))
    end

    it "handles >64 listeners on a single signal using FrameArena scratch overflow with zero GC allocations" do
      table = Lapis::Core::StaticSignalTable.new
      emitter_id = 3003_u64
      slot = table.slot(emitter_id, "mass_broadcast", Int32)

      total = 0
      80.times do
        slot.connect do |delta|
          total += delta
        end
      end

      slot.active_count.should eq(80)

      assert_zero_allocation("StaticSignalSlot >64 Listeners Overflow via FrameArena", iterations: 2_000, warmup: 10) do
        slot.emit(1)
      end

      total.should be >= 160_000
      Lapis::Core::FrameArena.current.used.should eq(0)
    end
  end

  describe "TypedSignal(*T), `signal` macro, and `on_signal` macro Zero-Allocation Dispatch" do
    it "emits 0-arg, 2-arg scalar, and Vector3 signals on Node with strictly zero GC heap allocations" do
      node = ArenaSignalTestNode.new

      zero_count = 0
      hp_sum = 0
      vec_sum = 0.0_f32

      node.zero_arg_triggered.connect do
        zero_count += 1
      end

      on_signal node.health_changed do |hp, max|
        hp_sum += hp + max
      end

      vec_handler = ->(v : Godot::Vector3) {
        vec_sum += v.x + v.y + v.z
      }
      on_signal node.position_updated, vec_handler

      sample_vec = Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32)

      assert_zero_allocation("Node 0-arg TypedSignal#emit", iterations: 25_000, warmup: 20) do
        node.zero_arg_triggered.emit
      end

      assert_zero_allocation("Node 2-arg TypedSignal#emit", iterations: 25_000, warmup: 20) do
        node.health_changed.emit(50, 100)
      end

      assert_zero_allocation("Node Vector3 TypedSignal#emit", iterations: 25_000, warmup: 20) do
        node.position_updated.emit(sample_vec)
      end

      assert_zero_allocation("Node Object#emit_signal (0-arg)", iterations: 25_000, warmup: 20) do
        node.emit_signal("zero_arg_triggered")
      end

      zero_count.should be >= 50_000
      hp_sum.should be >= 3_750_000
      vec_sum.should be > 0.0_f32

      node.disconnect_all
      node.signal_connection_count("health_changed").should eq(0)
    end
  end
end
