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

    it "does not mark awaiting subscriptions as completed when emitter is destroyed or unsubscribed" do
      node = ArenaSignalTestNode.new
      tid = node.signal_target_id
      sub = Godot.subscribe_signal(tid, "zero_arg_triggered")
      sub.completed?.should be_false
      sub.unsubscribed?.should be_false

      Godot.clear_signal_subscriptions(tid)
      sub.unsubscribed?.should be_true
      sub.completed?.should be_false
      sub.active?.should be_false
    end
  end
end

# =============================================================================
# WO-065 ([AS-2]): Declarative `node` / `signal` / `on_signal` / `@[OnSignal]`
# Compile-Time Typed Proc Binding to `StaticSignalTable` Slots
# =============================================================================

gmodule WO065CombatMixin do
  signal shield_hit(absorbed : Int32)

  property shield_absorbed_total : Int32 = 0
  property mixin_annot_hits : Int32 = 0

  on_signal shield_hit, ->on_shield_hit(Int32)

  def on_shield_hit(absorbed : Int32) : Void
    @shield_absorbed_total += absorbed
  end

  @[OnSignal(:shield_hit)]
  def on_shield_hit_annotated(absorbed : Int32) : Void
    @mixin_annot_hits += absorbed
  end
end

node WO065DeclarativeActor < Node2D do
  include WO065CombatMixin

  signal health_changed(current : Int32, max : Int32)
  signal stamina_changed(stamina : Float32)
  signal combo_landed(hits : Int32, multiplier : Float64)
  signal spawned
  signal died

  property last_hp : Int32 = 100
  property last_max_hp : Int32 = 100
  property last_stamina : Float32 = 0.0_f32
  property combo_score : Float64 = 0.0
  property spawn_count : Int32 = 0
  property death_count : Int32 = 0
  property block_hp_bonus : Int32 = 0
  property dynamic_self_pings : Int32 = 0

  # 1. Explicit compile-time typed ProcPointer on class-level `on_signal`
  on_signal health_changed, ->on_health_changed(Int32, Int32)

  # 2. Symbol signal name + inferred ProcPointer (types inferred from `def` / `signal`)
  on_signal :stamina_changed, ->on_stamina_changed

  # 3. Symbol signal name + symbol method name
  on_signal :died, :on_died_handler

  # 4. One-shot declarative `on_signal`
  on_signal spawned, ->on_spawned_once, once: true

  # 5. Block-based declarative `on_signal` in node body
  on_signal health_changed do |hp, max|
    @block_hp_bonus += (max - hp)
  end

  def on_health_changed(current : Int32, max : Int32) : Void
    @last_hp = current
    @last_max_hp = max
  end

  def on_stamina_changed(stamina : Float32) : Void
    @last_stamina = stamina
  end

  def on_died_handler : Void
    @death_count += 1
  end

  def on_spawned_once : Void
    @spawn_count += 1
  end

  # 6. `@[OnSignal]` method annotation binding directly to `StaticSignalTable`
  @[OnSignal(:combo_landed)]
  def on_combo_landed(hits : Int32, multiplier : Float64) : Void
    @combo_score += hits.to_f64 * multiplier
  end

  def bind_in_method_scope : Void
    on_signal :died, ->on_dynamic_ping
  end

  def on_dynamic_ping : Void
    @dynamic_self_pings += 1
  end
end

describe "WO-065: Declarative `node` / `signal` / `on_signal` StaticSignalTable Proc Binding" do
  it "automatically binds class-level `on_signal`, `@[OnSignal]`, and `gmodule` procs to StaticSignalTable slots on instantiation" do
    actor = WO065DeclarativeActor.new

    # Emit 2-arg signal via fast-path emit_health_changed (never allocating TypedSignal wrapper)
    actor.emit_health_changed(75, 120)
    actor.last_hp.should eq(75)
    actor.last_max_hp.should eq(120)
    actor.block_hp_bonus.should eq(45)

    # Emit 1-arg Float32 signal bound via inferred ProcPointer `->on_stamina_changed`
    actor.emit_stamina_changed(88.5_f32)
    actor.last_stamina.should eq(88.5_f32)

    # Emit 2-arg signal bound via `@[OnSignal(:combo_landed)]`
    actor.emit_combo_landed(4, 2.5)
    actor.combo_score.should eq(10.0)

    # Emit 0-arg one-shot signal bound via `once: true`
    actor.emit_spawned
    actor.emit_spawned
    actor.spawn_count.should eq(1)

    # Emit 0-arg signal bound via symbol method `:on_died_handler`
    actor.emit_died
    actor.emit_died
    actor.death_count.should eq(2)

    # Emit mixin signal declared in `gmodule WO065CombatMixin`
    actor.emit_shield_hit(30)
    actor.shield_absorbed_total.should eq(30)
    actor.mixin_annot_hits.should eq(30)

    # Method-scope `on_signal :died, ->on_dynamic_ping`
    actor.bind_in_method_scope
    actor.emit_died
    actor.dynamic_self_pings.should eq(1)
    actor.death_count.should eq(3)

    actor.disconnect_all
  end

  it "provides synthesized `<name>_slot`, `bind_<name>`, `unbind_<name>`, and `<name>_signal_hash` without allocating TypedSignal" do
    actor = WO065DeclarativeActor.new
    actor.disconnect_all

    actor.health_changed_signal_hash.should eq(Lapis::Core::StaticSignalTable.hash_signal_name("health_changed"))

    slot = actor.health_changed_slot
    slot.empty?.should be_true

    observed_hp = 0
    cb = ->(hp : Int32, max : Int32) {
      observed_hp = hp + max
      nil
    }

    token = actor.bind_health_changed(cb)
    token.should be > 0_u64
    slot.active_count.should eq(1)

    actor.emit_health_changed(40, 100)
    observed_hp.should eq(140)

    actor.unbind_health_changed(cb).should be_true
    slot.active_count.should eq(0)

    # Rebind declarative class-level signals via rebind_static_signals!
    actor.rebind_static_signals!
    actor.emit_health_changed(60, 100)
    actor.last_hp.should eq(60)

    actor.disconnect_all
  end

  it "supports Tier 2 Lapis.static_signals / StaticSignalBuilder and Godot::Object static signal helpers" do
    actor = WO065DeclarativeActor.new
    actor.disconnect_all

    total = 0
    cb = ->(hp : Int32, max : Int32) {
      total += hp + max
      nil
    }

    Lapis.static_signals do |signals|
      tok = signals.bind(actor, "health_changed", cb)
      tok.should be > 0_u64
      signals.emit(actor, "health_changed", 25, 75).should eq(1)
      total.should eq(100)
      signals.unbind(actor, "health_changed", cb).should be_true
    end

    tok2 = actor.bind_static_signal(:health_changed, cb)
    tok2.should be > 0_u64
    actor.emit_static_signal(:health_changed, 10, 20).should eq(1)
    total.should eq(130)
    actor.unbind_static_signal(tok2).should be_true
    actor.emit_static_signal(:health_changed, 10, 20).should eq(0)
  end

  it "executes declarative `node` / `signal` / `on_signal` emission and slot binding with strictly ZERO GC heap allocations" do
    actor = WO065DeclarativeActor.new

    assert_zero_allocation("WO-065 Declarative emit_health_changed (2-arg)", iterations: 25_000, warmup: 20) do
      actor.emit_health_changed(80, 100)
    end

    assert_zero_allocation("WO-065 Declarative emit_combo_landed (@[OnSignal])", iterations: 25_000, warmup: 20) do
      actor.emit_combo_landed(3, 1.5)
    end

    assert_zero_allocation("WO-065 Declarative emit_shield_hit (gmodule)", iterations: 25_000, warmup: 20) do
      actor.emit_shield_hit(5)
    end

    slot = actor.health_changed_slot
    assert_zero_allocation("WO-065 Synthesized <name>_slot.emit", iterations: 25_000, warmup: 20) do
      slot.emit(90, 100)
    end

    cb = ->(hp : Int32, max : Int32) { nil }
    assert_zero_allocation("WO-065 bind_health_changed + unbind_health_changed cycle", iterations: 10_000, warmup: 20) do
      tok = actor.bind_health_changed(cb)
      actor.unbind_health_changed(tok)
    end

    actor.disconnect_all
  end
end
