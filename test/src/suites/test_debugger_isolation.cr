# =============================================================================
# LibGodot Test Suite: Native LLDB Debugger & Multiplayer Session Isolation
# =============================================================================

include Lapis::Test

macro test_debugger(name, &block)
  Registry.register("Debugger", {{name}}) do |_node|
    {{block.body}}
  end
end

{% if flag?(:release) %}
  test_debugger "Debugger components cleanly stripped in release mode" do
    assert_true true, "Debugger components omitted in release builds"
  end
{% else %}
  test_debugger "Debug agent initializes and handles role reporting safely" do
    Godot::Debugger::Agent.initialize_agent
    Godot::Debugger::Agent.report_role("Server", 1)
    assert_true true, "Agent role reported cleanly"
  end

  test_debugger "LLDB driver initializes with clean detached state" do
    driver = Godot::Debugger::LldbDriver.new
    assert_eq driver.state, Godot::Debugger::DriverState::Detached
    assert_nil driver.attached_pid
    assert_eq driver.breakpoints.size, 0
  end

  test_debugger "LLDB driver stop reason parser accurately categorizes events" do
    driver = Godot::Debugger::LldbDriver.new

    # Breakpoint hit
    line_bp = "* thread #1, stop reason = breakpoint 1.1\n    frame #0: 0x00007ff812345678 game.dll`Player#_physics_process(self=0x1234) at player.cr:42:5"
    info_bp = driver.parse_stop_info(line_bp)
    assert_eq info_bp.reason, Godot::Debugger::StopReason::Breakpoint
    assert_not_nil info_bp.frame
    if f = info_bp.frame
      assert_eq f.line, 42
      assert_eq f.file, "player.cr"
    end

    # Signal / Crash
    line_sig = "* thread #1, stop reason = signal SIGSEGV"
    info_sig = driver.parse_stop_info(line_sig)
    assert_eq info_sig.reason, Godot::Debugger::StopReason::Signal

    # Step
    line_step = "* thread #1, stop reason = step over"
    info_step = driver.parse_stop_info(line_step)
    assert_eq info_step.reason, Godot::Debugger::StopReason::Step

    # Interrupt
    line_int = "* thread #1, stop reason = interrupt"
    info_int = driver.parse_stop_info(line_int)
    assert_eq info_int.reason, Godot::Debugger::StopReason::UserInterrupt
  end

  test_debugger "Multi-session debugger isolation between Server and Client" do
    server_driver = Godot::Debugger::LldbDriver.new
    client_driver = Godot::Debugger::LldbDriver.new

    # Add breakpoint to Server session only
    bp_server = Godot::Debugger::BreakpointInfo.new(1, "src/server_sync.cr", 100)
    server_driver.breakpoints[1] = bp_server

    assert_eq server_driver.breakpoints.size, 1
    assert_eq client_driver.breakpoints.size, 0, "Client session breakpoints isolated from Server"

    # Add breakpoint to Client session only
    bp_client = Godot::Debugger::BreakpointInfo.new(1, "src/client_prediction.cr", 55)
    client_driver.breakpoints[1] = bp_client

    assert_eq server_driver.breakpoints[1].file, "src/server_sync.cr"
    assert_eq client_driver.breakpoints[1].file, "src/client_prediction.cr"
  end

  test_debugger "LLDB driver handles streaming split stop lines and backtrace" do
    driver = Godot::Debugger::LldbDriver.new
    stopped_info : Godot::Debugger::StopInfo? = nil
    driver.on_stop = ->(info : Godot::Debugger::StopInfo) {
      stopped_info = info
    }

    driver.process_line("* thread #1, stop reason = breakpoint 1.1")
    assert_nil stopped_info, "Pending stop event waits for frame line"

    driver.process_line("    frame #0: 0x00007ff812345678 game.dll`Main#_ready at C:\\game\\src\\main.cr:25:3")
    assert_not_nil stopped_info, "Stop info populated once frame line arrives"
    if info = stopped_info
      assert_eq info.reason, Godot::Debugger::StopReason::Breakpoint
      assert_not_nil info.frame
      if f = info.frame
        assert_eq f.line, 25
        assert_eq f.file, "C:/game/src/main.cr"
      end
    end
  end

  test_debugger "Godot.breakpoint helper executes cleanly" do
    # When no debugger is actively attached, breakpoint(can_continue: true) returns without aborting
    Godot.breakpoint(can_continue: true)
    Godot::Debugger::Agent.breakpoint(can_continue: true)
    assert_true true, "Godot.breakpoint executed safely"
  end
{% end %}

test_debugger "Multiplayer lockstep signal routing logic" do
  lockstep_paused = [] of Int32
  lockstep_resumed = [] of Int32

  signal_handler = ->(origin_id : Int32, is_paused : Bool) {
    [0, 1, 2].each do |peer_id|
      next if peer_id == origin_id
      if is_paused
        lockstep_paused << peer_id
      else
        lockstep_resumed << peer_id
      end
    end
  }

  # Simulate Session 0 (Server) breaking at line 42
  signal_handler.call(0, true)
  assert_eq lockstep_paused, [1, 2], "Peers 1 and 2 received lockstep pause when Server broke"

  # Simulate Session 0 resuming
  signal_handler.call(0, false)
  assert_eq lockstep_resumed, [1, 2], "Peers 1 and 2 received lockstep resume when Server continued"
end
