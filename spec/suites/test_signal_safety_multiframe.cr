# =============================================================================
# LibGodot Test Suite: Multi-Frame Signal Safety, Disconnection & Dead Object Pruning
# =============================================================================

include Lapis::Test

node SignalSafetyEmitterNode < Godot::Node do
  signal ping(seq : Int32)
  signal data(val : String)
  signal void_sig

  def emit_ping(seq : Int32) : Void
    ping.emit(seq)
  end
end

node SignalSafetyReceiverNode < Godot::Node do
  property received_count : Int32 = 0
  property last_seq : Int32 = -1
  property last_data : String = ""

  def handle_ping(seq : Int32) : Void
    @received_count += 1
    @last_seq = seq
  end

  def handle_data(str : String) : Void
    @received_count += 1
    @last_data = str
  end
end

test_suite "SignalSafetyMultiFrame" do
  test "Pillar 1: explicit disconnection verification across multiple frames" do
    emitter = Godot.create(SignalSafetyEmitterNode)
    root.call("add_child", emitter)

    call_count = 0
    sub = emitter.ping.connect do |args|
      call_count += 1
    end

    # Frame 1: Connected emission
    emitter.ping.emit(1)
    Fiber.yield
    assert_eq call_count, 1

    # Disconnect explicitly via subscription
    sub.disconnect
    assert_false sub.active?

    # Frame 2 & Frame 3: Emissions must not reach disconnected callback
    emitter.ping.emit(2)
    Fiber.yield
    emitter.ping.emit(3)
    Fiber.yield
    assert_eq call_count, 1, "Disconnected callback must never receive subsequent emissions"

    # Test operator `-=` with proc
    handler = ->(args : Array(Godot::Variant)) { call_count += 10 }
    emitter.ping += handler
    emitter.ping.emit(4)
    Fiber.yield
    assert_eq call_count, 11

    emitter.ping -= handler
    emitter.ping.emit(5)
    Fiber.yield
    assert_eq call_count, 11, "Proc disconnected with -= must not receive emissions"

    # Test operator `-=` with typed proc
    typed_handler = ->(seq : Int32) { call_count += seq * 100 }
    emitter.ping += typed_handler
    emitter.ping.emit(2)
    Fiber.yield
    assert_eq call_count, 211

    emitter.ping -= typed_handler
    emitter.ping.emit(3)
    Fiber.yield
    assert_eq call_count, 211, "Typed proc disconnected with -= must not receive emissions"

    root.call("remove_child", emitter)
    emitter.destroy
  end

  test "Pillar 2: automatic disconnection and graceful skip on receiver destruction" do
    emitter = Godot.create(SignalSafetyEmitterNode)
    receiver = Godot.create(SignalSafetyReceiverNode)
    root.call("add_child", emitter)
    root.call("add_child", receiver)

    # 1. Connect pure Crystal callback with receiver tracking
    sub = emitter.ping.connect(receiver) do |seq|
      receiver.handle_ping(seq)
    end
    assert_true sub.active?

    # 2. Connect engine method dispatch with receiver tracking
    sub_engine = emitter.data.connect(listener_target: receiver, method_name: :set_name)
    assert_true sub_engine.active?

    # Frame 1: emission while alive
    emitter.ping.emit(10)
    emitter.data.emit("CustomReceiverNode")
    Fiber.yield
    assert_eq receiver.received_count, 1
    assert_eq receiver.last_seq, 10
    assert_eq receiver.get_name.to_s, "CustomReceiverNode"

    # Frame 2: Destroy receiver
    root.call("remove_child", receiver)
    receiver.destroy
    assert_false receiver.alive?
    assert_false sub.active?, "Subscription must become inactive once receiver is destroyed"
    assert_false sub_engine.active?, "Engine method subscription must become inactive once receiver is destroyed"

    # Frame 3: Emit signal from living emitter to destroyed receiver
    # Invariant: Must not crash, must not throw, must auto-prune subscription
    emitter.ping.emit(20)
    emitter.data.emit("IgnoredName")
    Fiber.yield

    assert_false sub.active?
    assert_false sub_engine.active?

    root.call("remove_child", emitter)
    emitter.destroy
  end

  test "Pillar 3: emitting signals on destroyed emitters raises DisposedObjectError safely" do
    emitter = Godot.create(SignalSafetyEmitterNode)
    root.call("add_child", emitter)
    root.call("remove_child", emitter)
    emitter.destroy

    assert_false emitter.alive?
    assert_true emitter.destroyed?

    # Attempting to emit a signal on a dead emitter must raise DisposedObjectError
    assert_raises(Godot::DisposedObjectError) do
      emitter.ping.emit(100)
    end

    assert_raises(Godot::DisposedObjectError) do
      emitter.emit_signal("ping", 100)
    end
  end

  test "Pillar 4: mixed living and dead subscribers across frame slices" do
    emitter = Godot.create(SignalSafetyEmitterNode)
    root.call("add_child", emitter)

    receivers = Array(SignalSafetyReceiverNode).new
    subs = Array(Godot::SignalSubscription).new

    10.times do |i|
      rec = Godot.create(SignalSafetyReceiverNode)
      root.call("add_child", rec)
      receivers << rec
      subs << emitter.ping.connect(rec) do |seq|
        rec.handle_ping(seq)
      end
    end

    # Frame 1: All 10 alive
    emitter.ping.emit(1)
    Fiber.yield
    receivers.each { |r| assert_eq r.received_count, 1 }

    # Frame 2: Destroy 5 of the 10 receivers (even indices: 0, 2, 4, 6, 8)
    5.times do |i|
      dead_rec = receivers[i * 2]
      root.call("remove_child", dead_rec)
      dead_rec.destroy
    end

    # Frame 3: Emit to the remaining living subscribers
    emitter.ping.emit(2)
    Fiber.yield

    # Living receivers (odd indices) must have received 2 emissions
    [1, 3, 5, 7, 9].each do |idx|
      living_rec = receivers[idx]
      assert_true living_rec.alive?
      assert_eq living_rec.received_count, 2
      assert_eq living_rec.last_seq, 2
    end

    # Cleanup remaining living receivers
    [1, 3, 5, 7, 9].each do |idx|
      living_rec = receivers[idx]
      root.call("remove_child", living_rec)
      living_rec.destroy
    end

    root.call("remove_child", emitter)
    emitter.destroy
  end

  test "Pillar 5: one-shot (once) signal lifecycle across multiple frames" do
    emitter = Godot.create(SignalSafetyEmitterNode)
    root.call("add_child", emitter)

    once_calls = 0
    sub = emitter.ping.once do |_args|
      once_calls += 1
    end

    assert_true sub.active?

    # Frame 1: First emission triggers callback
    emitter.ping.emit(10)
    Fiber.yield
    assert_eq once_calls, 1
    assert_false sub.active?, "One-shot subscription must deactivate after first invocation"

    # Frame 2 & Frame 3: Subsequent emissions must not trigger
    emitter.ping.emit(20)
    Fiber.yield
    emitter.ping.emit(30)
    Fiber.yield
    assert_eq once_calls, 1, "One-shot subscription must never fire again"

    root.call("remove_child", emitter)
    emitter.destroy
  end

  test "Pillar 6: rapid reconnection churn across frame cycles without subscription accumulation" do
    emitter = Godot.create(SignalSafetyEmitterNode)
    root.call("add_child", emitter)

    50.times do |cycle|
      sub = emitter.ping.connect do |_args|
      end
      assert_true sub.active?
      emitter.ping.emit(cycle)
      Fiber.yield
      sub.disconnect
      assert_false sub.active?
    end

    # Verify no dangling subscriptions remained in table
    assert_eq emitter.ping.connection_count, 0

    root.call("remove_child", emitter)
    emitter.destroy
  end

  test "Pillar 7: zero leak signal lifecycle stress test" do
    assert_no_new_orphans("SignalMultiFrameStress") do
      10.times do
        emitter = Godot.create(SignalSafetyEmitterNode)
        receiver = Godot.create(SignalSafetyReceiverNode)
        root.call("add_child", emitter)
        root.call("add_child", receiver)

        sub = emitter.ping.connect(listener_target: receiver, method_name: :handle_ping)
        emitter.ping.emit(42)
        Fiber.yield

        sub.disconnect
        root.call("remove_child", receiver)
        root.call("remove_child", emitter)
        receiver.destroy
        emitter.destroy
      end
    end
  end
end
