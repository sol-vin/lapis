require "./spec_helper"

describe "AwaitState and AwaitStatus(T)" do
  describe "AwaitState" do
    it "exposes completed?, timed_out?, freed?, disposed?, and ok?" do
      c = Godot::AwaitState::Completed
      c.completed?.should be_true
      c.timed_out?.should be_false
      c.freed?.should be_false
      c.disposed?.should be_false
      c.ok?.should be_true

      t = Godot::AwaitState::TimedOut
      t.completed?.should be_false
      t.timed_out?.should be_true
      t.freed?.should be_false
      t.disposed?.should be_false
      t.ok?.should be_false

      f = Godot::AwaitState::Freed
      f.completed?.should be_false
      f.timed_out?.should be_false
      f.freed?.should be_true
      f.disposed?.should be_true
      f.ok?.should be_false
    end
  end

  describe "AwaitStatus(T) struct" do
    it "handles successful completion with value" do
      status = Godot::AwaitStatus(Int32).completed(42)
      status.completed?.should be_true
      status.timed_out?.should be_false
      status.freed?.should be_false
      status.disposed?.should be_false
      status.ok?.should be_true
      status.status.should eq(Godot::AwaitState::Completed)
      status.value.should eq(42)
      status.value!.should eq(42)
      status.value?.should eq(42)

      # Symbol and value equality
      (status == :completed).should be_true
      (status == :timed_out).should be_false
      (status == :freed).should be_false
      (status == :disposed).should be_false
      (status == Godot::AwaitState::Completed).should be_true
      (status == 42).should be_true
    end

    it "handles timeout and raises TimeoutError on value!" do
      status = Godot::AwaitStatus(Int32).timed_out
      status.completed?.should be_false
      status.timed_out?.should be_true
      status.freed?.should be_false
      status.disposed?.should be_false
      status.ok?.should be_false
      status.status.should eq(Godot::AwaitState::TimedOut)
      status.value.should be_nil
      status.value?.should be_nil

      (status == :timed_out).should be_true
      (status == :completed).should be_false
      (status == :freed).should be_false
      (status == Godot::AwaitState::TimedOut).should be_true

      expect_raises(Godot::TimeoutError) do
        status.value!
      end
    end

    it "handles freed/disposed state and raises DisposedObjectError on value!" do
      status = Godot::AwaitStatus(Int32).freed(12345_u64)
      status.completed?.should be_false
      status.timed_out?.should be_false
      status.freed?.should be_true
      status.disposed?.should be_true
      status.ok?.should be_false
      status.status.should eq(Godot::AwaitState::Freed)
      status.instance_id.should eq(12345_u64)
      status.value.should be_nil
      status.value?.should be_nil

      (status == :freed).should be_true
      (status == :disposed).should be_true
      (status == :completed).should be_false
      (status == :timed_out).should be_false
      (status == Godot::AwaitState::Freed).should be_true

      ex = expect_raises(Godot::DisposedObjectError) do
        status.value!
      end
      ex.instance_id.should eq(12345_u64)
    end

    it "handles AwaitStatus(Nil)" do
      status = Godot::AwaitStatus(Nil).completed
      status.completed?.should be_true
      status.timed_out?.should be_false
      status.freed?.should be_false
      status.value.should be_nil
      status.value!.should be_nil
      status.value?.should be_nil

      timed_out_status = Godot::AwaitStatus(Nil).timed_out
      timed_out_status.completed?.should be_false
      timed_out_status.timed_out?.should be_true
      expect_raises(Godot::TimeoutError) do
        timed_out_status.value!
      end

      freed_status = Godot::AwaitStatus(Nil).freed(999_u64)
      freed_status.completed?.should be_false
      freed_status.timed_out?.should be_false
      freed_status.freed?.should be_true
      freed_status.disposed?.should be_true
      freed_status.value?.should be_nil
      expect_raises(Godot::DisposedObjectError) do
        freed_status.value!
      end
    end

    it "supports element indexing and multiple assignment for Tuples" do
      status = Godot::AwaitStatus(Tuple(Int32, String)).completed({100, "Victory"})
      status.completed?.should be_true
      status[0].should eq(100)
      status[1].should eq("Victory")
      status.size.should eq(2)

      score, message = status
      score.should eq(100)
      message.should eq("Victory")
    end

    it "supports element indexing and multiple assignment for Arrays" do
      status = Godot::AwaitStatus(Array(String)).completed(["alpha", "beta", "gamma"])
      status.completed?.should be_true
      status[0].should eq("alpha")
      status[1].should eq("beta")
      status[2].should eq("gamma")
      status.size.should eq(3)
      status.first?.should eq("alpha")

      first, second = status
      first.should eq("alpha")
      second.should eq("beta")
    end

    it "forwards unknown methods to underlying value via forward_missing_to" do
      status = Godot::AwaitStatus(String).completed("hello world")
      status.upcase.should eq("HELLO WORLD")
      status.starts_with?("hello").should be_true
      status.size.should eq(11)
    end
  end

  describe "Duration and Span await / await! / await?" do
    it "Godot.await with number completes or times out" do
      # Very short wait
      status = Godot.await(0.001)
      status.should be_a(Godot::AwaitStatus(Nil))
      status.completed?.should be_true

      # Timeout shorter than wait
      to_status = Godot.await(0.2, timeout_sec: 0.005)
      to_status.timed_out?.should be_true
    end

    it "Godot.await! with number returns Void or raises TimeoutError" do
      Godot.await!(0.001).should be_nil

      expect_raises(Godot::TimeoutError) do
        Godot.await!(0.2, timeout_sec: 0.005)
      end
    end

    it "Godot.await? with number returns true on completion and false on timeout" do
      Godot.await?(0.001).should be_true
      Godot.await?(0.2, timeout_sec: 0.005).should be_false
    end

    it "Godot.await with Time::Span completes or times out" do
      status = Godot.await(1.milliseconds)
      status.completed?.should be_true

      to_status = Godot.await(200.milliseconds, timeout_sec: 0.005)
      to_status.timed_out?.should be_true
    end

    it "Godot.await! with Time::Span returns Void or raises TimeoutError" do
      Godot.await!(1.milliseconds).should be_nil

      expect_raises(Godot::TimeoutError) do
        Godot.await!(200.milliseconds, timeout_sec: 0.005)
      end
    end

    it "Godot.await? with Time::Span returns true on completion and false on timeout" do
      Godot.await?(1.milliseconds).should be_true
      Godot.await?(200.milliseconds, timeout_sec: 0.005).should be_false
    end
  end

  describe "Macro await, await!, await?" do
    it "evaluates macro await for duration" do
      status = await(0.001)
      status.completed?.should be_true
    end

    it "evaluates macro await! for duration" do
      await!(0.001)
      expect_raises(Godot::TimeoutError) do
        await!(0.2, timeout_sec: 0.005)
      end
    end

    it "evaluates macro await? for duration" do
      res = await?(0.001)
      res.should be_true

      to_res = await?(0.2, timeout_sec: 0.005)
      to_res.should be_false
    end
  end
end
