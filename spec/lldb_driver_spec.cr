require "spec"
require "../src/libgodot/debugger/lldb_driver"

describe Godot::Debugger::LldbDriver do
  it "parses LLDB breakpoint stop event lines" do
    driver = Godot::Debugger::LldbDriver.new
    line = "* thread #1, stop reason = breakpoint 1.1\n    frame #0: 0x00007ff812345678 game.dll`Player#_physics_process(self=0x1234) at player.cr:42:5"
    info = driver.parse_stop_info(line)

    info.reason.should eq(Godot::Debugger::StopReason::Breakpoint)
    frame = info.frame
    frame.should_not be_nil
    if f = frame
      f.index.should eq(0)
      f.function.should contain("Player#_physics_process")
      f.file.should eq("player.cr")
      f.line.should eq(42)
    end
  end

  it "parses LLDB signal / exception stop events" do
    driver = Godot::Debugger::LldbDriver.new
    line = "* thread #2, stop reason = signal SIGSEGV: invalid address (fault address: 0x0)"
    info = driver.parse_stop_info(line)
    info.reason.should eq(Godot::Debugger::StopReason::Signal)
  end

  it "parses LLDB step stop events" do
    driver = Godot::Debugger::LldbDriver.new
    line = "* thread #1, stop reason = step over"
    info = driver.parse_stop_info(line)
    info.reason.should eq(Godot::Debugger::StopReason::Step)
  end

  it "parses LLDB user interrupt stop events" do
    driver = Godot::Debugger::LldbDriver.new
    line = "* thread #1, stop reason = interrupt"
    info = driver.parse_stop_info(line)
    info.reason.should eq(Godot::Debugger::StopReason::UserInterrupt)
  end

  it "handles frame formatting to string" do
    frame = Godot::Debugger::StackFrame.new(0, "Hero#attack", "src/hero.cr", 88)
    frame.to_s.should eq("0: Hero#attack at src/hero.cr:88")
  end

  it "initializes breakpoint info with correct defaults" do
    bp = Godot::Debugger::BreakpointInfo.new(1, "src/player.cr", 25)
    bp.id.should eq(1)
    bp.file.should eq("src/player.cr")
    bp.line.should eq(25)
    bp.hit_count.should eq(0)
    bp.enabled.should be_true
    bp.resolved.should be_false
  end

  it "parses Windows file paths with drive letters and column numbers in stack frames" do
    driver = Godot::Debugger::LldbDriver.new
    frame_line = "    frame #0: 0x00007ff812345678 game.dll`Player#_process(delta=0.016) at C:\\Users\\Ian\\Documents\\game\\src\\player.cr:120:9"
    frame = driver.parse_frame_line(frame_line)
    frame.should_not be_nil
    if f = frame
      f.index.should eq(0)
      f.function.should contain("Player#_process")
      f.file.should eq("C:/Users/Ian/Documents/game/src/player.cr")
      f.line.should eq(120)
    end
  end

  it "streams split multi-line stop events and invokes on_stop callback" do
    driver = Godot::Debugger::LldbDriver.new
    stopped_info : Godot::Debugger::StopInfo? = nil
    driver.on_stop = ->(info : Godot::Debugger::StopInfo) {
      stopped_info = info
    }

    # Line 1: Stop reason arrives
    driver.process_line("* thread #1, stop reason = breakpoint 1.1")
    stopped_info.should be_nil # Waiting for frame line or confirmation

    # Line 2: Frame #0 line arrives
    driver.process_line("    frame #0: 0x00007ff812345678 game.dll`Enemy#take_damage(amount=10) at C:\\game\\src\\enemy.cr:77:3")
    stopped_info.should_not be_nil
    if info = stopped_info
      info.reason.should eq(Godot::Debugger::StopReason::Breakpoint)
      info.frame.should_not be_nil
      if frame = info.frame
        frame.index.should eq(0)
        frame.function.should contain("Enemy#take_damage")
        frame.file.should eq("C:/game/src/enemy.cr")
        frame.line.should eq(77)
      end
    end
  end

  it "parses thread backtrace output and invokes on_backtrace callback" do
    driver = Godot::Debugger::LldbDriver.new
    received_frames : Array(Godot::Debugger::StackFrame)? = nil
    driver.on_backtrace = ->(frames : Array(Godot::Debugger::StackFrame)) {
      received_frames = frames
    }

    driver.request_backtrace
    driver.process_line("* thread #1, stop reason = breakpoint 1.1")
    driver.process_line("  * frame #0: 0x00007ff812345678 game.dll`Enemy#die at C:\\game\\src\\enemy.cr:95:5")
    driver.process_line("    frame #1: 0x00007ff823456789 game.dll`Enemy#take_damage at C:\\game\\src\\enemy.cr:80:12")
    driver.process_line("    frame #2: 0x00007ff83456789a game.dll`Main#_physics_process at C:\\game\\src\\main.cr:44")
    driver.process_line("(lldb) ")

    received_frames.should_not be_nil
    if frames = received_frames
      frames.size.should eq(3)
      frames[0].index.should eq(0)
      frames[0].function.should contain("Enemy#die")
      frames[0].file.should eq("C:/game/src/enemy.cr")
      frames[0].line.should eq(95)

      frames[1].index.should eq(1)
      frames[1].function.should contain("Enemy#take_damage")
      frames[1].file.should eq("C:/game/src/enemy.cr")
      frames[1].line.should eq(80)

      frames[2].index.should eq(2)
      frames[2].function.should contain("Main#_physics_process")
      frames[2].file.should eq("C:/game/src/main.cr")
      frames[2].line.should eq(44)
    end
  end

  it "caches pre-attach breakpoints and tracks them in breakpoints collection" do
    driver = Godot::Debugger::LldbDriver.new
    # Setting breakpoints when detached queues them in @breakpoints without error
    driver.set_breakpoint("C:\\game\\src\\player.cr", 42)
    driver.set_breakpoint("C:\\game\\src\\enemy.cr", 90)

    driver.breakpoints.size.should eq(2)
    bp1 = driver.breakpoints[1]?
    bp1.should_not be_nil
    if bp = bp1
      bp.file.should eq("C:/game/src/player.cr")
      bp.line.should eq(42)
    end

    bp2 = driver.breakpoints[2]?
    bp2.should_not be_nil
    if bp = bp2
      bp.file.should eq("C:/game/src/enemy.cr")
      bp.line.should eq(90)
    end
  end
end
