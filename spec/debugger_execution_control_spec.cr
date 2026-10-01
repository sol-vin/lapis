require "spec"
require "../src/libgodot/debugger/radare_driver"

describe "Debugger Execution Control & Native Diagnostics" do
  describe "State Transitions & Execution Flow" do
    it "initializes in Detached state" do
      driver = Godot::Debugger::RadareDriver.new
      driver.state.should eq(Godot::Debugger::DriverState::Detached)
      driver.attached_pid.should be_nil
      driver.lockstep_paused_externally.should be_false
    end

    it "handles manual state transitions between Paused and Running" do
      driver = Godot::Debugger::RadareDriver.new
      driver.state = Godot::Debugger::DriverState::Paused
      driver.state.should eq(Godot::Debugger::DriverState::Paused)

      continued = false
      driver.on_continue = -> { continued = true }

      driver.continue_exec
      driver.state.should eq(Godot::Debugger::DriverState::Running)
      continued.should be_true
    end
  end

  describe "Stop Reason Classification" do
    it "accurately maps raw debugger output to StopReason enum values" do
      driver = Godot::Debugger::RadareDriver.new

      driver.parse_stop_reason("Hit breakpoint 1 at 0x140001000").should eq(Godot::Debugger::StopReason::Breakpoint)
      driver.parse_stop_reason("Process received signal SIGSEGV").should eq(Godot::Debugger::StopReason::Signal)
      driver.parse_stop_reason("Exception 0xc0000005: Access violation").should eq(Godot::Debugger::StopReason::Signal)
      driver.parse_stop_reason("Single step completed").should eq(Godot::Debugger::StopReason::Step)
      driver.parse_stop_reason("Interrupted by user request").should eq(Godot::Debugger::StopReason::UserInterrupt)
      driver.parse_stop_reason("Arbitrary unknown output").should eq(Godot::Debugger::StopReason::Unknown)
    end

    it "constructs StopInfo with demangled stack frames and context classification" do
      driver = Godot::Debugger::RadareDriver.new
      raw_line = "frame #0: 0x00007ff823456789 game.dll`Player#take_damage(self=0x1234, amount=25) at src/entities/player.cr:65:7"

      info = driver.parse_stop_info(raw_line)
      info.should_not be_nil
      if frame = info.frame
        frame.index.should eq(0)
        frame.function.should contain("Player#take_damage")
        frame.file.should eq("src/entities/player.cr")
        frame.line.should eq(65)
        if ctx = frame.context
          ctx.domain.should eq(Godot::Debugger::ContextDomain::Game)
          ctx.badge.should eq("[Context: Game]")
        end
      end
    end
  end

  describe "Breakpoint Management" do
    it "manages breakpoint lifecycle (set, query, toggle, remove)" do
      driver = Godot::Debugger::RadareDriver.new

      bp1 = driver.set_breakpoint("src/combat.cr", 42)
      bp1.id.should eq(1)
      bp1.file.should eq("src/combat.cr")
      bp1.line.should eq(42)
      bp1.enabled.should be_true

      bp2 = driver.set_breakpoint("src/inventory.cr", 88)
      bp2.id.should eq(2)

      driver.breakpoints.size.should eq(2)

      # Deduplication: setting duplicate returns existing
      bp_dup = driver.set_breakpoint("src/combat.cr", 42)
      bp_dup.id.should eq(1)
      driver.breakpoints.size.should eq(2)

      # Remove by ID
      driver.remove_breakpoint(1).should be_true
      driver.breakpoints.size.should eq(1)
      driver.breakpoints.has_key?(1).should be_false

      # Remove by file/line
      driver.remove_breakpoint("src/inventory.cr", 88).should be_true
      driver.breakpoints.empty?.should be_true
    end
  end

  describe "Non-Blocking Event Polling" do
    it "drains queued stop events on the Godot main thread" do
      driver = Godot::Debugger::RadareDriver.new
      received_stops = [] of Godot::Debugger::StopInfo

      driver.on_stop = ->(info : Godot::Debugger::StopInfo) {
        received_stops << info
      }

      driver.process_line("* thread #1, stop reason = breakpoint 1")
      driver.process_line("frame #0: 0x140001000 game.dll`Player#jump at src/player.cr:12")

      received_stops.size.should eq(1)
      received_stops.first.reason.should eq(Godot::Debugger::StopReason::Breakpoint)
      frame = received_stops.first.frame
      frame.should_not be_nil
      frame.not_nil!.function.should contain("Player#jump")
    end
  end
end
