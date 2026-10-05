# =============================================================================
# LibGodot Test Suite: Zero-Allocation Object Pool & Dead-Pointer Invariants
# =============================================================================
# Verifies Lapis::Pool pre-warming, acquire, release, active/available counters,
# and dead-pointer recovery.

require "../../src/libgodot/pool"

include Lapis::Test

node PoolTestBullet < Godot::Node2D do
  property speed : Float32 = 300.0_f32
  property damage : Int32 = 25

  def reset(speed : Float32, damage : Int32) : Void
    @speed = speed
    @damage = damage
  end
end

class PoolTestArena < Godot::Node2D
  node_pool bullets : PoolTestBullet, capacity: 10
end

test_suite "Pool" do
  test "NodePool prewarms instances, tracks available and active counts, and recycles cleanly" do
    arena = Godot.create(PoolTestArena)
    pool = arena.bullets

    assert_eq pool.capacity, 10
    assert_eq pool.available_count, 10
    assert_eq pool.active_count, 0

    # Acquire 3 bullets
    b1 = pool.acquire { |b| b.reset(400.0_f32, 50) }
    b2 = pool.acquire { |b| b.reset(500.0_f32, 75) }
    b3 = pool.acquire

    assert_eq pool.available_count, 7
    assert_eq pool.active_count, 3
    assert_eq b1.damage, 50
    assert_eq b2.damage, 75

    # Release 1 bullet
    pool.release(b1)
    assert_eq pool.available_count, 8
    assert_eq pool.active_count, 2

    # Release all remaining
    pool.release_all
    assert_eq pool.available_count, 10
    assert_eq pool.active_count, 0

    arena.destroy
  end

  test "NodePool handles dead pointers gracefully during acquire" do
    root = Godot.create(Godot::Node2D)
    pool = Lapis::Pool(PoolTestBullet).new(root, capacity: 2)

    # Acquire and manually destroy a pooled node to simulate external queue_free
    b1 = pool.acquire
    b1.destroy # dead pointer!

    # Acquiring next should prune dead node and succeed cleanly
    b2 = pool.acquire
    assert_true b2.active?

    pool.release(b2)
    root.destroy
  end
end
