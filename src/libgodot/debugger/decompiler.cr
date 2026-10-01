# =============================================================================
# LibGodot - Native radare2 Decompiler & Disassembly Engine
# =============================================================================
# Zero-dependency decompilation and disassembly for Crystal gameplay code,
# GDExtension thunks, and Godot engine binaries via native radare2 (pdc/pdf/pdca).

require "cradare2"
require "./r2_godot_plugin"

module Lapis
  module Debugger
    class Decompiler
      getter client : Cradare2::Client

      def initialize(@client : Cradare2::Client)
      end

      # Formats a 64-bit integer address or symbol string for radare2 seek
      private def target_str(target : UInt64 | Int32 | Int64 | String) : String
        case target
        when Int
          "0x#{target.to_s(16)}"
        else
          target.to_s
        end
      end

      # Decompiles function at address into clean pseudo-C (pdc)
      def decompile_at(address : UInt64) : String
        addr_hex = "0x#{address.to_s(16)}"
        # Analyze function at address if not already analyzed, then decompile
        @client.cmd("af @ #{addr_hex}") rescue nil
        res = @client.cmd("pdc @ #{addr_hex}").strip
        if res.empty? || res.includes?("Cannot find function")
          # Fallback to disassembly if function couldn't be structured
          @client.cmd("pdf @ #{addr_hex}").strip
        else
          res
        end
      end

      # Decompiles function with side-by-side assembly instruction comparison (pdca)
      def decompile_side_by_side(address : UInt64) : String
        addr_hex = "0x#{address.to_s(16)}"
        @client.cmd("af @ #{addr_hex}") rescue nil
        res = @client.cmd("pdca @ #{addr_hex}").strip
        res.empty? ? decompile_at(address) : res
      end

      # Returns source location struct for address using Cradare2 Lines helper
      def source_location_model(address : UInt64) : Cradare2::Lines::SourceLocation?
        @client.crystal.lines.at(address) rescue nil
      end

      # Returns source context lines around address if available
      def source_context_at(address : UInt64, window : Int32 = 4) : Array(NamedTuple(line: Int32, text: String, current: Bool))
        if loc = source_location_model(address)
          @client.crystal.lines.reader.read_context(loc.file, loc.line, window: window)
        else
          [] of NamedTuple(line: Int32, text: String, current: Bool)
        end
      rescue
        [] of NamedTuple(line: Int32, text: String, current: Bool)
      end

      # Returns source file and line mapping for address using radare2 debug symbols (cl)
      def source_location_at(address : UInt64) : String?
        if loc = source_location_model(address)
          return "#{loc.normalized_file}:#{loc.line}"
        end

        addr_hex = "0x#{address.to_s(16)}"
        res = @client.cmd("cl @ #{addr_hex}").strip rescue ""
        (!res.empty? && res != "??:0" && !res.includes?("Cannot")) ? res : nil
      end

      # Returns source-interleaved disassembly (pdls)
      def source_disassembly_at(address : UInt64, count : Int32 = 20) : String
        addr_hex = "0x#{address.to_s(16)}"
        @client.cmd("pdls #{count} @ #{addr_hex}").strip rescue ""
      end

      # Returns all discovered Crystal class/struct/module names from debug symbols
      def crystal_classes : Array(String)
        @client.crystal.classes rescue [] of String
      end

      # Decompiles by function name or symbol
      def decompile_function(name : String) : String
        @client.cmd("af @ #{name}") rescue nil
        res = @client.cmd("pdc @ #{name}").strip
        if res.empty? || res.includes?("Cannot find function")
          @client.cmd("pdf @ #{name}").strip
        else
          res
        end
      end

      # Looks up a method for a given Crystal class and decompiles it
      def decompile_method(class_name : String, method_name : String) : String
        methods = @client.crystal.methods_for_class(class_name)
        target_fn = methods.find do |fn|
          info = @client.crystal.parse_symbol(fn.name)
          info.method_name == method_name || fn.name.includes?(method_name)
        end

        if target_fn
          decompile_at(target_fn.offset)
        else
          # Fallback to searching symbols
          syms = @client.crystal.symbols_for_class(class_name)
          target_sym = syms.find do |s|
            info = @client.crystal.parse_symbol(s.name)
            info.method_name == method_name || s.name.includes?(method_name)
          end

          if target_sym
            decompile_at(target_sym.vaddr)
          else
            "// Function '#{class_name}##{method_name}' not found in analyzed binary symbols."
          end
        end
      end

      # Full function disassembly formatted with addresses and opcodes (pdf)
      def disassemble_function(target : UInt64 | Int32 | Int64 | String) : String
        t = target_str(target)
        @client.cmd("af @ #{t}") rescue nil
        @client.cmd("pdf @ #{t}").strip
      end

      # Disassembles a range of instructions starting at address
      def disassemble_range(address : UInt64, count : Int32 = 15) : Array(Cradare2::Model::Instruction)
        @client.disasm.at(address, count)
      end

      # DWARF line-annotated decompile if line metadata is present (CLd)
      def decompile_source_line(address : UInt64) : String
        addr_hex = "0x#{address.to_s(16)}"
        res = @client.cmd("CLd @ #{addr_hex}").strip
        res.empty? ? decompile_at(address) : res
      end

      # Lazily initialized R2GodotPlugin instance
      @godot_plugin : R2GodotPlugin? = nil

      def godot_plugin : R2GodotPlugin
        @godot_plugin ||= R2GodotPlugin.new(@client)
      end

      # Decodes a Godot Object header at virtual memory address
      def decompile_godot_object(address : UInt64) : GodotObjectHeader
        R2GodotPlugin.read_object_header(@client, address)
      end

      # Decodes a Godot Variant payload at virtual memory address
      def decode_variant_at(address : UInt64) : DecodedVariant
        VariantDecoder.decode_at(@client, address)
      end
    end
  end
end

module Godot
  {% unless Godot.has_constant?(:Debugger) %}
    alias Debugger = ::Lapis::Debugger
  {% end %}
end
