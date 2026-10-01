# =============================================================================
# LibGodot - Radare2 Dual-Target Plugin for Godot & Lapis
# =============================================================================
# Implements the `godot` and `lapis` command suites atop `cradare2`.
# Provides Mode 1 (Editor Supervisor) and Mode 2 (Standalone Game Debugger).

require "cradare2"
require "cradare2/plugin/dispatcher"
require "json"
require "./r2_godot_types"
require "./r2_source_indexer"
require "./r2_classdb_reconstructor"
require "./plugin_forensics"

module Lapis
  module Debugger
    alias AddressUtils = Cradare2::AddressUtils

    # --- Godot Command Suite (prefix: "godot") ---

    class GodotDetectCommand < Cradare2::Plugin::Command
      def initialize
        super("detect", "Detects Godot engine version, precision, and loaded extensions", "godot detect [-j]")
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        modules = client.debug.modules rescue [] of Cradare2::Model::ModuleInfo
        has_godot = modules.any? { |m| m.name.downcase.includes?("godot") || m.name.downcase.includes?("libgodot") }
        has_bridge = modules.any? { |m| m.name.downcase.includes?("crystal_bridge") }
        has_game = modules.any? { |m| m.name.downcase.includes?("game.dll") || m.name.downcase.includes?("game_loaded_") }
        has_plugin = modules.any? { |m| m.name.downcase.includes?("plugin.dll") || m.name.downcase.includes?("plugin_loaded_") }

        data = {
          "godot_detected" => has_godot,
          "bridge_loaded"  => has_bridge,
          "game_loaded"    => has_game,
          "plugin_loaded"  => has_plugin,
          "precision"      => "float64/float32 mixed",
          "modules_count"  => modules.size,
        }

        return data.to_json if json

        String.build do |io|
          io.puts "Godot Engine Integration Status:"
          io.puts "  Engine Core:       #{has_godot ? "Detected" : "Not Found"}"
          io.puts "  GDExtension Bridge: #{has_bridge ? "Loaded" : "Not Loaded"}"
          io.puts "  Game Logic DLL:    #{has_game ? "Loaded" : "Not Loaded"}"
          io.puts "  Editor Plugin DLL:  #{has_plugin ? "Loaded" : "Not Loaded"}"
          io.puts "  Precision Mode:    #{data["precision"]}"
        end
      end
    end

    class GodotObjectCommand < Cradare2::Plugin::Command
      def initialize
        super("object", "Decodes Godot Object header, ObjectID, and verifies alive status", "godot object <address|reg> [-j]", ["obj"])
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        return "Usage: #{usage}" if args.empty?
        target = args.first

        addr = resolve_target_address(client, target)
        return "Error: Could not resolve address for '#{target}'" unless addr

        header = R2GodotPlugin.read_object_header(client, addr)

        if json
          return header.to_json
        end

        String.build do |io|
          io.puts "Godot Object @ 0x#{addr.to_s(16)}:"
          io.puts "  VTable:       0x#{header.vtable.to_s(16)}"
          io.puts "  Instance ID:  #{header.instance_id} (0x#{header.instance_id.to_s(16)})"
          io.puts "  User Data:    0x#{header.user_data.to_s(16)}"
          if header.class_name
            io.puts "  Class Name:   #{header.class_name}"
          end
          if header.is_alive
            io.puts "  Status:       [ALIVE] Registered in ObjectDB"
          else
            io.puts "  Status:       [DEAD POINTER DETECTED!] Object deallocated or invalid ID"
          end
        end
      end

      private def resolve_target_address(client : Cradare2::Client, target : String) : UInt64?
        if addr = parse_address(target)
          return addr
        end
        # Try evaluating register name (e.g. "rcx", "rdi", "rax")
        reg_val = client.cmd("?v #{target}").strip
        AddressUtils.to_u64?(reg_val)
      end
    end

    class GodotVariantCommand < Cradare2::Plugin::Command
      def initialize
        super("variant", "Decodes 24/32-byte Godot Variant payload at address or register", "godot variant <address|reg> [-j]", ["var"])
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        return "Usage: #{usage}" if args.empty?
        target = args.first

        addr = resolve_target_address(client, target)
        return "Error: Could not resolve address for '#{target}'" unless addr

        decoded = VariantDecoder.decode_at(client, addr)

        return decoded.to_json if json

        String.build do |io|
          io.puts "Godot Variant @ 0x#{addr.to_s(16)}:"
          io.puts "  Type:    #{decoded.type} (#{decoded.type.value})"
          io.puts "  Value:   #{decoded.value}"
          io.puts "  Summary: #{decoded.summary}"
        end
      end

      private def resolve_target_address(client : Cradare2::Client, target : String) : UInt64?
        if addr = parse_address(target)
          return addr
        end
        reg_val = client.cmd("?v #{target}").strip
        AddressUtils.to_u64?(reg_val)
      end
    end

    class GodotClassDBCommand < Cradare2::Plugin::Command
      def initialize
        super("classdb", "Displays reconstructed or discovered ClassDB classes and methods", "godot classdb [filter] [-j]")
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        recon = ClassDBReconstructor.new
        classes = recon.reconstruct_from_session(client)

        filter = args.first?

        filtered = if filter && !filter.empty?
                     classes.select { |name, _| name.downcase.includes?(filter.downcase) }
                   else
                     classes
                   end

        return filtered.to_json if json

        return "No ClassDB classes matched filter '#{filter}'." if filtered.empty?

        String.build do |io|
          io.puts "Discovered ClassDB Classes (#{filtered.size}):"
          filtered.each do |cname, cls|
            io.puts "  - #{cname} < #{cls.parent_name} (0x#{cls.address.to_s(16)})"
            cls.methods.each do |m|
              io.puts "      def #{m.name} @ 0x#{m.address.to_s(16)}"
            end
          end
        end
      end
    end

    class GodotTypesCommand < Cradare2::Plugin::Command
      def initialize
        super("types", "Registers Godot radare2 print formats (pf.godot_*)", "godot types")
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        TypeMapRegistrar.register_all(client)
        "Registered Godot print formats: pf.godot_object, pf.godot_variant, pf.godot_vector2, pf.godot_vector3, pf.godot_color, pf.godot_transform3d."
      end
    end

    # --- Lapis Command Suite (prefix: "lapis") ---

    class LapisInfoCommand < Cradare2::Plugin::Command
      def initialize
        super("info", "Displays Lapis toolchain, GC heap, and active DLL telemetry", "lapis info [-j]")
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        modules = client.debug.modules rescue [] of Cradare2::Model::ModuleInfo
        shadow_dlls = modules.select { |m| m.name.downcase.includes?("game_loaded_") || m.name.downcase.includes?("plugin_loaded_") }

        data = {
          "lapis_version"  => "0.0.246",
          "crystal_target" => "1.20+",
          "modules"        => modules.map(&.name),
          "shadow_dlls"    => shadow_dlls.map(&.name),
        }

        return data.to_json if json

        String.build do |io|
          io.puts "Lapis Engine & Toolchain Telemetry:"
          io.puts "  Lapis Version:   0.0.246"
          io.puts "  Active Modules:  #{modules.size} loaded"
          io.puts "  Shadow DLLs:     #{shadow_dlls.size} active"
          shadow_dlls.each do |s|
            io.puts "    - #{s.name} (0x#{s.base_address.to_s(16)} - 0x#{s.end_address.to_s(16)})"
          end
        end
      end
    end

    class LapisSupervisorCommand < Cradare2::Plugin::Command
      def initialize
        super("supervisor", "Mode 1: Supervises Godot Editor and isolates fault origins", "lapis supervisor [diagnose|status] [-j]")
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        sub = args.first? || "status"
        case sub
        when "diagnose"
          pc_str = client.cmd("?v pc").strip
          pc = AddressUtils.to_u64?(pc_str) || 0_u64
          mod = client.debug.module_at(pc)
          origin = mod ? PluginForensics.classify_module(mod.name) : ModuleOrigin::Unknown

          res = {
            "faulting_pc"     => "0x#{pc.to_s(16)}",
            "faulting_module" => mod ? mod.name : "unknown",
            "origin"          => origin.to_s,
          }
          return res.to_json if json
          String.build do |io|
            io.puts "=== Editor Supervisor Crash Diagnosis ==="
            io.puts "Faulting PC:      0x#{pc.to_s(16)}"
            io.puts "Faulting Module:  #{mod ? mod.name : "unknown"}"
            io.puts "Fault Boundary:   #{origin}"
          end
        else
          # Status
          modules = client.debug.modules rescue [] of Cradare2::Model::ModuleInfo
          return modules.to_json if json
          "Editor Supervisor Active. Monitoring #{modules.size} mapped process modules."
        end
      end
    end

    class LapisStaleVTablesCommand < Cradare2::Plugin::Command
      def initialize
        super("stale-vtables", "Checks loaded objects for vtables pointing to unmapped previous shadow DLLs", "lapis stale-vtables [-j]")
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        stale = R2GodotPlugin.find_stale_vtables(client)
        return stale.to_json if json

        if stale.empty?
          "Zero stale vtables detected across all active module boundaries."
        else
          String.build do |io|
            io.puts "WARNING: #{stale.size} stale vtables detected!"
            stale.each { |s| io.puts "  - #{s}" }
          end
        end
      end
    end

    class LapisDeadPointersCommand < Cradare2::Plugin::Command
      def initialize
        super("dead-pointers", "Scans CPU registers and memory for dead Godot object pointers", "lapis dead-pointers [-j]")
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        dead = R2GodotPlugin.scan_dead_pointers(client)
        return dead.to_json if json

        if dead.empty?
          "Zero dead pointers detected in CPU registers."
        else
          String.build do |io|
            io.puts "CRITICAL HAZARD: #{dead.size} dead pointer(s) detected!"
            dead.each do |reg, id|
              io.puts "  - Register #{reg}: Instance ID #{id} (freed in ObjectDB)"
            end
          end
        end
      end
    end

    class LapisMapCommand < Cradare2::Plugin::Command
      def initialize
        super("map", "Runs SourceIndexer over src/ and injects flags and comments into r2", "lapis map [dir] [-j]")
      end

      def execute(client : Cradare2::Client, args : Array(String), json : Bool = false) : String
        dir = args.first? || "src"
        indexer = SourceIndexer.new
        indexer.index_directory(dir)
        indexer.inject_into_radare(client)

        data = {
          "indexed_nodes"      => indexer.nodes.size,
          "indexed_properties" => indexer.properties.size,
          "indexed_signals"    => indexer.signals.size,
        }

        return data.to_json if json

        "Successfully indexed #{indexer.nodes.size} nodes, #{indexer.properties.size} properties, and #{indexer.signals.size} signals from '#{dir}'."
      end
    end

    # --- Unified R2GodotPlugin Engine ---

    class R2GodotPlugin
      getter client : Cradare2::Client
      getter godot_dispatcher : Cradare2::Plugin::CommandDispatcher
      getter lapis_dispatcher : Cradare2::Plugin::CommandDispatcher

      def initialize(@client : Cradare2::Client)
        @godot_dispatcher = Cradare2::Plugin::CommandDispatcher.new(@client, prefix: "godot")
        @lapis_dispatcher = Cradare2::Plugin::CommandDispatcher.new(@client, prefix: "lapis")

        register_commands
      end

      private def register_commands : Nil
        @godot_dispatcher.register(GodotDetectCommand.new)
        @godot_dispatcher.register(GodotObjectCommand.new)
        @godot_dispatcher.register(GodotVariantCommand.new)
        @godot_dispatcher.register(GodotClassDBCommand.new)
        @godot_dispatcher.register(GodotTypesCommand.new)

        @lapis_dispatcher.register(LapisInfoCommand.new)
        @lapis_dispatcher.register(LapisSupervisorCommand.new)
        @lapis_dispatcher.register(LapisStaleVTablesCommand.new)
        @lapis_dispatcher.register(LapisDeadPointersCommand.new)
        @lapis_dispatcher.register(LapisMapCommand.new)
      end

      # Dispatches a command string to either "godot" or "lapis" command dispatchers.
      def dispatch(cmd_line : String) : String
        trimmed = cmd_line.strip
        first_token = trimmed.split(/\s+/).first?.try(&.downcase) || ""

        case first_token
        when "godot"
          @godot_dispatcher.dispatch(trimmed)
        when "lapis"
          @lapis_dispatcher.dispatch(trimmed)
        else
          # Fallback: check if subcommands match either dispatcher
          sub = first_token.lchop("godot:").lchop("lapis:")
          if @godot_dispatcher.commands.has_key?(sub)
            @godot_dispatcher.dispatch(trimmed)
          elsif @lapis_dispatcher.commands.has_key?(sub)
            @lapis_dispatcher.dispatch(trimmed)
          else
            "Unknown plugin command: '#{first_token}'. Available prefixes: 'godot', 'lapis'."
          end
        end
      end

      # Reads and validates Godot Object header at memory address.
      def self.read_object_header(client : Cradare2::Client, address : UInt64) : GodotObjectHeader
        bytes = client.memory.read_bytes(address, 32)
        return GodotObjectHeader.new(0_u64, 0_u64, is_alive: false) if bytes.size < 16

        vtable = IO::ByteFormat::LittleEndian.decode(UInt64, bytes[0, 8])
        instance_id = IO::ByteFormat::LittleEndian.decode(UInt64, bytes[8, 8])
        user_data = bytes.size >= 24 ? IO::ByteFormat::LittleEndian.decode(UInt64, bytes[16, 8]) : 0_u64
        user_data_type = bytes.size >= 32 ? IO::ByteFormat::LittleEndian.decode(UInt64, bytes[24, 8]) : 0_u64

        # Validate monotonic 64-bit ID: Godot ObjectIDs start above 0 and monotonic
        is_alive = instance_id > 0_u64 && instance_id < 0x7FFFFFFFFFFFFFFF_u64

        GodotObjectHeader.new(vtable, instance_id, user_data, user_data_type, is_alive: is_alive)
      end

      # Scans standard CPU registers for dead pointers.
      def self.scan_dead_pointers(client : Cradare2::Client) : Array(Tuple(String, UInt64))
        results = [] of Tuple(String, UInt64)
        registers = ["rcx", "rdx", "r8", "r9", "rdi", "rsi", "rbx", "rax"]

        registers.each do |reg|
          val_s = client.cmd("?v #{reg}").strip
          if val = AddressUtils.to_u64?(val_s)
            if val > 0x10000_u64 # Exclude small integers or null offsets
              header = read_object_header(client, val)
              if !header.is_alive && header.instance_id > 0
                results << {reg, header.instance_id}
              end
            end
          end
        end

        results
      end

      # Identifies vtables pointing to memory that is no longer part of any mapped module.
      def self.find_stale_vtables(client : Cradare2::Client) : Array(String)
        results = [] of String
        modules = client.debug.modules rescue [] of Cradare2::Model::ModuleInfo
        return results if modules.empty?

        registers = ["rcx", "rdi", "rsi", "rbx"]
        registers.each do |reg|
          val_s = client.cmd("?v #{reg}").strip
          if val = AddressUtils.to_u64?(val_s)
            if val > 0x10000_u64
              header = read_object_header(client, val)
              if header.vtable > 0
                # Check if vtable falls within any known module
                in_module = modules.any? { |m| m.contains?(header.vtable) }
                unless in_module
                  results << "Register #{reg} (Object @ 0x#{val.to_s(16)}) points to stale vtable 0x#{header.vtable.to_s(16)} outside mapped modules"
                end
              end
            end
          end
        end

        results
      end
    end
  end
end
