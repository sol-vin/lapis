# =============================================================================
# LibGodot Test Suite: High-Throughput Node Pool Stress & Lifecycle Invariants
# =============================================================================
# Verifies high-throughput node pooling under burst allocations,
# capacity expansion, and dead-pointer resilience.

require "../../src/libgodot/pool"

include Lapis::Test

node StressPooledLaser < Godot::Node2D do
  property energy : Float32 = 100.0_f32
  property active_color : String = "cyan"

  def reinit(energy : Float32, color : String) : Void
    @energy = energy
    @active_color = color
  end
end

class StressPoolHost < Godot::Node2D
  node_pool lasers : StressPooledLaser, capacity: 50
end

test_suite "NodePoolStress" do
  test "NodePool prewarms 50 instances and executes high-burst acquire and release" do
    host = Godot.create(StressPoolHost)
    pool = host.lasers

    assert_eq pool.capacity, 50
    assert_eq pool.available_count, 50
    assert_eq pool.active_count, 0

    # Burst acquire 50 instances
    acquired = Array(StressPooledLaser).new
    50.times do |i|
      laser = pool.acquire { |l| l.reinit(i * 2.0_f32, "blue") }
      assert_eq laser.energy, i * 2.0_f32
      assert_eq laser.active_color, "blue"
      acquired << laser
    end

    assert_eq pool.available_count, 0
    assert_eq pool.active_count, 50

    # Releasing all returns pool to full availability
    pool.release_all
    assert_eq pool.available_count, 50
    assert_eq pool.active_count, 0

    host.destroy
  end

  test "NodePool survives dead pointer pruning during active burst" do
    host = Godot.create(StressPoolHost)
    pool = host.lasers

    # Acquire 5 nodes
    l1 = pool.acquire
    l2 = pool.acquire
    l3 = pool.acquire
    l4 = pool.acquire
    l5 = pool.acquire

    assert_eq pool.active_count, 5

    # Simulate catastrophic external destruction of l2 and l4
    l2.destroy
    l4.destroy

    # Release remaining alive nodes
    pool.release(l1)
    pool.release(l3)
    pool.release(l5)

    # Releasing dead nodes does not crash or raise
    pool.release(l2)
    pool.release(l4)

    # Next acquire works cleanly
    next_laser = pool.acquire
    assert_true next_laser.active?

    pool.release(next_laser)
    host.destroy
  end

  test "NodePool sustains 500 acquire-release cycles with zero memory leaks" do
    host = Godot.create(StressPoolHost)
    pool = host.lasers

    assert_memory_stable(cycles: 5, max_delta: 0) do
      100.times do
        l = pool.acquire { |item| item.reinit(50.0_f32, "red") }
        pool.release(l)
      end
    end

    host.destroy
  end
end
