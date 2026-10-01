# =============================================================================
# LibGodot - GDExtension Boundary Crash Forensics & Dead-Pointer Engine
# =============================================================================
# Multi-layer crash forensics classifying faulting instruction pointers across
# Godot Core, C++ Bridge, Plugin DLL, Game DLL, and Boehm GC boundaries.

require "cradare2"
require "./decompiler"

module Lapis
  module Debugger
    enum ModuleOrigin
      GameCode
      LapisPlugin
      GDExtensionBridge
      GodotCore
      BoehmGC
      SystemCRT
      Unknown
    end

    class CrashReport
      property origin : ModuleOrigin
      property faulting_pc : UInt64
      property faulting_module : String
      property is_dead_pointer : Bool
      property dead_pointer_instance_id : UInt64?
      property dead_pointer_class_name : String?
      property decompiled_crash_site : String
      property demangled_backtrace : Array(String)
      property raw_report : String

      def initialize(
        @origin : ModuleOrigin,
        @faulting_pc : UInt64,
        @faulting_module : String,
        @is_dead_pointer : Bool = false,
        @dead_pointer_instance_id : UInt64? = nil,
        @dead_pointer_class_name : String? = nil,
        @decompiled_crash_site : String = "",
        @demangled_backtrace : Array(String) = [] of String,
        @raw_report : String = "",
      )
      end

      def summary : String
        String.build do |io|
          io.puts "================================================================="
          io.puts "           LAPIS CRASH FORENSICS & FAULT ANALYSIS               "
          io.puts "================================================================="
          io.puts "Faulting PC:      0x#{@faulting_pc.to_s(16)}"
          io.puts "Origin Module:    #{@faulting_module} [#{@origin}]"

          if @is_dead_pointer
            io.puts "CRITICAL HAZARD:  DEAD POINTER DEREFERENCE DETECTED!"
            if id = @dead_pointer_instance_id
              io.puts "Instance ID:      #{id} (0x#{id.to_s(16)})"
            end
            if cn = @dead_pointer_class_name
              io.puts "Target Class:     #{cn}"
            end
            io.puts "Remedy:           The Godot Node was freed (queue_free/free), but accessed by Crystal without #check_alive!"
          elsif @faulting_pc < 0x10000
            io.puts "CRITICAL HAZARD:  NULL POINTER DEREFERENCE!"
            io.puts "Remedy:           Accessing offset on a nil/null object reference."
          end

          io.puts "\nDemangled Call Stack:"
          if @demangled_backtrace.empty?
            io.puts "  (No call stack frames captured)"
          else
            @demangled_backtrace.each_with_index do |frame, idx|
              io.puts "  ##{idx} #{frame}"
            end
          end

          unless @decompiled_crash_site.empty?
            io.puts "\nDecompiled Crash Site (pdc):"
            io.puts "-----------------------------------------------------------------"
            io.puts @decompiled_crash_site
            io.puts "-----------------------------------------------------------------"
          end
        end
      end
    end

    class PluginForensics
      # Classifies a memory address into its host module origin based on loaded memory maps
      def self.classify_module(name : String) : ModuleOrigin
        lower = name.downcase
        if lower.includes?("game.dll") || lower.includes?("game_loaded_") || lower.includes?("game.exe")
          ModuleOrigin::GameCode
        elsif lower.includes?("plugin.dll") || lower.includes?("plugin_loaded_")
          ModuleOrigin::LapisPlugin
        elsif lower.includes?("crystal_bridge")
          ModuleOrigin::GDExtensionBridge
        elsif lower.includes?("godot") || lower.includes?("libgodot")
          ModuleOrigin::GodotCore
        elsif lower.includes?("gc.dll") || lower.includes?("libgc")
          ModuleOrigin::BoehmGC
        elsif lower.includes?("ucrtbase") || lower.includes?("msvcrt") || lower.includes?("ntdll") || lower.includes?("kernel32")
          ModuleOrigin::SystemCRT
        else
          ModuleOrigin::Unknown
        end
      end

      # Performs automated forensics analysis on the current stopped state in radare2
      def self.diagnose_crash(client : Cradare2::Client) : CrashReport
        regs = client.debug.registers
        pc = regs.pc
        maps = client.debug.maps

        # Locate faulting memory region
        matching_map = maps.find { |m| m.contains?(pc) }
        mod_name = matching_map ? File.basename(matching_map.name) : "unknown_unmapped"
        origin = matching_map ? classify_module(matching_map.name) : ModuleOrigin::Unknown

        # Check for dead pointer patterns in 'this' pointer (RCX on Windows, RDI on SysV)
        this_ptr = regs.rcx > 0 ? regs.rcx : regs.rdi
        is_dead_pointer = false
        dead_instance_id : UInt64? = nil
        dead_class : String? = nil

        # If this pointer looks like a valid address, attempt reading @instance_id (typically offset 8 or 16)
        if this_ptr > 0x10000 && this_ptr != 0xffffffffffffffff_u64
          begin
            candidate_id = client.memory.read_u64(this_ptr + 8) rescue 0_u64
            if candidate_id == 0
              candidate_id = client.memory.read_u64(this_ptr + 16) rescue 0_u64
            end

            # A monotonic Godot ObjectDB instance ID is non-zero
            if candidate_id > 100 && candidate_id < 0x7fffffffffff_u64
              dead_instance_id = candidate_id
              is_dead_pointer = true
            end
          rescue
          end
        end

        # Decompile crash site
        decompiler = Decompiler.new(client)
        crash_decomp = decompiler.decompile_at(pc) rescue ""

        # Extract demangled call stack
        bt_frames = client.debug.backtrace_symbols

        # Raw r2 crash report
        raw = client.debug.crash_report(regs: regs) rescue ""

        CrashReport.new(
          origin: origin,
          faulting_pc: pc,
          faulting_module: mod_name,
          is_dead_pointer: is_dead_pointer,
          dead_pointer_instance_id: dead_instance_id,
          dead_pointer_class_name: dead_class,
          decompiled_crash_site: crash_decomp,
          demangled_backtrace: bt_frames,
          raw_report: raw
        )
      end

      # Performs lightweight static or runtime fault inspection for a given address and reason
      def self.inspect_fault(fault_address : UInt64, reason : String = "") : CrashReport
        is_dead = (fault_address == 0_u64)
        CrashReport.new(
          origin: ModuleOrigin::GameCode,
          faulting_pc: fault_address,
          faulting_module: "game.dll",
          is_dead_pointer: is_dead,
          dead_pointer_instance_id: nil,
          dead_pointer_class_name: nil,
          decompiled_crash_site: "",
          demangled_backtrace: [] of String,
          raw_report: reason
        )
      end
    end
  end
end
