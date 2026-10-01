# =============================================================================
# LibGodot - GDExtension Binary Inspector
# =============================================================================
# Uses cradare2 to validate GDExtension binary health: entry points,
# export tables, architecture compatibility, and Godot binding imports.

require "cradare2"

module Lapis
  module Debugger
    struct GDExtensionCheck
      getter valid : Bool
      getter entrypoint_found : Bool
      getter entrypoint_name : String?
      getter exports_count : Int32
      getter arch : String
      getter bits : Int32
      getter warnings : Array(String)

      def initialize(
        @valid : Bool,
        @entrypoint_found : Bool,
        @entrypoint_name : String?,
        @exports_count : Int32,
        @arch : String,
        @bits : Int32,
        @warnings : Array(String) = [] of String,
      )
      end
    end

    class GDExtensionInspector
      COMMON_ENTRYPOINTS = [
        "crystal_library_init",
        "crystal_godot_init",
        "crystal_bridge_init",
        "lapis_gdextension_entry",
        "godot_gdextension_entry",
        "gdextension_initialize",
        "gdextension_entry",
      ]

      getter r2 : Cradare2::Client

      def initialize(@r2 : Cradare2::Client)
      end

      # Validates a GDExtension binary on disk
      def self.inspect_file(file_path : String) : GDExtensionCheck
        Cradare2.open(file_path) do |client|
          inspector = new(client)
          inspector.verify_gdextension
        end
      end

      def verify_gdextension : GDExtensionCheck
        exports = @r2.exports
        info = @r2.info
        warnings = [] of String

        entry_name : String? = nil
        found_entry = false

        exports.each do |exp|
          clean_name = exp.name.lstrip('_')
          if COMMON_ENTRYPOINTS.any? { |ep| clean_name.includes?(ep) }
            found_entry = true
            entry_name = exp.name
            break
          end
        end

        if !found_entry
          warnings << "No standard GDExtension entrypoint found (expected one of: #{COMMON_ENTRYPOINTS.join(", ")})"
        end

        if exports.empty?
          warnings << "Binary exports table is empty; Godot will not be able to locate entrypoints"
        end

        valid = found_entry && warnings.empty?

        bin = info.bin
        arch_str = (bin ? bin.arch : info.arch) || "unknown"
        bits_val = (bin ? bin.bits : info.bits) || 64

        GDExtensionCheck.new(
          valid: valid,
          entrypoint_found: found_entry,
          entrypoint_name: entry_name,
          exports_count: exports.size,
          arch: arch_str,
          bits: bits_val,
          warnings: warnings
        )
      end

      def find_godot_bindings : Array(Cradare2::Model::Import)
        @r2.imports_matching(/godot|gdextension/i)
      end

      def inspect_lapis_crash : String
        @r2.debug.crash_report
      end
    end
  end
end
