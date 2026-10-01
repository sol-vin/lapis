require "./spec_helper"

describe "Godot::ThreadSafety & ThreadAffinityError Headless Specs" do
  before_each do
    Godot::ThreadSafety.reset!
    Godot::ThreadSafety.record_main_thread!
  end

  after_each do
    Godot::ThreadSafety.reset!
  end

  describe "Thread & Execution Context Detection" do
    it "identifies the current thread as Main Thread" do
      Godot::ThreadSafety.main_thread?.should be_true
      Godot::ThreadSafety.current_thread_id.should eq(Godot::ThreadSafety.main_thread_id)
    end

    it "detects unmanaged background threads (Thread.new) as non-main" do
      is_main = true
      detected_id = 0_u64
      t = Thread.new do
        is_main = Godot::ThreadSafety.main_thread?
        detected_id = Godot::ThreadSafety.current_thread_id
      end
      t.join

      is_main.should be_false
      detected_id.should_not eq(Godot::ThreadSafety.main_thread_id)
    end

    it "detects worker threads in Fiber::ExecutionContext::Parallel as non-main" do
      worker_pool = Fiber::ExecutionContext::Parallel.new("TestWorkerPool", maximum: 2)
      ch = Channel(NamedTuple(main: Bool, ec_name: String?)).new(1)

      worker_pool.spawn(name: "ChunkWorker") do
        f = Fiber.current
        ch.send({
          main: Godot::ThreadSafety.main_thread?,
          ec_name: f.execution_context?.try(&.name)
        })
      end

      res = ch.receive
      res[:main].should be_false
      res[:ec_name].should eq("TestWorkerPool")
    end

    it "formats descriptive context information for Thread.new" do
      context_str = ""
      t = Thread.new do
        context_str = Godot::ThreadSafety.context_description
      end
      t.join

      context_str.should contain("Thread.new")
      context_str.should contain("OS Thread ID:")
    end

    it "formats descriptive context information for named ExecutionContext fibers" do
      ec = Fiber::ExecutionContext::Parallel.new("AudioPipeline", maximum: 1)
      ch = Channel(String).new(1)

      ec.spawn(name: "DSPWorker") do
        ch.send(Godot::ThreadSafety.context_description)
      end

      desc = ch.receive
      desc.should contain("DSPWorker")
      desc.should contain("AudioPipeline")
      desc.should contain("Fiber::ExecutionContext::Parallel")
    end
  end

  describe "Thread Affinity Assertion & Exceptions" do
    it "does not raise on the Main Thread" do
      expect_raises(Exception) do
        Godot::ThreadSafety.assert_main_thread!("add_child", "Node")
        raise "did_not_raise"
      end.message.should eq("did_not_raise")
    end

    it "raises Godot::ThreadAffinityError when called from Thread.new" do
      ex_caught : Godot::ThreadAffinityError? = nil
      t = Thread.new do
        begin
          Godot::ThreadSafety.assert_main_thread!("add_child", "Node")
        rescue ex : Godot::ThreadAffinityError
          ex_caught = ex
        end
      end
      t.join

      ex_caught.should_not be_nil
      if err = ex_caught
        err.operation.should eq("add_child")
        err.target_class.should eq("Node")
        err.message.not_nil!.should contain("Thread Affinity Violation")
        err.message.not_nil!.should contain("Node#add_child")
        err.message.not_nil!.should contain("call_deferred")
        err.message.not_nil!.should contain("defer_add_child")
      end
    end

    it "raises Godot::ThreadAffinityError when called from parallel ExecutionContext" do
      ec = Fiber::ExecutionContext::Parallel.new("ParallelPhysics", maximum: 1)
      ch = Channel(Godot::ThreadAffinityError?).new(1)

      ec.spawn(name: "RigidBodySolver") do
        begin
          Godot::ThreadSafety.assert_main_thread!("reparent", "Node")
          ch.send(nil)
        rescue ex : Godot::ThreadAffinityError
          ch.send(ex)
        end
      end

      err = ch.receive
      err.should_not be_nil
      if e = err
        e.operation.should eq("reparent")
        e.calling_context.should contain("RigidBodySolver")
        e.calling_context.should contain("ParallelPhysics")
      end
    end
  end

  describe "Enforcement Policies" do
    it "respects Policy::Disabled" do
      Godot::ThreadSafety.policy = Godot::ThreadSafety::Policy::Disabled
      raised = false

      t = Thread.new do
        begin
          Godot::ThreadSafety.assert_main_thread!("add_child", "Node")
        rescue
          raised = true
        end
      end
      t.join

      raised.should be_false
    end

    it "respects Policy::Warn without raising" do
      Godot::ThreadSafety.policy = Godot::ThreadSafety::Policy::Warn
      raised = false

      t = Thread.new do
        begin
          Godot::ThreadSafety.assert_main_thread!("add_child", "Node")
        rescue
          raised = true
        end
      end
      t.join

      raised.should be_false
    end
  end

  describe "Main Thread Work Queue" do
    it "executes blocks immediately when called on Main Thread" do
      executed = false
      Godot::ThreadSafety.run_on_main_thread do
        executed = true
      end
      executed.should be_true
    end

    it "enqueues blocks from background threads and executes upon flush" do
      executed_values = [] of Int32
      t = Thread.new do
        Godot::ThreadSafety.run_on_main_thread do
          executed_values << 100
        end
        Godot::ThreadSafety.run_on_main_thread do
          executed_values << 200
        end
      end
      t.join

      executed_values.should be_empty
      Godot::ThreadSafety.flush_main_thread_queue!
      executed_values.should eq([100, 200])
    end
  end
end
