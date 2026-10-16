# tools/lapis/src/commands/decompile.cr
require "cradare2"
require "opal"
require "option_parser"
require "../core/logger"
require "../core/env"
require "../tui/debugger_view"
require "../../../../src/libgodot/debugger/r2_godot_plugin"

module Lapis
  module Commands
    module Decompile
      def self.print_help
        puts <<-HELP
\e[35m=== Lapis: Native Binary Decompiler & Disassembly ===\e[0m

Usage: lapis decompile <binary> [symbol_or_offset] [options]

Arguments:
  <binary>                   Path to binary (.dll, .so, .exe, or .dylib)
  [symbol_or_offset]         Function name, Crystal method (e.g. 'Player#_process'), or hex offset (0x...)

Options:
  --tui                      Launch interactive TUI decompiler & browser
  --no-tui                   Disable interactive TUI and output directly to terminal
  -a, --asm                  Output disassembly (pdf) instead of pseudo-C
  -s, --side-by-side         Output side-by-side assembly and pseudo-C (pdca)
  -S, --source               Display Crystal source code context and lines using debug symbols
  -c, --class=CLASS          Decompile all methods for a specific Crystal class
  --crystal                  Inspect Crystal runtime models, classes, and GC symbols
  --godot                    Inspect Godot engine models, ClassDB, and print formats
  --object=ADDR              Inspect Godot Object header at memory address
  --variant=ADDR             Decode Godot Variant payload at memory address
  --symbols                  List all functions and symbols present in the binary
  --verify                   Verify GDExtension binary health and entry points
  -o, --output=FILE          Write decompiled output to file
  -h, --help                 Show this help screen

Examples:
  lapis decompile bin/game.dll
  lapis decompile bin/game.dll --godot
  lapis decompile bin/game.dll --object 0x140020000
  lapis decompile bin/game.dll "Player#_physics_process"
  lapis decompile bin/game.dll "Player#_physics_process" --source
  lapis decompile bin/crystal_bridge.dll 0x140001000
  lapis decompile bin/game.dll --class Player
  lapis decompile bin/game.dll --crystal
  lapis decompile bin/game.dll "Player#_process" --asm
  lapis decompile bin/game.dll "Player#_process" --side-by-side
  lapis decompile bin/crystal_bridge.dll --verify
HELP
      end

      def self.run(args : Array(String)) : Int32
        if args.empty? || args.includes?("-h") || args.includes?("--help")
          print_help
          return 0
        end

        binary_path : String? = nil
        target : String? = nil
        output_file : String? = nil
        class_filter : String? = nil
        mode_asm = false
        mode_side_by_side = false
        mode_source = false
        mode_crystal = false
        mode_godot = false
        object_target : String? = nil
        variant_target : String? = nil
        mode_symbols = false
        mode_verify = false
        force_tui : Bool? = nil

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: lapis decompile <binary> [symbol_or_offset] [options]"
          opts.on("--tui", "Launch interactive TUI explorer") { force_tui = true }
          opts.on("--no-tui", "Disable interactive TUI") { force_tui = false }
          opts.on("-a", "--asm", "Output disassembly instead of pseudo-C") { mode_asm = true }
          opts.on("-s", "--side-by-side", "Side-by-side assembly and pseudo-C") { mode_side_by_side = true }
          opts.on("-S", "--source", "Display Crystal source code context and lines") { mode_source = true }
          opts.on("-c CLASS", "--class=CLASS", "Decompile all methods for class") { |c| class_filter = c }
          opts.on("--crystal", "Inspect Crystal runtime models, classes, and GC symbols") { mode_crystal = true }
          opts.on("--godot", "Inspect Godot engine models, ClassDB, and print formats") { mode_godot = true }
          opts.on("--object=ADDR", "Inspect Godot Object header at address") { |a| object_target = a }
          opts.on("--variant=ADDR", "Decode Godot Variant at address") { |a| variant_target = a }
          opts.on("--symbols", "List functions and symbols") { mode_symbols = true }
          opts.on("--verify", "Verify GDExtension binary health") { mode_verify = true }
          opts.on("-o FILE", "--output=FILE", "Save output to file") { |f| output_file = f }
          opts.on("-h", "--help", "Show help") { print_help; exit 0 }
          opts.unknown_args do |before, after|
            remaining = before + after
            binary_path = remaining[0]?
            target = remaining[1]? if remaining.size > 1
          end
        end

        parser.parse(args)

        target_file = binary_path
        unless target_file && File.exists?(target_file)
          Core::Logger.error("Target binary does not exist: #{target_file || "(none specified)"}")
          return 1
        end

        begin
          Cradare2.open(target_file) do |r2|
            # 1. Interactive TUI Mode: Launch when no single target/filter is specified and TTY or forced
            should_launch_tui = if force_tui == true
                                  true
                                elsif force_tui == false
                                  false
                                else
                                  target.nil? && class_filter.nil? && !mode_verify && !mode_symbols && !mode_crystal && !mode_source && output_file.nil? && STDOUT.tty?
                                end

            if should_launch_tui
              TUI::DebuggerView.run(target_file)
              return 0
            end

            # 2. GDExtension Verification Mode
            if mode_verify
              info = r2.info
              exports = r2.exports
              common_ep = ["lapis_gdextension_entry", "godot_gdextension_entry", "gdextension_initialize", "gdextension_entry"]
              found_ep = exports.find { |e| common_ep.any? { |ep| e.name.includes?(ep) } }
              godot_imports = r2.imports_matching(/godot|gdextension/i)
              has_pic = info.pic?
              has_nx = info.bin.try(&.nx) == true
              has_canary = info.bin.try(&.canary) == true

              term_w = [Opal.terminal.columns, 80].max
              dashboard = Opal.render_ui(term_w, 24) do |ui|
                ui.vstack do |root|
                  root.box(title: "GDExtension Binary Health Check: #{File.basename(target_file)}", border_fg: :cyan) do |b|
                    b.vstack do |v|
                      v.hstack do |h|
                        h.text("Architecture: ", bold: true)
                        h.text("#{info.arch} (#{info.bits}-bit, #{info.format.upcase})  ")
                        h.text("Entrypoint: ", bold: true)
                        if found_ep
                          h.badge(" [✓] #{found_ep.name} ", bg: :green, fg: :white)
                        else
                          h.badge(" [✗] MISSING ENTRYPOINT ", bg: :red, fg: :white)
                        end
                      end
                      v.text("")
                      v.table(headers: ["Component", "Status", "Metric Details"]) do |tbl|
                        tbl.row([
                          "Export Table",
                          exports.empty? ? "[✗] EMPTY" : "[✓] VALID",
                          "#{exports.size} exported symbol(s) detected"
                        ])
                        tbl.row([
                          "Godot C-API",
                          godot_imports.empty? ? "[!] NONE" : "[✓] DETECTED",
                          "#{godot_imports.size} binding import(s) detected"
                        ])
                        tbl.row([
                          "ASLR / PIC",
                          has_pic ? "[✓] ENABLED" : "[!] DISABLED",
                          has_pic ? "Dynamic base relocations active" : "Fixed address base"
                        ])
                        tbl.row([
                          "DEP / NX",
                          has_nx ? "[✓] ENABLED" : "[!] DISABLED",
                          has_nx ? "Non-executable stack protected" : "Executable stack risk"
                        ])
                        tbl.row([
                          "Stack Canary",
                          has_canary ? "[✓] ENABLED" : "[!] DISABLED",
                          has_canary ? "Stack smashing protection active" : "No buffer canary"
                        ])
                      end
                    end
                  end
                end
              end

              puts dashboard
              return found_ep ? 0 : 1
            end

            # 3. Crystal Runtime Inspection Mode
            if mode_crystal
              is_crystal = r2.crystal.crystal_binary? rescue false
              classes = r2.crystal.classes rescue [] of String
              ep = r2.crystal.entrypoint rescue nil
              gc_fns = r2.crystal.gc_functions rescue [] of Cradare2::Model::Function
              main_fn = r2.crystal.crystal_main_function rescue nil

              term_w = [Opal.terminal.columns, 80].max
              dashboard = Opal.render_ui(term_w, [classes.size + 14, 28].min) do |ui|
                ui.box(title: "Crystal Runtime Inspection: #{File.basename(target_file)}", border_fg: :cyan) do |b|
                  b.vstack do |v|
                    v.hstack do |h|
                      h.text("Crystal Binary: ", bold: true)
                      if is_crystal
                        h.badge(" [✓] DETECTED ", bg: :green, fg: :white)
                      else
                        h.badge(" [!] UNKNOWN / C++ ", bg: :yellow, fg: :black)
                      end
                      h.text("  Classes: ", bold: true)
                      h.text("#{classes.size}  ")
                      h.text("GC Functions: ", bold: true)
                      h.text("#{gc_fns.size}")
                    end
                    v.text("")
                    if main_fn
                      v.text("Main Entrypoint: #{main_fn.name} (0x#{main_fn.offset.to_s(16)})", fg: :cyan)
                    elsif ep
                      v.text("Main Entrypoint: 0x#{ep.to_s(16)}", fg: :cyan)
                    end
                    v.text("")
                    v.text("Discovered Crystal Classes (#{classes.size}):", bold: true, fg: :yellow)
                    classes.first(15).each do |cls|
                      methods = r2.crystal.methods_for_class(cls) rescue [] of Cradare2::Model::Function
                      v.text("  - #{cls} (#{methods.size} methods)", fg: :white)
                    end
                    if classes.size > 15
                      v.text("  ... and #{classes.size - 15} more classes", fg: :bright_black)
                    end
                  end
                end
              end
              puts dashboard
              return 0
            end

            # 3b. Godot Integration & ClassDB Mode
            if mode_godot
              plugin = ::Lapis::Debugger::R2GodotPlugin.new(r2)
              puts plugin.dispatch("godot detect")
              puts
              puts plugin.dispatch("godot classdb")
              return 0
            end

            # 3c. Targeted Object Header Inspection
            if obj_addr = object_target
              plugin = ::Lapis::Debugger::R2GodotPlugin.new(r2)
              puts plugin.dispatch("godot object #{obj_addr}")
              return 0
            end

            # 3d. Targeted Variant Payload Inspection
            if var_addr = variant_target
              plugin = ::Lapis::Debugger::R2GodotPlugin.new(r2)
              puts plugin.dispatch("godot variant #{var_addr}")
              return 0
            end

            # 4. List Symbols Mode
            if mode_symbols
              functions = r2.functions
              term_w = [Opal.terminal.columns, 80].max
              tbl_rendered = Opal.render_ui(term_w, functions.size + 4) do |ui|
                ui.box(title: "Analyzed Functions in #{File.basename(target_file)} (#{functions.size})", border_fg: :cyan) do |b|
                  b.table(headers: ["Offset", "Function Name", "Size"], header_fg: :cyan) do |tbl|
                    functions.each do |fn|
                      demangled = Cradare2::Util::Demangler.demangle(fn.name, r2.transport)
                      tbl.row(["0x#{fn.offset.to_s(16).rjust(12, '0')}", demangled, "#{fn.size} B"])
                    end
                  end
                end
              end
              puts tbl_rendered
              return 0
            end

            # 4. Class Methods Batch Decompilation Mode
            if cf = class_filter
              methods = r2.crystal.methods_for_class(cf)
              if methods.empty?
                Core::Logger.warn("No functions found for Crystal class '#{cf}'. Checking symbols...")
                syms = r2.crystal.symbols_for_class(cf)
                if syms.empty?
                  Core::Logger.error("Class '#{cf}' not found in binary.")
                  return 1
                end
              end

              output_buf = IO::Memory.new
              output_buf.puts "// ============================================================================="
              output_buf.puts "// Decompiled Methods for Class: #{cf} (#{methods.size} functions)"
              output_buf.puts "// =============================================================================\n"

              methods.each do |method_fn|
                offset_hex = "0x#{method_fn.offset.to_s(16)}"
                code = if mode_asm
                         r2.disasm.function_text(offset_hex)
                       elsif mode_side_by_side
                         r2.disasm.side_by_side(offset_hex)
                       else
                         r2.disasm.decompile(offset_hex)
                       end
                output_buf.puts code
                output_buf.puts "\n"
              end

              result_text = output_buf.to_s
              if out_f = output_file
                File.write(out_f, result_text)
                Core::Logger.success("Decompiled #{methods.size} method(s) to #{out_f}")
              else
                puts result_text
              end
              return 0
            end

            # 5. Single Target Decompilation Mode
            target_str = (target || "entry0").to_s
            offset_hex = if target_str.starts_with?("0x") || target_str.starts_with?("0X")
                           target_str
                         else
                           matching_fn = r2.functions_matching(target_str).first?
                           if matching_fn
                             "0x#{matching_fn.offset.to_s(16)}"
                           else
                             matching_sym = r2.symbols_matching(target_str).first?
                             matching_sym ? "0x#{matching_sym.vaddr.to_s(16)}" : target_str
                           end
                         end

            r2.cmd("af @ #{offset_hex}") rescue nil

            if mode_source
              loc_model = r2.crystal.lines.at(offset_hex.to_u64?(16) || 0_u64) rescue nil
              source_loc = if loc_model
                             "#{loc_model.normalized_file}:#{loc_model.line}"
                           else
                             r2.cmd("cl @ #{offset_hex}").strip rescue ""
                           end

              source_disasm = r2.disasm.source_interleaved(offset_hex, 20)
              if source_disasm.empty? || source_disasm.includes?("Cannot")
                source_disasm = r2.cmd("pdsf @ #{offset_hex}").strip rescue ""
              end

              source_file = loc_model.try(&.normalized_file)
              source_line_num = loc_model.try(&.line)

              if source_file.nil? && (match = source_loc.match(/(.+):(\d+)/))
                source_file = match[1]
                source_line_num = match[2].to_i?
              end

              source_preview = IO::Memory.new
              if source_file && source_line_num && r2.crystal.lines.reader.exists?(source_file)
                context = r2.crystal.lines.reader.read_context(source_file, source_line_num, before: 5, after: 5)
                start_l = context.first?.try(&.[:line]) || 1
                end_l = context.last?.try(&.[:line]) || 1
                source_preview.puts "// Source File: #{source_file} (lines #{start_l}-#{end_l}):"
                context.each do |c_line|
                  marker = c_line[:current] ? "=> " : "   "
                  source_preview.puts sprintf("%s%4d | %s", marker, c_line[:line], c_line[:text])
                end
              elsif source_file && File.exists?(source_file) && source_line_num
                lines = File.read_lines(source_file) rescue [] of String
                start_l = [1, source_line_num - 5].max
                end_l = [lines.size, source_line_num + 5].min
                source_preview.puts "// Source File: #{source_file} (lines #{start_l}-#{end_l}):"
                (start_l..end_l).each do |ln|
                  marker = (ln == source_line_num) ? "=> " : "   "
                  source_preview.puts sprintf("%s%4d | %s", marker, ln, lines[ln - 1]?)
                end
              elsif !source_loc.empty? && source_loc != "??:0"
                source_preview.puts "// Source Location: #{source_loc}"
              else
                source_preview.puts "// No DWARF/PDB source line mapping available for #{target_str} (#{offset_hex})"
                source_preview.puts "// Tip: Recompile with debug symbols (-g) to embed DWARF source lines."
              end

              term_w = [Opal.terminal.columns, 90].max
              rendered = Opal.render_ui(term_w, 30) do |ui|
                ui.box(title: "Source Code Mapping: #{target_str} (#{offset_hex})", border_fg: :cyan) do |b|
                  b.vstack do |v|
                    v.text("Source Location: #{source_loc.empty? ? "Unknown" : source_loc}", bold: true, fg: :yellow)
                    v.text("")
                    v.code_view(source_preview.to_s, language: :crystal)
                    v.text("")
                    v.text("Source Interleaved Disassembly (pdls):", bold: true, fg: :cyan)
                    v.code_view(source_disasm.empty? ? "(No interleaved disassembly available)" : source_disasm, language: :asm)
                  end
                end
              end

              if out_f = output_file
                File.write(out_f, rendered)
                Core::Logger.success("Saved source mapping of #{target_str} to #{out_f}")
              else
                puts rendered
              end
            elsif mode_side_by_side
              asm_code = r2.disasm.function_text(offset_hex).strip
              c_code = r2.disasm.decompile(offset_hex, fallback_asm: false).strip
              if c_code.empty? || c_code.includes?("Cannot")
                c_code = "// Pseudocode decompilation unavailable for this symbol"
              end

              term_w = [Opal.terminal.columns, 100].max
              side_rendered = Opal.render_ui(term_w, 35) do |ui|
                ui.box(title: "Side-by-Side Decompilation: #{target_str} (#{offset_hex})", border_fg: :cyan) do |b|
                  b.split_view(ratio: 0.5) do |split|
                    split.first do |left|
                      left.code_view(asm_code, language: :asm)
                    end
                    split.second do |right|
                      right.code_view(c_code, language: :c)
                    end
                  end
                end
              end

              if out_f = output_file
                File.write(out_f, side_rendered)
                Core::Logger.success("Saved side-by-side decompilation to #{out_f}")
              else
                puts side_rendered
              end
            else
              decompiled = if mode_asm
                             r2.disasm.function_text(offset_hex)
                           elsif target_str.includes?('#')
                             parts = target_str.split('#', 2)
                             r2.crystal.decompile_method(parts[0], parts[1])
                           else
                             r2.disasm.decompile(offset_hex)
                           end

              if decompiled.empty? || decompiled.includes?("Cannot find function")
                Core::Logger.warn("pdc could not structure function; falling back to disassembly (pdf)...")
                decompiled = r2.cmd("pdf @ #{offset_hex}")
                mode_asm = true
              end

              if out_f = output_file
                File.write(out_f, decompiled)
                Core::Logger.success("Saved decompilation of #{target_str} to #{out_f}")
              else
                term_w = [Opal.terminal.columns, 80].max
                rendered = Opal.render_ui(term_w, decompiled.lines.size + 4) do |ui|
                  ui.box(title: "Decompiled: #{target_str} (#{offset_hex})", border_fg: :cyan) do |b|
                    b.code_view(decompiled, language: mode_asm ? :asm : :c)
                  end
                end
                puts rendered
              end
            end
          end
          0
        rescue ex
          Core::Logger.error("Decompilation failed: #{ex.message}")
          1
        end
      end
    end
  end
end
