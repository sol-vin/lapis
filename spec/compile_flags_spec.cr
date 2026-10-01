require "./spec_helper"

describe "Compile-Time Flags & Optimization Diagnostics" do
  describe "Godot::LeakTracker" do
    it "records, counts, and unregisters active allocations" do
      tracker = Godot.leak_tracker
      tracker.clear!

      # Temporarily ensure enabled for test verification
      prev_enabled = tracker.enabled?
      tracker.enabled = true

      begin
        tracker.register(1001_u64, "PlayerNode", "src/game/player.cr", 42)
        tracker.register(1002_u64, "EnemyNode", "src/game/enemy.cr", 88)
        tracker.live_count.should eq(2)

        # Unregister one
        tracker.unregister(1001_u64)
        tracker.live_count.should eq(1)

        # Inspect remaining leak
        leaks = tracker.live_allocations
        leaks.size.should eq(1)
        leaks[0].instance_id.should eq(1002_u64)
        leaks[0].class_name.should eq("EnemyNode")
        leaks[0].file.should eq("src/game/enemy.cr")
        leaks[0].line.should eq(88)

        # Dump report to memory buffer
        io = IO::Memory.new
        leak_count = tracker.dump_leaks(io)
        leak_count.should eq(1)
        out_str = io.to_s
        out_str.should contain("WARNING: 1 Crystal Godot object(s) were leaked!")
        out_str.should contain("EnemyNode")
        out_str.should contain("src/game/enemy.cr:88")

        # Cleanup
        tracker.unregister(1002_u64)
        tracker.live_count.should eq(0)
      ensure
        tracker.enabled = prev_enabled
        tracker.clear!
      end
    end
  end

  describe "Godot::DispatchProfiler" do
    it "records method invocations and calculates timing metrics" do
      profiler = Godot.dispatch_profiler
      profiler.reset!

      prev_enabled = profiler.enabled?
      profiler.enabled = true

      begin
        # Record sample dispatches
        profiler.record("Player", "_process", 500_000.0)   # 0.5 ms
        profiler.record("Player", "_process", 1_500_000.0) # 1.5 ms
        profiler.record("Enemy", "take_damage", 250_000.0) # 0.25 ms

        metrics = profiler.metrics
        metrics.has_key?("Player#_process").should be_true
        metrics.has_key?("Enemy#take_damage").should be_true

        p_metric = metrics["Player#_process"]
        p_metric.count.should eq(2)
        p_metric.total_ns.should eq(2_000_000.0)
        p_metric.avg_ns.should eq(1_000_000.0)
        p_metric.min_ns.should eq(500_000.0)
        p_metric.max_ns.should eq(1_500_000.0)
        p_metric.avg_ms.should eq(1.0)
        p_metric.total_ms.should eq(2.0)

        # Dump profile output to memory buffer
        io = IO::Memory.new
        profiler.dump_profile(io)
        out_str = io.to_s
        out_str.should contain("Method Dispatch Profile")
        out_str.should contain("Player#_process")
        out_str.should contain("Enemy#take_damage")
      ensure
        profiler.enabled = prev_enabled
        profiler.reset!
      end
    end
  end

  describe "Godot::TombstoneTracker" do
    it "records freed objects and formats rich DisposedObjectError messages" do
      tombstones = Godot.tombstone_tracker
      tombstones.clear!

      prev_enabled = tombstones.enabled?
      tombstones.enabled = true

      begin
        tombstones.record_freed(5555_u64, "ZombieBoss", "src/game/boss.cr", 150)

        t = tombstones.find(5555_u64)
        t.should_not be_nil
        t.not_nil!.class_name.should eq("ZombieBoss")
        t.not_nil!.file.should eq("src/game/boss.cr")
        t.not_nil!.line.should eq(150)

        msg = tombstones.format_disposed_message(5555_u64)
        msg.should contain("ZombieBoss (Instance ID: 5555)")
        msg.should contain("src/game/boss.cr:150")

        # Non-existent tombstone fallback
        fallback = tombstones.format_disposed_message(9999_u64)
        fallback.should contain("Object 9999 was disposed by Godot or GDScript")
      ensure
        tombstones.enabled = prev_enabled
        tombstones.clear!
      end
    end
  end

  describe "Godot::SignalSpy" do
    it "traces signal emissions and tracks event counts" do
      spy = Godot.signal_spy
      spy.clear!

      prev_enabled = spy.enabled?
      spy.enabled = true

      begin
        spy.record("Player", "health_changed", 2)
        spy.record("Player", "died", 0)

        spy.event_count.should eq(2)
        events = spy.events
        events[0].emitter_class.should eq("Player")
        events[0].signal_name.should eq("health_changed")
        events[0].arg_count.should eq(2)

        events[1].signal_name.should eq("died")
        events[1].arg_count.should eq(0)
      ensure
        spy.enabled = prev_enabled
        spy.clear!
      end
    end
  end

  describe "Godot::ThreadSafety" do
    it "asserts main thread cleanly" do
      Godot::ThreadSafety.main_thread?.should be_true
      # Should not raise on main thread
      Godot::ThreadSafety.assert_main_thread!("test_op", "Node")
    end
  end

  describe "Godot::EditorDocRegistry" do
    it "provides safe register and load_all methods" do
      # Should execute cleanly without error
      Godot::EditorDocRegistry.register("<test></test>")
      Godot::EditorDocRegistry.load_all
    end
  end
end
