# =============================================================================
# LibGodot - radare2 Binary Analyzer & Hardening Engine
# =============================================================================
# Programmatic static and dynamic binary analysis via cradare2.
# Audits GC safety, GDExtension symbols, section budgets, function bloat,
# string footprint, import minimization, and security hardening.

require "json"
require "cradare2"

module Lapis
  module Debugger
    class BinaryAnalyzer
      # =======================================================================
      # Report Data Models
      # =======================================================================

      struct GCSafetyReport
        include ::JSON::Serializable

        getter thread_registration_verified : Bool
        getter thread_registration_count : Int32
        getter gc_imports : Array(String)
        getter gc_functions : Array(String)
        getter has_gc_malloc : Bool
        getter static_data_size : UInt64
        getter warnings : Array(String)

        def initialize(
          @thread_registration_verified : Bool,
          @thread_registration_count : Int32,
          @gc_imports : Array(String),
          @gc_functions : Array(String),
          @has_gc_malloc : Bool,
          @static_data_size : UInt64,
          @warnings : Array(String) = [] of String
        )
        end
      end

      struct SymbolAuditReport
        include ::JSON::Serializable

        getter entrypoint_found : Bool
        getter entrypoint_name : String?
        getter entrypoint_has_c_linkage : Bool
        getter exported_classes : Array(String)
        getter total_functions : Int32
        getter total_symbols : Int32
        getter warnings : Array(String)

        def initialize(
          @entrypoint_found : Bool,
          @entrypoint_name : String?,
          @entrypoint_has_c_linkage : Bool,
          @exported_classes : Array(String),
          @total_functions : Int32,
          @total_symbols : Int32,
          @warnings : Array(String) = [] of String
        )
        end
      end

      struct SectionBudget
        include ::JSON::Serializable

        getter name : String
        getter size : UInt64
        getter budget : UInt64
        getter percentage : Float64
        getter within_budget : Bool

        def initialize(@name : String, @size : UInt64, @budget : UInt64)
          @percentage = @budget > 0 ? ((@size.to_f / @budget.to_f) * 100.0).round(1) : 0.0
          @within_budget = @size <= @budget
        end
      end

      struct FunctionSizeOutlier
        include ::JSON::Serializable

        getter name : String
        getter size : UInt64
        getter offset : UInt64

        def initialize(@name : String, @size : UInt64, @offset : UInt64)
        end
      end

      struct EfficiencyReport
        include ::JSON::Serializable

        getter sections : Array(SectionBudget)
        getter largest_functions : Array(FunctionSizeOutlier)
        getter total_code_size : UInt64
        getter total_binary_size : UInt64
        getter leaked_paths : Array(String)
        getter imported_libraries : Array(String)
        getter warnings : Array(String)

        def initialize(
          @sections : Array(SectionBudget),
          @largest_functions : Array(FunctionSizeOutlier),
          @total_code_size : UInt64,
          @total_binary_size : UInt64,
          @leaked_paths : Array(String),
          @imported_libraries : Array(String),
          @warnings : Array(String) = [] of String
        )
        end
      end

      struct HardeningReport
        include ::JSON::Serializable

        getter dep_enabled : Bool
        getter aslr_enabled : Bool
        getter has_relocations : Bool
        getter warnings : Array(String)

        def initialize(
          @dep_enabled : Bool,
          @aslr_enabled : Bool,
          @has_relocations : Bool,
          @warnings : Array(String) = [] of String
        )
        end
      end

      struct FullReport
        include ::JSON::Serializable

        getter target_path : String
        getter arch : String
        getter bits : Int32
        getter gc : GCSafetyReport
        getter symbols : SymbolAuditReport
        getter efficiency : EfficiencyReport
        getter hardening : HardeningReport
        getter passed : Bool

        def initialize(
          @target_path : String,
          @arch : String,
          @bits : Int32,
          @gc : GCSafetyReport,
          @symbols : SymbolAuditReport,
          @efficiency : EfficiencyReport,
          @hardening : HardeningReport
        )
          @passed = @gc.warnings.empty? &&
                    @symbols.warnings.empty? &&
                    @efficiency.warnings.empty? &&
                    @hardening.warnings.empty?
        end

        def format_terminal : String
          String.build do |io|
            io.puts "â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—"
            io.puts "â•‘                    ðŸ”® LAPIS BINARY ANALYSIS REPORT                           â•‘"
            io.puts "â•‘ Target: %-60s â•‘" % File.basename(@target_path)
            io.puts "â•‘ Architecture: %-4s (%d-bit)                                             â•‘" % [@arch, @bits]
            io.puts "â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
            io.puts

            # [1] GDExtension & Symbols
            io.puts "[1] GDExtension & Symbol Health:"
            if @symbols.entrypoint_found
              io.puts "  âœ“ Entrypoint: #{@symbols.entrypoint_name} (C-linkage: #{@symbols.entrypoint_has_c_linkage ? "yes" : "NO"})"
            else
              io.puts "  âœ— Entrypoint: None found!"
            end
            io.puts "  âœ“ Classes Discovered: #{@symbols.exported_classes.size}"
            @symbols.exported_classes.first(6).each do |cls|
              io.puts "    â€¢ #{cls}"
            end
            if @symbols.exported_classes.size > 6
              io.puts "    ... and #{@symbols.exported_classes.size - 6} more"
            end
            io.puts "  âœ“ Total Functions: #{@symbols.total_functions}, Total Symbols: #{@symbols.total_symbols}"
            @symbols.warnings.each { |w| io.puts "  âš  [Symbol Warning] #{w}" }
            io.puts

            # [2] GC & Memory Architecture
            io.puts "[2] Memory & GC Architecture:"
            io.puts "  âœ“ Boehm GC Symbols: #{@gc.has_gc_malloc ? "Verified (GC_malloc present)" : "None"}"
            io.puts "  âœ“ Thread Registration: #{@gc.thread_registration_verified ? "Verified (#{@gc.thread_registration_count} xrefs/symbols)" : "Not detected"}"
            io.puts "  âœ“ Static Data Size (.data/.bss): %d KB" % (@gc.static_data_size // 1024)
            @gc.warnings.each { |w| io.puts "  âš  [GC Warning] #{w}" }
            io.puts

            # [3] Space Efficiency & Section Budgets
            io.puts "[3] Space Efficiency & Section Budgets:"
            @efficiency.sections.each do |sec|
              status = sec.within_budget ? "âœ“" : "âœ—"
              io.puts "  #{status} %-8s: %6.2f MB / %6.2f MB budget (%5.1f%%)" % [
                sec.name,
                sec.size.to_f / (1024.0 * 1024.0),
                sec.budget.to_f / (1024.0 * 1024.0),
                sec.percentage,
              ]
            end
            if !@efficiency.largest_functions.empty?
              io.puts "  Top Function Outliers:"
              @efficiency.largest_functions.first(3).each do |fn|
                short_name = fn.name.size > 40 ? "#{fn.name[0, 37]}..." : fn.name
                io.puts "    • %-40s (%5.1f KB)" % [short_name, fn.size.to_f / 1024.0]
              end
            end
            @efficiency.warnings.each { |w| io.puts "  âš  [Efficiency Warning] #{w}" }
            io.puts

            # [4] Security & Hardening
            io.puts "[4] Security & Platform Hardening:"
            io.puts "  #{(@hardening.dep_enabled ? "âœ“" : "âš ")} DEP / W^X Memory: #{@hardening.dep_enabled ? "Enabled (safe)" : "Warning: Writable+Executable section detected"}"
            io.puts "  #{(@hardening.aslr_enabled ? "âœ“" : "âš ")} ASLR / Dynamic Base: #{@hardening.aslr_enabled ? "Enabled" : "Disabled"}"
            io.puts "  #{(@hardening.has_relocations ? "âœ“" : "âš ")} Relocation Table (.reloc): #{@hardening.has_relocations ? "Present" : "Missing"}"
            @hardening.warnings.each { |w| io.puts "  âš  [Hardening Warning] #{w}" }
            io.puts

            if @passed
              io.puts ">>> RESULT: PASS (All binary health & efficiency invariants verified) <<<"
            else
              io.puts ">>> RESULT: WARNINGS DETECTED (Review above logs) <<<"
            end
          end
        end
      end

      # =======================================================================
      # Analyzer Implementation
      # =======================================================================

      COMMON_ENTRYPOINTS = [
        "crystal_godot_init",
        "crystal_library_init",
        "crystal_bridge_init",
        "lapis_gdextension_entry",
        "godot_gdextension_entry",
        "gdextension_initialize",
        "gdextension_entry",
      ]

      DEFAULT_BUDGETS = {
        ".text"  => 14_680_064_u64, # 14 MB code budget
        ".rdata" => 4_194_304_u64,  # 4 MB read-only data budget
        ".data"  => 2_097_152_u64,  # 2 MB global data budget
        ".bss"   => 2_097_152_u64,  # 2 MB uninitialized data budget
      }

      getter client : Cradare2::Client
      getter file_path : String

      def initialize(@client : Cradare2::Client, @file_path : String)
      end

      # Main entry point to inspect a file
      def self.analyze_file(
        file_path : String,
        budgets : Hash(String, UInt64) = DEFAULT_BUDGETS,
        quick : Bool = false
      ) : FullReport
        Cradare2.open(file_path) do |client|
          # Run basic analysis (entrypoint, symbols, imports) unless quick
          client.analyze.basic unless quick
          analyzer = new(client, file_path)
          analyzer.run(budgets)
        end
      end

      def run(budgets : Hash(String, UInt64) = DEFAULT_BUDGETS) : FullReport
        info = @client.info
        bin = info.bin
        arch_str = (bin ? bin.arch : info.arch) || "x86"
        bits_val = (bin ? bin.bits : info.bits) || 64

        gc_report = audit_gc_safety
        symbol_report = audit_symbols
        efficiency_report = audit_efficiency(budgets)
        hardening_report = audit_hardening

        FullReport.new(
          target_path: @file_path,
          arch: arch_str,
          bits: bits_val,
          gc: gc_report,
          symbols: symbol_report,
          efficiency: efficiency_report,
          hardening: hardening_report
        )
      end

      # Audits Boehm GC symbols, imports, and thread registration
      def audit_gc_safety : GCSafetyReport
        symbols = @client.symbols
        imports = @client.imports
        functions = @client.functions
        warnings = [] of String

        gc_syms = symbols.select { |s| s.name.includes?("GC_") }
        gc_imps = imports.select { |i| i.name.includes?("GC_") }
        gc_funcs = functions.select { |f| f.name.includes?("GC_") }

        has_malloc = gc_syms.any? { |s| s.name.includes?("GC_malloc") } ||
                     gc_imps.any? { |i| i.name.includes?("GC_malloc") } ||
                     gc_funcs.any? { |f| f.name.includes?("GC_malloc") }

        # Check for thread registration
        thread_reg_syms = symbols.select { |s| s.name.includes?("GC_register_my_thread") }
        thread_reg_imps = imports.select { |i| i.name.includes?("GC_register_my_thread") }
        thread_reg_count = thread_reg_syms.size + thread_reg_imps.size

        # Find static data sections size (.data + .bss)
        sections = @client.sections
        static_size = 0_u64
        sections.each do |sec|
          if sec.name == ".data" || sec.name == ".bss"
            static_size += (sec.vsize || sec.size)
          end
        end

        GCSafetyReport.new(
          thread_registration_verified: thread_reg_count > 0,
          thread_registration_count: thread_reg_count,
          gc_imports: gc_imps.map(&.name),
          gc_functions: gc_funcs.map(&.name),
          has_gc_malloc: has_malloc,
          static_data_size: static_size,
          warnings: warnings
        )
      end

      # Audits GDExtension entry points, exported classes, and C-linkage
      def audit_symbols : SymbolAuditReport
        exports = @client.exports
        symbols = @client.symbols
        functions = @client.functions
        warnings = [] of String

        entry_name : String? = nil
        found_entry = false
        c_linkage = false

        # Check exports for standard GDExtension entrypoints
        exports.each do |exp|
          clean_name = exp.name.lstrip('_')
          if COMMON_ENTRYPOINTS.any? { |ep| clean_name.includes?(ep) }
            found_entry = true
            entry_name = exp.name
            c_linkage = !exp.name.starts_with?("_Z") # Standard Itanium/GCC C++ mangling check
            break
          end
        end

        # Fallback check on symbols if not a dynamic export table (e.g. static host executable)
        if !found_entry
          symbols.each do |sym|
            clean = sym.name.lstrip('_')
            if COMMON_ENTRYPOINTS.any? { |ep| clean.includes?(ep) }
              found_entry = true
              entry_name = sym.name
              c_linkage = !sym.name.starts_with?("_Z")
              break
            end
          end
        end

        if !found_entry && @file_path.ends_with?(".dll")
          warnings << "No standard GDExtension entrypoint found in export table (expected one of: #{COMMON_ENTRYPOINTS.join(", ")})"
        end

        if found_entry && !c_linkage
          warnings << "Entrypoint '#{entry_name}' has C++ mangling instead of 'extern \"C\"' linkage"
        end

        # Discovered classes via Cradare2 Crystal helper
        discovered_classes = @client.crystal.classes

        SymbolAuditReport.new(
          entrypoint_found: found_entry,
          entrypoint_name: entry_name,
          entrypoint_has_c_linkage: c_linkage,
          exported_classes: discovered_classes,
          total_functions: functions.size,
          total_symbols: symbols.size,
          warnings: warnings
        )
      end

      # Audits section sizes, function outliers, and string table footprint
      def audit_efficiency(budgets : Hash(String, UInt64) = DEFAULT_BUDGETS) : EfficiencyReport
        sections = @client.sections
        functions = @client.functions
        warnings = [] of String

        section_budgets = Array(SectionBudget).new
        total_code_size = 0_u64
        total_binary_size = (File.size(@file_path) rescue 0_i64).to_u64

        sections.each do |sec|
          sec_size = sec.vsize || sec.size
          if sec.executable?
            total_code_size += sec_size
          end

          budget = budgets[sec.name]? || (sec_size * 2_u64)
          sb = SectionBudget.new(sec.name, sec_size, budget)
          section_budgets << sb

          if !sb.within_budget
            warnings << "Section '#{sec.name}' size (%.2f MB) exceeds budget (%.2f MB)" % [
              sec_size.to_f / (1024.0 * 1024.0),
              budget.to_f / (1024.0 * 1024.0),
            ]
          end
        end

        # Find top largest functions
        sorted_fns = functions.sort_by { |f| -(f.size.to_i64) }
        outliers = Array(FunctionSizeOutlier).new
        sorted_fns.first(10).each do |f|
          outliers << FunctionSizeOutlier.new(f.name, f.size, f.offset)
          # Outlier warning threshold: 64 KB
          if f.size > 65536_u64
            warnings << "Function outlier: '#{f.name}' exceeds 64 KB (%d bytes)" % f.size
          end
        end

        # Check for leaked paths in data strings
        leaked_paths = Array(String).new
        begin
          strings_json = @client.cmdj("izj")
          if arr = strings_json.as_a?
            arr.each do |item|
              str = item["string"]?.try(&.as_s) || ""
              if str.includes?("/scratch/spec_") || str.includes?("\\scratch\\spec_")
                leaked_paths << str
              end
            end
          end
        rescue
        end

        if !leaked_paths.empty?
          warnings << "Found #{leaked_paths.size} temporary or developer scratch path(s) embedded in binary strings"
        end

        # Imported libraries (ilj)
        imported_libs = Array(String).new
        begin
          libs_json = @client.cmdj("ilj")
          if arr = libs_json.as_a?
            arr.each do |item|
              if name = item.as_s?
                imported_libs << name
              end
            end
          end
        rescue
        end

        EfficiencyReport.new(
          sections: section_budgets,
          largest_functions: outliers,
          total_code_size: total_code_size,
          total_binary_size: total_binary_size,
          leaked_paths: leaked_paths,
          imported_libraries: imported_libs,
          warnings: warnings
        )
      end

      # Audits DEP, ASLR, and relocation tables
      def audit_hardening : HardeningReport
        sections = @client.sections
        warnings = [] of String

        # DEP: No section should be both writable AND executable (W+X)
        has_wx = sections.any? do |sec|
          sec.writable? && sec.executable?
        end
        dep_ok = !has_wx
        if has_wx
          warnings << "Binary contains writable and executable (W+X) memory section; violates DEP/W^X security"
        end

        # ASLR & Relocations
        has_reloc = sections.any? { |sec| sec.name == ".reloc" }
        aslr_ok = has_reloc # In PE, dynamic base requires .reloc table
        if !has_reloc && @file_path.ends_with?(".dll")
          warnings << "Shared library is missing '.reloc' relocation table; ASLR dynamic rebasing may fail"
        end

        HardeningReport.new(
          dep_enabled: dep_ok,
          aslr_enabled: aslr_ok,
          has_relocations: has_reloc,
          warnings: warnings
        )
      end
    end
  end
end
