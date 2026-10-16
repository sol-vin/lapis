# =============================================================================
# LibGodot Test Suite: Concurrency Actor Pattern with Buffered Channels
# =============================================================================
# Verifies background thread workers communicating with the main loop
# via buffered channels (Channel(T).new(N)) and safe cross-thread notifications.

include Lapis::Test

node ConcurrencyActorTarget < Godot::Node2D do
  signal processed(val : Int32)
  signal finished
end

test_suite "ActorChannel" do
  test "background OS worker thread dispatches results through buffered channel" do
    channel = Channel(Int32).new(16)
    target = Godot.create(ConcurrencyActorTarget)

    # Spawn background OS thread (Actor Pattern)
    worker = Thread.new do
      5.times do |i|
        # Simulate background calculation (procedural generation / pathfinding)
        result = (i + 1) * 10
        channel.send(result)
      end
    end

    # Main thread consumes from buffered channel
    received = Array(Int32).new
    5.times do
      received << channel.receive
    end

    worker.join

    assert_eq received.size, 5
    assert_eq received, [10, 20, 30, 40, 50]

    target.destroy
  end

  test "multiple concurrent background threads stream into shared buffered channel" do
    channel = Channel(String).new(32)
    threads = Array(Thread).new

    3.times do |thread_idx|
      threads << Thread.new do
        3.times do |item_idx|
          channel.send("T#{thread_idx}_I#{item_idx}")
        end
      end
    end

    received = Array(String).new
    9.times do
      received << channel.receive
    end

    threads.each(&.join)
    assert_eq received.size, 9

    # Verify every thread's items are present
    3.times do |t|
      3.times do |i|
        assert_true received.includes?("T#{t}_I#{i}")
      end
    end
  end
end
