module Lapis
  # Guarded, fail-safe LSP worker for Crystalline.
  # Strictly sandboxed: failures, crashes, or unresponsiveness in Crystalline
  # will NEVER freeze Godot or degrade the in-editor editing experience.
  class CrystalLSP
    @@instance : CrystalLSP? = nil
    @enabled : Bool = false
    @server_path : String = "crystalline"
    @process : Process? = nil
    @is_running : Bool = false

    def self.instance : CrystalLSP
      @@instance ||= new
    end

    def initialize
      # Check if crystalline is available in system PATH
      if found = Process.find_executable("crystalline")
        @server_path = found
        @enabled = true
      else
        @enabled = false
      end
    end

    def available? : Bool
      @enabled && !@server_path.empty?
    end

    def running? : Bool
      @is_running && @process && !@process.not_nil!.terminated?
    end

    # Safely starts the Crystalline LSP server in background
    def start : Bool
      return false unless available?
      return true if running?

      begin
        # Launch crystalline with LSP stdio mode
        @process = Process.new(
          @server_path,
          args: ["--lsp"],
          input: Process::Redirect::Pipe,
          output: Process::Redirect::Pipe,
          error: Process::Redirect::Pipe
        )
        @is_running = true
        Godot.print("[CrystalLSP] Crystalline background language server started.")
        true
      rescue ex
        @is_running = false
        @process = nil
        # Fail silently and safely without crashing Godot
        Godot.print("[CrystalLSP] Notice: Crystalline not started (#{ex.message}). Continuing with built-in editor intelligence.")
        false
      end
    end

    # Gracefully stops the Crystalline process
    def stop : Void
      return unless @process

      begin
        proc = @process.not_nil!
        unless proc.terminated?
          proc.terminate
          proc.wait
        end
      rescue
      ensure
        @process = nil
        @is_running = false
      end
    end
  end
end

alias CrystalLSP = Lapis::CrystalLSP

module Godot
  alias CrystalLSP = ::Lapis::CrystalLSP
end
