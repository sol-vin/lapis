require "./spec_helper"

describe Godot::TimerHandle do
  it "initializes with interval and default state" do
    handle = Godot::TimerHandle.new(0.5)
    handle.interval_sec.should eq(0.5)
    handle.running?.should be_true
    handle.paused?.should be_false
    handle.cancelled?.should be_false
    handle.finished?.should be_false
    handle.elapsed_time.should eq(0.0)
    handle.elapsed.should eq(0.0)
    handle.time_left.should eq(0.5)
    handle.tick_count.should eq(0_i64)
  end

  it "advances time and ticks at interval boundary" do
    handle = Godot::TimerHandle.new(1.0)
    handle.advance(0.4).should be_false
    handle.elapsed_time.should eq(0.4)
    handle.elapsed.should eq(0.4)
    handle.time_left.should be_close(0.6, 1e-5)
    handle.tick_count.should eq(0_i64)

    handle.advance(0.6).should be_true
    handle.tick_count.should eq(1_i64)
    handle.elapsed_time.should eq(0.0)
    handle.time_left.should eq(1.0)
  end

  it "supports record_tick! and reset" do
    handle = Godot::TimerHandle.new(0.8)
    handle.advance(0.4)
    handle.record_tick!
    handle.tick_count.should eq(1_i64)

    handle.reset
    handle.elapsed.should eq(0.0)
    handle.tick_count.should eq(0_i64)
  end

  it "supports pause and resume" do
    handle = Godot::TimerHandle.new(1.0)
    handle.pause
    handle.paused?.should be_true
    handle.advance(2.0).should be_false
    handle.tick_count.should eq(0_i64)

    handle.resume
    handle.paused?.should be_false
    handle.advance(1.0).should be_true
    handle.tick_count.should eq(1_i64)
  end

  it "supports cancel and stop" do
    handle = Godot::TimerHandle.new(0.2)
    handle.cancel
    handle.running?.should be_false
    handle.cancelled?.should be_true
    handle.finished?.should be_true
    handle.time_left.should eq(0.0)
    handle.advance(1.0).should be_false
    handle.tick_count.should eq(0_i64)

    handle2 = Godot::TimerHandle.new(0.3)
    handle2.stop
    handle2.cancelled?.should be_true
    handle2.finished?.should be_true
  end

  it "automatically cancels when bound node is destroyed" do
    node = Godot.create(Godot::Node)
    handle = Godot::TimerHandle.new(0.1, node)
    handle.advance(0.05).should be_false

    node.destroy
    handle.advance(0.1).should be_false
    handle.cancelled?.should be_true
    handle.running?.should be_false
    handle.finished?.should be_true
  end

  it "supports top-level and Node every/after helper methods" do
    node = Godot.create(Godot::Node)

    # Node#every with Time::Span
    h_every = node.every(0.5.seconds) do |h|
      # block
    end
    h_every.should be_a(Godot::TimerHandle)
    h_every.interval_sec.should eq(0.5)
    h_every.cancel

    # Node#after with Float
    h_after = node.after(1.0) do
      # block
    end
    h_after.should be_a(Godot::TimerHandle)
    h_after.interval_sec.should eq(1.0)
    h_after.cancel

    # Top-level every with Number
    h_top_every = every(0.25) do |h|
      # block
    end
    h_top_every.should be_a(Godot::TimerHandle)
    h_top_every.interval_sec.should eq(0.25)
    h_top_every.cancel

    # Top-level after with Time::Span
    h_top_after = after(0.75.seconds) do
      # block
    end
    h_top_after.should be_a(Godot::TimerHandle)
    h_top_after.interval_sec.should eq(0.75)
    h_top_after.cancel

    node.destroy
  end
end
