# =============================================================================
# LibGodot Test Suite: Lifecycle-Safe Timers, TimerHandle & Coroutine Sugar
# =============================================================================

include Lapis::Test

test_suite "Timers" do
  test "Pillar 1: TimerHandle initialization, inspection, and time_left calculation" do
    handle = Godot::TimerHandle.new(0.5)
    assert_true handle.running?
    assert_false handle.paused?
    assert_false handle.cancelled?
    assert_false handle.finished?
    assert_approx_eq handle.interval_sec.to_f32, 0.5_f32
    assert_approx_eq handle.elapsed_time.to_f32, 0.0_f32
    assert_approx_eq handle.elapsed.to_f32, 0.0_f32
    assert_approx_eq handle.time_left.to_f32, 0.5_f32
    assert_eq handle.tick_count, 0_i64
  end

  test "Pillar 2: Deterministic time advancement, interval boundary crossing, and reset" do
    handle = Godot::TimerHandle.new(1.0)

    # Partial advance
    ticked1 = handle.advance(0.3)
    assert_false ticked1
    assert_approx_eq handle.elapsed.to_f32, 0.3_f32
    assert_approx_eq handle.time_left.to_f32, 0.7_f32
    assert_eq handle.tick_count, 0_i64

    # Boundary crossing advance
    ticked2 = handle.advance(0.7)
    assert_true ticked2
    assert_approx_eq handle.elapsed.to_f32, 0.0_f32
    assert_approx_eq handle.time_left.to_f32, 1.0_f32
    assert_eq handle.tick_count, 1_i64

    # Multiple ticks advance
    handle.advance(0.5)
    handle.record_tick!
    assert_eq handle.tick_count, 2_i64

    # Reset
    handle.reset
    assert_approx_eq handle.elapsed.to_f32, 0.0_f32
    assert_eq handle.tick_count, 0_i64
  end

  test "Pillar 3: TimerHandle pause and resume behavior" do
    handle = Godot::TimerHandle.new(0.4)

    handle.pause
    assert_true handle.paused?

    # Advance while paused does nothing
    assert_false handle.advance(1.0)
    assert_eq handle.tick_count, 0_i64

    handle.resume
    assert_false handle.paused?

    # Advance after resume ticks
    assert_true handle.advance(0.5)
    assert_eq handle.tick_count, 1_i64
  end

  test "Pillar 4: Node binding and automatic early cancellation upon node destruction" do
    target_node = Godot.create(Godot::Node2D)
    handle = Godot::TimerHandle.new(0.2, target_node)
    assert_true handle.running?
    assert_false handle.finished?

    # Node is alive, advance works
    assert_false handle.advance(0.1)

    # Destroy node
    target_node.destroy

    # Advance detects deallocated node and cancels
    assert_false handle.advance(0.2)
    assert_false handle.running?
    assert_true handle.cancelled?
    assert_true handle.finished?
    assert_approx_eq handle.time_left.to_f32, 0.0_f32
  end

  test "Pillar 5: Godot.every and Node#every recurring timer scheduling" do
    parent = Godot.create(Godot::Node2D)

    # Node#every with Time::Span
    h_node_every = parent.every(0.1.seconds) do |h|
      # block
    end
    assert_not_nil h_node_every
    assert_true h_node_every.running?
    assert_approx_eq h_node_every.interval_sec.to_f32, 0.1_f32
    h_node_every.cancel
    assert_true h_node_every.cancelled?

    # Godot.every with Number
    h_gd_every = Godot.every(0.2, parent) do |h|
      # block
    end
    assert_not_nil h_gd_every
    assert_true h_gd_every.running?
    h_gd_every.cancel

    parent.destroy
  end

  test "Pillar 6: Godot.after and Node#after delayed timer scheduling" do
    parent = Godot.create(Godot::Node2D)

    # Node#after with Number
    h_node_after = parent.after(0.15) do
      # block
    end
    assert_not_nil h_node_after
    assert_approx_eq h_node_after.interval_sec.to_f32, 0.15_f32
    h_node_after.cancel

    # Godot.after with Time::Span
    h_gd_after = Godot.after(0.2.seconds, parent) do
      # block
    end
    assert_not_nil h_gd_after
    h_gd_after.cancel

    parent.destroy
  end

  test "Pillar 7: Top-level every and after convenience helpers" do
    h1 = every(0.5.seconds) do
      # block
    end
    assert_not_nil h1
    assert_true h1.running?
    h1.stop
    assert_true h1.cancelled?
    assert_true h1.finished?

    h2 = after(0.25) do
      # block
    end
    assert_not_nil h2
    assert_true h2.running?
    h2.cancel
    assert_true h2.cancelled?
  end

  test "Pillar 8: Quantitative zero memory leak verification" do
    assert_no_leak do
      10.times do
        node = Godot.create(Godot::Node)
        h = node.every(0.05) do
          # tick
        end
        h.advance(0.05)
        h.cancel
        node.destroy
      end
    end
  end
end
