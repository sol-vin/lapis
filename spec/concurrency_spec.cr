require "./spec_helper"

describe "LibGodot Concurrency & Thread Safety" do
  describe "Godot::Channel Actor Communication" do
    it "transfers data across background OS worker threads and main thread" do
      channel = Godot::Channel.new(10)

      worker = Thread.new do
        (1..5).each do |num|
          channel.send("Message_#{num * 10}")
        end
      end

      worker.join
      channel.size.should eq(5)

      results = [] of String
      5.times do
        results << channel.try_receive.not_nil!.to_s
      end

      results.should eq(["Message_10", "Message_20", "Message_30", "Message_40", "Message_50"])
      channel.empty?.should be_true
      channel.close
    end

    it "handles multi-producer thread contention safely without message corruption" do
      channel = Godot::Channel.new(100)
      worker_count = 4
      items_per_worker = 25

      workers = (1..worker_count).map do |w_id|
        Thread.new do
          items_per_worker.times do |item_idx|
            channel.send("Worker#{w_id}_Item#{item_idx}")
          end
        end
      end

      workers.each(&.join)
      channel.size.should eq(100)

      drained = [] of String
      while item = channel.try_receive
        drained << item.to_s
      end

      drained.size.should eq(100)
      channel.is_empty.should be_true
      channel.close
    end

    it "unblocks waiting background receiver threads when closed" do
      channel = Godot::Channel.new(4)
      receiver_done = false
      received_result : Godot::ChannelItem? = "initial"

      worker = Thread.new do
        received_result = channel.receive(timeout_sec: 2.0)
        receiver_done = true
      end

      # Give worker time to enter wait state
      Crystal::System::Thread.sleep(10.milliseconds)

      channel.close
      worker.join

      receiver_done.should be_true
      received_result.should be_nil
      channel.is_closed.should be_true
      channel.send("post_close").should be_false
    end
  end

  describe "Godot::TypedChannel(T)" do
    it "provides strongly-typed message passing for Godot types" do
      typed_chan = Godot::TypedChannel(Godot::Vector3).new(5)

      worker = Thread.new do
        typed_chan.send(Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32))
        typed_chan.send(Godot::Vector3.new(4.0_f32, 5.0_f32, 6.0_f32))
      end

      worker.join
      typed_chan.size.should eq(2)

      v1 = typed_chan.try_receive.not_nil!
      v1.x.should eq(1.0_f32)
      v1.y.should eq(2.0_f32)
      v1.z.should eq(3.0_f32)

      v2 = typed_chan.try_receive.not_nil!
      v2.x.should eq(4.0_f32)
      v2.y.should eq(5.0_f32)
      v2.z.should eq(6.0_f32)

      typed_chan.close
      typed_chan.closed?.should be_true
    end
  end

  describe "Cooperative Fiber Scheduling with Godot.spawn & Godot.delay" do
    it "cooperatively executes spawned gameplay fibers without blocking" do
      log = [] of String

      Godot.spawn do
        log << "fiber_start"
        Fiber.yield
        log << "fiber_step"
        Fiber.yield
        log << "fiber_end"
      end

      # Allow cooperative fiber execution slices
      5.times { Fiber.yield }

      log.should eq(["fiber_start", "fiber_step", "fiber_end"])
    end

    it "cooperatively pauses with Godot.delay" do
      start_time = ::Time.instant
      Godot.delay(0.02)
      elapsed = (::Time.instant - start_time).total_seconds
      (elapsed >= 0.015).should be_true
    end
  end

  describe "Godot Collections Interoperability" do
    it "converts Crystal Hash to Godot::Dictionary and supports key-value operations" do
      hash = {"level" => "5", "difficulty" => "hard"}
      dict = hash.to_godot_dict

      dict.size.should eq(2)
      dict["level"].should eq("5")
      dict["difficulty"].should eq("hard")
      dict.has_key?("level").should be_true
      dict.has_key?("missing").should be_false

      dict["score"] = "1000"
      dict.size.should eq(3)
      dict["score"].should eq("1000")

      roundtrip = dict.to_h
      roundtrip["score"].should eq("1000")
    end

    it "converts Crystal Array to Godot::Array and supports Enumerable methods" do
      arr = [10, 20, 30]
      g_arr = arr.to_godot_array

      g_arr.size.should eq(3)
      g_arr[0].should eq(10)
      g_arr[1].should eq(20)
      g_arr[2].should eq(30)

      g_arr << 40
      g_arr.size.should eq(4)
      g_arr.to_a.should eq([10, 20, 30, 40])
    end
  end
end
