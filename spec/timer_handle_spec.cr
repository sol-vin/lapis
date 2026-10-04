require "./spec_helper"

describe Godot::TimerHandle do
  it "initializes with interval and default state" do
    handle = Godot::TimerHandle.new(0.5)
    handle.interval_sec.should eq(0.5)
    handle.running?.should be_true
    handle.paused?.should be_false
    handle.cancelled?.should be_false
    handle.elapsed_time.should eq(0.0)
    handle.tick_count.should eq(0_i64)
  end

  it "advances time and ticks at interval boundary" do
    handle = Godot::TimerHandle.new(1.0)
    handle.advance(0.4).should be_false
    handle.elapsed_time.should eq(0.4)
    handle.tick_count.should eq(0_i64)

    handle.advance(0.6).should be_true
    handle.tick_count.should eq(1_i64)
    handle.elapsed_time.should eq(0.0)
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
    handle.advance(1.0).should be_false
    handle.tick_count.should eq(0_i64)
  end

  it "automatically cancels when bound node is destroyed" do
    node = Godot.create(Godot::Node)
    handle = Godot::TimerHandle.new(0.1, node)
    handle.advance(0.05).should be_false

    node.destroy
    handle.advance(0.1).should be_false
    handle.cancelled?.should be_true
    handle.running?.should be_false
  end
end
