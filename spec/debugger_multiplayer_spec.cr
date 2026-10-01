require "spec"
require "../src/editor/debugger/crystal_debugger_plugin"
require "../src/editor/debugger/session_controller"

describe "Multiplayer Debugging & Lockstep Synchronization" do
  describe "Multi-Session Architecture & Role Classification" do
    it "initializes multiple peer sessions with distinct roles and process IDs" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      server_ctrl = Godot::DebuggerSessionController.new(0, dummy_session)
      server_ctrl.update_role("Server", 1001_i64)
      plugin.register_session_controller(server_ctrl)

      client1_ctrl = Godot::DebuggerSessionController.new(1, dummy_session)
      client1_ctrl.update_role("Client 1", 1002_i64)
      plugin.register_session_controller(client1_ctrl)

      client2_ctrl = Godot::DebuggerSessionController.new(2, dummy_session)
      client2_ctrl.update_role("Client 2", 1003_i64)
      plugin.register_session_controller(client2_ctrl)

      plugin.sessions.size.should eq(3)
      plugin.server_session.should_not be_nil
      plugin.server_session.try(&.role).should eq("Server")
      plugin.server_session.try(&.target_pid).should eq(1001_i64)

      clients = plugin.client_sessions
      clients.size.should eq(2)
      clients.map(&.role).should contain("Client 1")
      clients.map(&.role).should contain("Client 2")

      c1 = plugin.sessions_for_role("Client 1")
      c1.size.should eq(1)
      c1.first.session_id.should eq(1)

      plugin.cleanup
    end

    it "handles capture messages to dynamically assign multiplayer roles" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      s0 = Godot::DebuggerSessionController.new(0, dummy_session)
      s1 = Godot::DebuggerSessionController.new(1, dummy_session)
      plugin.register_session_controller(s0)
      plugin.register_session_controller(s1)

      # Server announces role via TCP capture
      plugin.handle_capture("lapis:ready:2048:DedicatedServer", 0).should be_true
      s0.role.should eq("DedicatedServer")
      s0.target_pid.should eq(2048_i64)

      # Client announces role via TCP capture
      plugin.handle_capture("lapis:ready:4096:Client 1", 1).should be_true
      s1.role.should eq("Client 1")
      s1.target_pid.should eq(4096_i64)

      plugin.server_session.should eq(s0)
      plugin.client_sessions.should eq([s1])

      plugin.cleanup
    end
  end

  describe "Multi-Peer Breakpoint Synchronization" do
    it "propagates active breakpoints across all connected multiplayer instances" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      server = Godot::DebuggerSessionController.new(0, dummy_session)
      client = Godot::DebuggerSessionController.new(1, dummy_session)
      plugin.register_session_controller(server)
      plugin.register_session_controller(client)

      # Set breakpoint in game code
      plugin.handle_breakpoint_toggle("res://src/player.cr", 42, true)

      server.driver.breakpoints.size.should eq(1)
      server.driver.breakpoints[1].file.should eq("res://src/player.cr")
      server.driver.breakpoints[1].line.should eq(42)

      client.driver.breakpoints.size.should eq(1)
      client.driver.breakpoints[1].file.should eq("res://src/player.cr")
      client.driver.breakpoints[1].line.should eq(42)

      # Remove breakpoint
      plugin.handle_breakpoint_toggle("res://src/player.cr", 42, false)
      server.driver.breakpoints.empty?.should be_true
      client.driver.breakpoints.empty?.should be_true

      plugin.cleanup
    end

    it "automatically provisions pre-existing breakpoints to late-joining client instances" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      # Breakpoints created prior to client connection
      plugin.handle_breakpoint_toggle("res://src/net/sync.cr", 88, true)
      plugin.handle_breakpoint_toggle("res://src/net/rpc.cr", 120, true)

      # Late-joining client session connects
      late_client = Godot::DebuggerSessionController.new(2, dummy_session)
      late_client.driver.breakpoints.size.should eq(0)

      plugin.register_session_controller(late_client)

      # Late client should now possess all active breakpoints
      late_client.driver.breakpoints.size.should eq(2)
      bps = late_client.driver.breakpoints.values
      bps.map(&.file).should contain("res://src/net/sync.cr")
      bps.map(&.line).should contain(88)
      bps.map(&.file).should contain("res://src/net/rpc.cr")
      bps.map(&.line).should contain(120)

      plugin.cleanup
    end
  end

  describe "Lockstep Pause & Resume Propagation" do
    it "pauses all multiplayer peers in lockstep when one peer breaks" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      server = Godot::DebuggerSessionController.new(0, dummy_session)
      client1 = Godot::DebuggerSessionController.new(1, dummy_session)
      client2 = Godot::DebuggerSessionController.new(2, dummy_session)

      plugin.register_session_controller(server)
      plugin.register_session_controller(client1)
      plugin.register_session_controller(client2)

      # Simulate all 3 instances currently running gameplay loop
      server.driver.state = Godot::Debugger::DriverState::Running
      client1.driver.state = Godot::Debugger::DriverState::Running
      client2.driver.state = Godot::Debugger::DriverState::Running

      plugin.all_sessions_running?.should be_true
      plugin.all_sessions_paused?.should be_false

      # Client 1 encounters a breakpoint stop event
      stop_info = Godot::Debugger::StopInfo.new(
        reason: Godot::Debugger::StopReason::Breakpoint,
        thread_id: 1,
        frame: Godot::Debugger::StackFrame.new(0, "Player#take_damage", "src/player.cr", 50),
        description: "Hit breakpoint 1 at src/player.cr:50"
      )

      # Trigger client 1 on_stop callback (origin break)
      client1.driver.on_stop.try(&.call(stop_info))

      # Client 1 paused due to breakpoint
      client1.driver.lockstep_paused_externally.should be_false

      # Server and Client 2 cooperatively paused via lockstep
      server.driver.state.should eq(Godot::Debugger::DriverState::Paused)
      server.driver.lockstep_paused_externally.should be_true

      client2.driver.state.should eq(Godot::Debugger::DriverState::Paused)
      client2.driver.lockstep_paused_externally.should be_true

      plugin.all_sessions_paused?.should be_true

      plugin.cleanup
    end

    it "resumes all multiplayer peers in lockstep when the origin peer continues" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      server = Godot::DebuggerSessionController.new(0, dummy_session)
      client1 = Godot::DebuggerSessionController.new(1, dummy_session)
      client2 = Godot::DebuggerSessionController.new(2, dummy_session)

      plugin.register_session_controller(server)
      plugin.register_session_controller(client1)
      plugin.register_session_controller(client2)

      # Set all to paused
      server.driver.state = Godot::Debugger::DriverState::Paused
      server.driver.lockstep_paused_externally = true

      client1.driver.state = Godot::Debugger::DriverState::Paused
      client1.driver.lockstep_paused_externally = false # Origin

      client2.driver.state = Godot::Debugger::DriverState::Paused
      client2.driver.lockstep_paused_externally = true

      # Client 1 developer clicks Continue
      client1.driver.on_continue.try(&.call)

      # All peers should resume in lockstep
      server.driver.state.should eq(Godot::Debugger::DriverState::Running)
      server.driver.lockstep_paused_externally.should be_false

      client2.driver.state.should eq(Godot::Debugger::DriverState::Running)
      client2.driver.lockstep_paused_externally.should be_false

      plugin.cleanup
    end

    it "does not trigger cascade feedback loop when peer is paused by lockstep" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      server = Godot::DebuggerSessionController.new(0, dummy_session)
      client1 = Godot::DebuggerSessionController.new(1, dummy_session)

      plugin.register_session_controller(server)
      plugin.register_session_controller(client1)

      server.driver.state = Godot::Debugger::DriverState::Running
      client1.driver.state = Godot::Debugger::DriverState::Running

      lockstep_signal_count = 0
      server.on_lockstep_signal = ->(origin : Int32, paused : Bool) {
        lockstep_signal_count += 1
      }
      client1.on_lockstep_signal = ->(origin : Int32, paused : Bool) {
        lockstep_signal_count += 1
      }

      # Pause server externally
      server.lockstep_pause
      server.driver.state.should eq(Godot::Debugger::DriverState::Paused)
      server.driver.lockstep_paused_externally.should be_true

      # Now simulate driver on_stop firing on server as a result of interrupt
      stop_info = Godot::Debugger::StopInfo.new(reason: Godot::Debugger::StopReason::UserInterrupt)
      server.driver.on_stop.try(&.call(stop_info))

      # Since lockstep_paused_externally was true, it must NOT re-signal lockstep
      lockstep_signal_count.should eq(0)

      plugin.cleanup
    end

    it "respects lockstep_enabled = false to isolate an instance from global halts" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      server = Godot::DebuggerSessionController.new(0, dummy_session)
      isolated_client = Godot::DebuggerSessionController.new(1, dummy_session)
      normal_client = Godot::DebuggerSessionController.new(2, dummy_session)

      # Disable lockstep on isolated_client
      isolated_client.lockstep_enabled = false

      plugin.register_session_controller(server)
      plugin.register_session_controller(isolated_client)
      plugin.register_session_controller(normal_client)

      server.driver.state = Godot::Debugger::DriverState::Running
      isolated_client.driver.state = Godot::Debugger::DriverState::Running
      normal_client.driver.state = Godot::Debugger::DriverState::Running

      # Isolated client hits a breakpoint; should not broadcast lockstep to peers
      stop_info = Godot::Debugger::StopInfo.new(reason: Godot::Debugger::StopReason::Breakpoint)
      isolated_client.driver.on_stop.try(&.call(stop_info))

      # Peers should still be running!
      server.driver.state.should eq(Godot::Debugger::DriverState::Running)
      normal_client.driver.state.should eq(Godot::Debugger::DriverState::Running)

      plugin.cleanup
    end
  end

  describe "Multiplayer RPC Message Capture & Trace Logging" do
    it "captures network RPC message events and records them in session RPC trace" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      server = Godot::DebuggerSessionController.new(0, dummy_session)
      server.update_role("Server", 100)
      client = Godot::DebuggerSessionController.new(1, dummy_session)
      client.update_role("Client 1", 101)

      plugin.register_session_controller(server)
      plugin.register_session_controller(client)

      # Client sends RPC to Server
      plugin.handle_capture("lapis:rpc:1:cast_spell:spell_id=fireball,power=100", 0).should be_true
      server.rpc_trace_log.size.should eq(1)
      server.rpc_trace_log.first.should contain("cast_spell(spell_id=fireball,power=100)")
      server.rpc_trace_log.first.should contain("RPC from 1 -> Server")

      # Server sends RPC to Client
      plugin.handle_capture("lapis:rpc:0:spawn_projectile:x=12.5,y=0.0,z=-5.0", 1).should be_true
      client.rpc_trace_log.size.should eq(1)
      client.rpc_trace_log.first.should contain("spawn_projectile")
      client.rpc_trace_log.first.should contain("RPC from 0 -> Client 1")

      plugin.cleanup
    end

    it "traces sequence of multi-hop RPC packets across server and multiple clients" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      server = Godot::DebuggerSessionController.new(0, dummy_session)
      server.update_role("Server", 500)
      c1 = Godot::DebuggerSessionController.new(1, dummy_session)
      c1.update_role("Client 1", 501)
      c2 = Godot::DebuggerSessionController.new(2, dummy_session)
      c2.update_role("Client 2", 502)

      plugin.register_session_controller(server)
      plugin.register_session_controller(c1)
      plugin.register_session_controller(c2)

      # 1. Client 1 sends input action to Server
      plugin.handle_capture("lapis:rpc:1:player_jump:velocity=15.0", 0).should be_true

      # 2. Server broadcasts position update to Client 1 and Client 2
      plugin.handle_capture("lapis:rpc:0:sync_position:entity=1,y=15.0", 1).should be_true
      plugin.handle_capture("lapis:rpc:0:sync_position:entity=1,y=15.0", 2).should be_true

      server.rpc_trace_log.size.should eq(1)
      c1.rpc_trace_log.size.should eq(1)
      c2.rpc_trace_log.size.should eq(1)

      server.rpc_trace_log.first.should contain("player_jump")
      c1.rpc_trace_log.first.should contain("sync_position")
      c2.rpc_trace_log.first.should contain("sync_position")

      plugin.cleanup
    end
  end

  describe "Multiplayer Peer Disconnect & Session Lifecycles" do
    it "cleans up detached sessions while preserving active multiplayer peers" do
      plugin = Godot::CrystalDebuggerPlugin.new
      dummy_session = Godot::EditorDebuggerSession.new(Pointer(Void).null)

      s0 = Godot::DebuggerSessionController.new(0, dummy_session)
      s1 = Godot::DebuggerSessionController.new(1, dummy_session)
      plugin.register_session_controller(s0)
      plugin.register_session_controller(s1)

      plugin.sessions.size.should eq(2)

      # Client 1 disconnects
      s1.cleanup
      plugin.sessions.delete(1)

      plugin.sessions.size.should eq(1)
      plugin.sessions.has_key?(0).should be_true
      plugin.sessions.has_key?(1).should be_false

      plugin.cleanup
    end
  end
end
