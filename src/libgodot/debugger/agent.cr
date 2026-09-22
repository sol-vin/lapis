# =============================================================================
# LibGodot - Crystal Game Instance Debug Agent
# =============================================================================
# Runs inside the running game process (game.dll or standalone game.exe).
# Communicates with the Godot Editor via EngineDebugger TCP messaging,
# reporting the OS Process ID (PID) and multiplayer role to ensure LLDB
# attaches to the correct session.

require "../generated/singletons"

module Lapis
  include Godot
  module Debugger
    class Agent
      @@initialized : Bool = false
      @@cached_role : String = "Peer"
      @@cached_peer_id : Int32 = 0

      # Initializes the debug agent inside the running game instance
      def self.initialize_agent : Void
        return if @@initialized
        @@initialized = true

        if !Godot::EngineDebugger.singleton_ptr.null?
          ed = Godot::EngineDebugger.new(Godot::EngineDebugger.singleton_ptr)
          if ed.call_bool("is_active")
            pid = Process.pid.to_i64
            role = detect_role
            msg = "crystal_debugger:ready:#{pid}:#{role}:#{@@cached_peer_id}"
            ed.call("send_message", msg)
            Godot.print("[CrystalDebugAgent] Connected to editor debugger. Reported PID: #{pid}, Role: #{role}")
          end
        end
      rescue ex
        Godot.print("[CrystalDebugAgent] Notice: #{ex.message}")
      end

      # Updates the multiplayer role of this instance (e.g. Server, Client 1, Client 2)
      def self.report_role(role : String, peer_id : Int32 = 0) : Void
        @@cached_role = role
        @@cached_peer_id = peer_id

        if !Godot::EngineDebugger.singleton_ptr.null?
          ed = Godot::EngineDebugger.new(Godot::EngineDebugger.singleton_ptr)
          if ed.call_bool("is_active")
            pid = Process.pid.to_i64
            msg = "crystal_debugger:role:#{pid}:#{role}:#{peer_id}"
            ed.call("send_message", msg)
            Godot.print("[CrystalDebugAgent] Updated multiplayer role: #{role} (ID: #{peer_id})")
          end
        end
      rescue
      end

      # Triggers Godot's built-in debug pause loop
      def self.debug_break(can_continue : Bool = true, is_error : Bool = false) : Void
        if !Godot::EngineDebugger.singleton_ptr.null?
          ed = Godot::EngineDebugger.new(Godot::EngineDebugger.singleton_ptr)
          if ed.call_bool("is_active")
            ed.call("debug", can_continue, is_error)
          end
        end
      rescue
      end

      # Automatically determines if this game instance is Server, Client, or Standalone
      private def self.detect_role : String
        return @@cached_role if @@cached_role != "Peer"

        # Check command line arguments for common multiplayer flags
        begin
          ARGV.each do |arg|
            if arg.includes?("--server") || arg.includes?("-server") || arg.includes?("dedicated")
              return "Server"
            elsif arg.includes?("--client") || arg.includes?("-client")
              return "Client"
            end
          end
        rescue
        end

        "Game Instance"
      end
    end
  end
end
