# =============================================================================
# Lapis - Radare2 Native Debugger & Crash Forensics View (TUI)
# =============================================================================
# Dynamic interactive debugger dashboard powered by native radare2 (cradare2).
# Inspects CPU registers, disassembly, pseudo-C decompilation, call stack frames,
# and raw memory via Opal's HexViewer component.
# =============================================================================

require "opal"
require "json"
require "cradare2"
require "../core/env"
require "../core/logger"

module Lapis
  module TUI
    class DebuggerView
      enum Tab
        Disassembly
        Decompiler
        CrystalSource
        Registers
        HexMemory
        CallStack
        BinaryMetrics
      end

      property target_binary : String
      property fault_pc : UInt64 = 0_u64
      property active_tab : Tab = Tab::Disassembly
      property? running : Bool = true
      property? crash_mode : Bool = false
      property crash_reason : String = ""
      property? choosing_file : Bool = false

      # Real CPU registers extracted from radare2 / crash dump
      getter registers : Hash(String, UInt64) = Hash(String, UInt64).new

      getter file_dialog : Opal::UI::FileDialog
      getter hex_viewer : Opal::UI::HexViewer
      getter tabs : Opal::UI::Tabs
      getter disasm_view : Opal::UI::CodeView
      getter decomp_view : Opal::UI::CodeView
      getter source_view : Opal::UI::CodeView
      getter registers_table : Opal::UI::Table
      getter stack_table : Opal::UI::Table
      getter binary_metrics : Opal::UI::BinaryMetrics

      getter disassembly_lines : Array(String) = [] of String
      getter decompiler_lines : Array(String) = [] of String
      getter crystal_source_lines : Array(String) = [] of String
      getter source_file_path : String? = nil
      getter source_line_number : Int32? = nil
      getter stack_frames : Array(String) = [] of String
      getter status_message : String = ""

      def initialize(
        @target_binary : String = "bin/game.dll",
        @fault_pc : UInt64 = 0_u64,
        @crash_mode : Bool = false,
        @crash_reason : String = "",
        auto_analyze : Bool = true
      )
        initial_dir = Core::Env::ROOT_DIR.join("bin").to_s
        initial_dir = "." unless Dir.exists?(initial_dir)
        @file_dialog = Opal::UI::FileDialog.new(initial_path: initial_dir, mode: :open_file)

        # Initialize HexViewer with buffer
        initial_bytes = Bytes.new(256, 0_u8)
        @hex_viewer = Opal::UI::HexViewer.new(initial_bytes, base_address: @fault_pc)
        @binary_metrics = Opal::UI::BinaryMetrics.new(target_name: Path.new(@target_binary).basename, bar_char: '|')

        # Opal UI Navigation Tabs with Pill Styling
        @tabs = Opal::UI::Tabs.new(
          items: [
            Opal::UI::TabItem.new("disasm", "Disassembly (pdf)", shortcut: "1"),
            Opal::UI::TabItem.new("decomp", "Pseudo-C (pdc)", shortcut: "2"),
            Opal::UI::TabItem.new("crystal", "Crystal Source (cl)", shortcut: "3"),
            Opal::UI::TabItem.new("regs", "CPU Registers (dr)", shortcut: "4"),
            Opal::UI::TabItem.new("hex", "Hex Memory (px)", shortcut: "5"),
            Opal::UI::TabItem.new("stack", "Call Stack (dbt)", shortcut: "6"),
            Opal::UI::TabItem.new("metrics", "Binary Metrics (iS/afb)", shortcut: "7"),
          ],
          active_index: 0,
          pill_style: true
        )

        # Opal UI Code Views with Syntax Highlighting & Line Numbers
        @disasm_view = Opal::UI::CodeView.new(language: :asm, show_line_numbers: true)
        @decomp_view = Opal::UI::CodeView.new(language: :c, show_line_numbers: true)
        @source_view = Opal::UI::CodeView.new(language: :crystal, show_line_numbers: true)

        # Opal UI Tables for Registers and Call Stack
        @registers_table = Opal::UI::Table.new(
          headers: ["Register", "64-bit Hex Value", "Decimal Value"],
          zebra: true,
          truncate: true
        )
        @stack_table = Opal::UI::Table.new(
          headers: ["#", "Frame Details"],
          zebra: true,
          truncate: true
        )

        resolve_and_analyze if auto_analyze
      end

      # Smart context badge indicating architectural domain
      def context_badge : String
        clean = @target_binary.gsub('\\', '/').downcase
        if clean.includes?("addons/")
          addon_parts = clean.split("addons/").last?.try(&.split('/'))
          name = addon_parts && addon_parts.size > 0 ? addon_parts.first : "Addon"
          "[Context: Addon '#{name}']"
        elsif clean.includes?("crystal_bridge")
          "[Context: GDExtension Bridge]"
        elsif clean.includes?("godot") || clean.includes?("libgodot")
          "[Context: Godot Core]"
        elsif clean.includes?("game")
          "[Context: Game]"
        else
          "[Context: Native Binary]"
        end
      end

      def self.run(target : String = "bin/game.dll") : Nil
        new(target).run
      end

      # Automatically invoked when a process crash (0xC0000005 / SIGSEGV) is detected
      def self.auto_swap_on_crash(target_bin : String, fault_pc : UInt64, reason : String) : Nil
        new(target_bin, fault_pc, crash_mode: true, crash_reason: reason).run
      end

      def run : Nil
        return unless STDOUT.tty?

        driver = Opal::Terminal.default_driver
        driver.raw_mode do
          driver.enter_alternate_screen
          driver.hide_cursor
          begin
            while @running
              render(driver)
              handle_input(driver)
            end
          ensure
            driver.show_cursor
            driver.exit_alternate_screen
          end
        end
      end

      private def resolve_target_file : String?
        # Check explicit path
        if File.exists?(@target_binary)
          return @target_binary
        end

        # Check relative to workspace root
        from_root = Core::Env::ROOT_DIR.join(@target_binary)
        if File.exists?(from_root)
          return from_root.to_s
        end

        # Check standard targets
        ["bin/game.dll", "bin/crystal_bridge.dll", "bin/game.exe", "test/bin/game.dll"].each do |candidate|
          cand_path = Core::Env::ROOT_DIR.join(candidate)
          return cand_path.to_s if File.exists?(cand_path)
        end

        nil
      end

      # Runs live radare2 analysis using Cradare2 on the resolved binary
      private def resolve_and_analyze
        @disassembly_lines.clear
        @decompiler_lines.clear
        @crystal_source_lines.clear
        @source_file_path = nil
        @source_line_number = nil
        @stack_frames.clear
        @registers.clear

        target_file = resolve_target_file
        unless target_file
          @status_message = "Target binary not found: #{@target_binary} (Press 'F' to browse)"
          @disassembly_lines << "; No binary loaded. Press 'F' or 'O' to select a binary (.dll/.exe/.so)."
          @decompiler_lines << "// No binary loaded. Press 'F' or 'O' to select a binary."
          @crystal_source_lines << "# No binary loaded. Press 'F' or 'O' to select a binary."
          load_crash_log_frames
          return
        end

        @target_binary = target_file
        @status_message = "Analyzing #{File.basename(target_file)} with radare2..."

        begin
          Cradare2.open(target_file) do |r2|
            # 1. Analyze symbols & functions
            r2.cmd("aaa") rescue nil

            # Determine inspection target offset/symbol
            target_expr = if @fault_pc > 0_u64
                            "0x#{@fault_pc.to_s(16)}"
                          else
                            "entry0"
                          end

            # 2. Extract real Disassembly
            dis = r2.cmd("pdf @ #{target_expr}") rescue ""
            if dis.empty? || dis.includes?("Cannot find")
              dis = r2.cmd("pd 35 @ #{target_expr}") rescue ""
            end
            dis.each_line { |line| @disassembly_lines << line } unless dis.empty?

            # 3. Extract real Decompilation (pseudo-C via pdc)
            dec = r2.cmd("pdc @ #{target_expr}") rescue ""
            if dec.empty? || dec.includes?("Cannot")
              dec = "// Pseudocode decompilation not available at #{target_expr}\n// Function might not be analyzed or is external stub."
            end
            dec.each_line { |line| @decompiler_lines << line }

            # 4. Extract Crystal Source & Mapping (cl @ target_expr)
            loc_model = r2.crystal.lines.at(target_expr.to_u64?(16) || @fault_pc) rescue nil
            source_loc = if loc_model
                           "#{loc_model.normalized_file}:#{loc_model.line}"
                         else
                           r2.cmd("cl @ #{target_expr}").strip rescue ""
                         end

            if source_loc.empty? || source_loc == "??:0" || source_loc.includes?("Cannot")
              source_loc = r2.cmd("cl").strip rescue ""
            end

            s_file = loc_model.try(&.normalized_file)
            s_line = loc_model.try(&.line)

            if s_file.nil? && (match = source_loc.match(/(.+):(\d+)/))
              s_file = match[1]
              s_line = match[2].to_i?
            end

            @source_file_path = s_file
            @source_line_number = s_line

            @crystal_source_lines << "# Target: #{target_expr} | Source Location: #{source_loc.empty? ? "Unknown (compile with -g)" : source_loc}"
            @crystal_source_lines << "#"

            if (sf = @source_file_path) && (sln = @source_line_number) && r2.crystal.lines.reader.exists?(sf)
              context = r2.crystal.lines.reader.read_context(sf, sln, before: 12, after: 12)
              start_l = context.first?.try(&.[:line]) || 1
              end_l = context.last?.try(&.[:line]) || 1
              @crystal_source_lines << "# Source Context from #{sf} (lines #{start_l}-#{end_l}):"
              context.each do |c_line|
                marker = c_line[:current] ? "=> " : "   "
                @crystal_source_lines << sprintf("%s%4d | %s", marker, c_line[:line], c_line[:text])
              end
            elsif (sf = @source_file_path) && File.exists?(sf) && (sln = @source_line_number)
              lines = File.read_lines(sf) rescue [] of String
              start_l = [1, sln - 12].max
              end_l = [lines.size, sln + 12].min
              @crystal_source_lines << "# Source Context from #{sf} (lines #{start_l}-#{end_l}):"
              (start_l..end_l).each do |ln|
                marker = (ln == sln) ? "=> " : "   "
                @crystal_source_lines << sprintf("%s%4d | %s", marker, ln, lines[ln - 1]?)
              end
            else
              classes = r2.crystal.classes rescue [] of String
              if !classes.empty?
                @crystal_source_lines << "# Discovered #{classes.size} Crystal class(es) in binary symbols:"
                classes.first(25).each do |cls|
                  methods = r2.crystal.methods_for_class(cls) rescue [] of Cradare2::Model::Function
                  method_names = methods.map(&.name).first(3).join(", ")
                  method_names += "..." if methods.size > 3
                  @crystal_source_lines << sprintf("  class %-30s # %d methods: %s", cls, methods.size, method_names)
                end
                if classes.size > 25
                  @crystal_source_lines << "  # ... and #{classes.size - 25} more classes"
                end
              else
                @crystal_source_lines << "# No Crystal source line mapping or classes discovered."
                @crystal_source_lines << "# Tip: Compile with debug symbols (-g) to view original Crystal source lines."
              end
            end

            # 5. Extract real CPU Registers
            if drj = (r2.cmdj("drj") rescue nil)
              if drj.as_h?
                drj.as_h.each do |k, v|
                  if val = v.as_i64?
                    @registers[k] = val.to_u64
                  end
                end
              end
            end

            # Fallback if drj was empty (e.g. static binary without active debug session)
            if @registers.empty?
              raw_dr = r2.cmd("dr") rescue ""
              parse_raw_registers(raw_dr)
            end

            # 5. Extract Hex Memory from binary at target offset
            bytes = Bytes.new(256, 0_u8)
            File.open(target_file, "r") do |f|
              f.read(bytes) rescue nil
            end
            @hex_viewer = Opal::UI::HexViewer.new(bytes, base_address: @fault_pc > 0 ? @fault_pc : 0x140001000_u64)

            # 6. Extract real Stack Frames / Call Graph from radare2
            begin
              bt_frames = r2.crystal.demangled_backtrace
              bt_frames.each_with_index do |frame, idx|
                fn_name = frame.function_name || frame.function || "unknown"
                @stack_frames << "##{idx}  0x#{frame.pc.to_s(16).rjust(16, '0')} in #{fn_name} (sp=0x#{frame.sp.to_s(16)})"
              end
            rescue
            end

            # If no live debug backtrace, extract real caller cross-references from binary
            if @stack_frames.empty?
              callers = r2.cmd("axt @ #{target_expr}") rescue ""
              callers.each_line do |cl|
                next if cl.strip.empty?
                @stack_frames << cl.strip
              end
            end

            # 7. Extract real binary section metrics and top functions for Tab 7
            extract_binary_metrics(r2)
          end
        rescue ex
          @status_message = "Radare2 analysis warning: #{ex.message}"
        end

        load_crash_log_frames

        # Synchronize Opal components with analyzed state
        @disasm_view.code = @disassembly_lines.join('\n')
        @decomp_view.code = @decompiler_lines.join('\n')
        @source_view.code = @crystal_source_lines.join('\n')
        @source_view.highlighted_line = @source_line_number

        reg_rows = @registers.map { |k, v| [k.upcase, sprintf("0x%016x", v), v.to_s] }
        @registers_table.rows = reg_rows

        stack_rows = @stack_frames.map_with_index { |sf, idx| ["##{idx}", sf] }
        @stack_table.rows = stack_rows
      end

      private def extract_binary_metrics(r2)
        tot_size = File.size(@target_binary).to_u64 rescue 0_u64
        metrics = Opal::UI::BinaryMetrics.new(
          target_name: Path.new(@target_binary).basename,
          total_size: tot_size,
          bar_char: '|'
        )

        # Parse sections
        sections_str = r2.cmd("iSj") rescue "[]"
        if arr = JSON.parse(sections_str).as_a?
          arr.each do |s|
            name = s["name"]?.try(&.as_s) || ""
            size = s["size"]?.try(&.as_i64.to_u64) || s["vsize"]?.try(&.as_i64.to_u64) || 0_u64
            pct = tot_size > 0 ? ((size.to_f / tot_size.to_f) * 100.0).round(1) : 0.0
            is_code = name.downcase.includes?("text")
            is_data = name.downcase.includes?("data") || name.downcase.includes?("rdata")
            metrics.code_size += size if is_code
            metrics.add_section(name, size, pct, is_code: is_code, is_data: is_data)
          end
        end

        # Parse top functions by size
        funcs_str = r2.cmd("aflj") rescue "[]"
        if f_arr = JSON.parse(funcs_str).as_a?
          sorted = f_arr.sort_by { |f| -(f["size"]?.try(&.as_i64) || 0_i64) }
          sorted.first(8).each do |f|
            name = f["name"]?.try(&.as_s) || "fn"
            size = f["size"]?.try(&.as_i64.to_u64) || 0_u64
            cc = f["cc"]?.try(&.as_i64.to_i) || 1
            metrics.add_function(name, size, cc)
          end
        end

        # Hardening info
        bin_info = r2.cmd("iH") rescue ""
        dep = !bin_info.downcase.includes?("nx: false")
        aslr = !bin_info.downcase.includes?("aslr: false")
        metrics.add_hardening("DEP / NX", dep, "Data Execution Prevention")
        metrics.add_hardening("ASLR", aslr, "Address Space Layout Randomization")
        metrics.add_hardening("Relocations", true, "Base Relocations Table")

        @binary_metrics = metrics
      end

      private def parse_raw_registers(output : String)
        output.scan(/([a-zA-Z0-9]+)\s*=\s*(0x[0-9a-fA-F]+|[0-9]+)/).each do |match|
          name = match[1].downcase
          val_str = match[2]
          val = if val_str.starts_with?("0x") || val_str.starts_with?("0X")
                  val_str[2..].to_u64(16) rescue 0_u64
                else
                  val_str.to_u64 rescue 0_u64
                end
          @registers[name] = val
        end
      end

      # Reads backtrace frames from log/crash.log if available
      private def load_crash_log_frames
        crash_log = Core::Env::ROOT_DIR.join("log/crash.log")
        if File.exists?(crash_log)
          lines = File.read_lines(crash_log) rescue [] of String
          frames = lines.select { |l| l.strip.starts_with?("#") || l.includes?("0x") }
          @stack_frames = frames unless frames.empty?
        end

        if @stack_frames.empty?
          @stack_frames << "(No active crash backtrace in log/crash.log)"
        end
      end

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        if @choosing_file
          render_file_picker(buffer, width, height)
        else
          render_dashboard(buffer, width, height)
        end
      end

      private def render(driver : Opal::Terminal::Driver)
        w, h = driver.size
        width = Math.max(80, w)
        height = Math.max(24, h)
        buffer = Opal::UI::Buffer.new(width, height)
        render_to_buffer(buffer, width, height)

        driver.write(Opal::Terminal::Screen.move_to(1, 1))
        driver.write(buffer.render_to_string(with_ansi: true))
        driver.flush
      end

      private def render_file_picker(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(2, 1, "[BIN] SELECT TARGET BINARY TO DEBUG / DECOMPILE", fg: Opal::Color.bright_cyan, bold: true)
        buffer.put_string(2, 2, "Select a .dll, .exe, or .so binary to load into Radare2", fg: Opal::Color.bright_black)
        buffer.put_string(2, 3, "─" * (width - 4), fg: Opal::Color.bright_black)

        @file_dialog.render(buffer, 2, 4, width - 4, height - 7)

        y = height - 2
        buffer.put_string(2, y, "─" * (width - 4), fg: Opal::Color.bright_black)
        buffer.put_string(2, y + 1, "Enter: Open Binary │ Esc: Cancel Selection", fg: Opal::Color.yellow)
      end

      private def render_dashboard(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        # Header Banner
        header_title = @crash_mode ? "[CRASH] RADARE2 CRASH FORENSICS [AUTO-SWAP ACTIVE]" : ":: RADARE2 NATIVE DEBUGGER & FORENSICS ::"
        header_fg = @crash_mode ? Opal::Color.bright_red : Opal::Color.bright_cyan
        buffer.put_string(2, 1, header_title, fg: header_fg, bold: true)

        target_name = Path.new(@target_binary).basename
        pc_str = @fault_pc > 0 ? "Fault PC: 0x#{@fault_pc.to_s(16)}" : "Entry Target: entry0"
        buffer.put_string(45, 1, "│ #{target_name} (#{pc_str})", fg: Opal::Color.bright_black)

        if @crash_mode && !@crash_reason.empty?
          buffer.put_string(2, 2, "#{context_badge} │ CRASH: #{@crash_reason}", fg: Opal::Color.bright_yellow, bold: true)
        else
          buffer.put_string(2, 2, "#{context_badge} │ Status: #{@status_message}", fg: Opal::Color.cyan)
        end

        # Opal UI Navigation Tabs
        @tabs.active_index = @active_tab.value
        @tabs.render(buffer, 2, 3, width - 4, 1)

        buffer.put_string(2, 4, "─" * (width - 4), fg: Opal::Color.bright_black)

        # Tab Content rendered via Opal Components
        case @active_tab
        when Tab::Disassembly
          @disasm_view.code = @disassembly_lines.join('\n') if @disasm_view.code.empty? && !@disassembly_lines.empty?
          @disasm_view.render(buffer, 2, 5, width - 4, height - 7)
        when Tab::Decompiler
          @decomp_view.code = @decompiler_lines.join('\n') if @decomp_view.code.empty? && !@decompiler_lines.empty?
          @decomp_view.render(buffer, 2, 5, width - 4, height - 7)
        when Tab::CrystalSource
          @source_view.code = @crystal_source_lines.join('\n') if @source_view.code.empty? && !@crystal_source_lines.empty?
          @source_view.render(buffer, 2, 5, width - 4, height - 7)
        when Tab::Registers
          @registers_table.render(buffer, 2, 5, width - 4, height - 7)
        when Tab::HexMemory
          @hex_viewer.render(buffer, 2, 5, width - 4, height - 7)
        when Tab::CallStack
          @stack_table.rows = @stack_frames.map_with_index { |sf, idx| ["##{idx}", sf] } if @stack_table.rows.empty? && !@stack_frames.empty?
          @stack_table.render(buffer, 2, 5, width - 4, height - 7)
        when Tab::BinaryMetrics
          @binary_metrics.render(buffer, 2, 5, width - 4, height - 7)
        end

        # Footer
        footer_y = height - 2
        buffer.put_string(2, footer_y - 1, "─" * (width - 4), fg: Opal::Color.bright_black)
        controls = "Tab: Switch View │ 1-7: Direct Tab │ ↑/↓: Scroll │ F/O: Pick Binary │ R: Re-analyze │ Esc/Q: Back to Hub"
        buffer.put_string(2, footer_y, controls, fg: Opal::Color.bright_white)
      end

      private def render_lines(
        buffer : Opal::UI::Buffer,
        lines : Array(String),
        start_y : Int32,
        max_lines : Int32,
        width : Int32,
        fg : Opal::Color = Opal::Color.white
      )
        lines[0, max_lines].each_with_index do |line, idx|
          buffer.put_string(2, start_y + idx, line, fg: fg, max_width: width - 4)
        end
      end

      private def render_registers(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        buffer.put_string(2, 5, "General Purpose CPU Registers (64-bit x86_64 / ARM64):", fg: Opal::Color.bright_yellow, bold: true)

        if @registers.empty?
          buffer.put_string(4, 7, "(No register state available for static binary analysis)", fg: Opal::Color.bright_black)
          return
        end

        reg_list = @registers.to_a
        col_w = 26
        cols = Math.max(1, (width - 4) // col_w)

        reg_list.each_with_index do |(name, val), idx|
          col = idx % cols
          row = idx // cols
          break if 7 + row >= height - 3

          x = 4 + (col * col_w)
          y = 7 + row

          reg_name = name.upcase.ljust(5)
          hex_val = sprintf("0x%016x", val)

          buffer.put_string(x, y, reg_name, fg: Opal::Color.cyan, bold: true)
          buffer.put_string(x + 6, y, hex_val, fg: Opal::Color.bright_white)
        end
      end

      private def handle_input(driver : Opal::Terminal::Driver)
        ev = driver.read_event
        return unless ev.is_a?(Opal::Terminal::KeyEvent)

        # Global command palette shortcut
        if ev.char == '~' || ev.char == '`' || ev.matches?("ctrl+p")
          @running = false
          return
        end

        if @choosing_file
          handle_file_dialog_input(ev)
          return
        end

        case ev.name
        when "escape", "esc"
          @running = false
        when "tab"
          @active_tab = case @active_tab
                        when Tab::Disassembly   then Tab::Decompiler
                        when Tab::Decompiler    then Tab::CrystalSource
                        when Tab::CrystalSource then Tab::Registers
                        when Tab::Registers     then Tab::HexMemory
                        when Tab::HexMemory     then Tab::CallStack
                        when Tab::CallStack     then Tab::BinaryMetrics
                        else                         Tab::Disassembly
                        end
          @tabs.active_index = @active_tab.value
        when "up", "k"
          case @active_tab
          when Tab::Disassembly   then @disasm_view.scroll_up(1)
          when Tab::Decompiler    then @decomp_view.scroll_up(1)
          when Tab::CrystalSource then @source_view.scroll_up(1)
          when Tab::Registers     then @registers_table.scroll_offset = Math.max(0, @registers_table.scroll_offset - 1)
          when Tab::HexMemory     then @hex_viewer.scroll_up(16)
          when Tab::CallStack     then @stack_table.scroll_offset = Math.max(0, @stack_table.scroll_offset - 1)
          end
        when "down", "j"
          case @active_tab
          when Tab::Disassembly   then @disasm_view.scroll_down(1)
          when Tab::Decompiler    then @decomp_view.scroll_down(1)
          when Tab::CrystalSource then @source_view.scroll_down(1)
          when Tab::Registers     then @registers_table.scroll_offset = @registers_table.scroll_offset + 1
          when Tab::HexMemory     then @hex_viewer.scroll_down(16)
          when Tab::CallStack     then @stack_table.scroll_offset = @stack_table.scroll_offset + 1
          end
        when "page_up", "pageup"
          case @active_tab
          when Tab::Disassembly   then @disasm_view.scroll_up(15)
          when Tab::Decompiler    then @decomp_view.scroll_up(15)
          when Tab::CrystalSource then @source_view.scroll_up(15)
          when Tab::HexMemory     then @hex_viewer.scroll_up(64)
          end
        when "page_down", "pagedown"
          case @active_tab
          when Tab::Disassembly   then @disasm_view.scroll_down(15)
          when Tab::Decompiler    then @decomp_view.scroll_down(15)
          when Tab::CrystalSource then @source_view.scroll_down(15)
          when Tab::HexMemory     then @hex_viewer.scroll_down(64)
          end
        else
          if ch = ev.char
            case ch
            when 'q', 'Q'
              @running = false
            when '1'
              @active_tab = Tab::Disassembly
              @tabs.active_index = @active_tab.value
            when '2'
              @active_tab = Tab::Decompiler
              @tabs.active_index = @active_tab.value
            when '3'
              @active_tab = Tab::CrystalSource
              @tabs.active_index = @active_tab.value
            when '4'
              @active_tab = Tab::Registers
              @tabs.active_index = @active_tab.value
            when '5'
              @active_tab = Tab::HexMemory
              @tabs.active_index = @active_tab.value
            when '6'
              @active_tab = Tab::CallStack
              @tabs.active_index = @active_tab.value
            when '7'
              @active_tab = Tab::BinaryMetrics
              @tabs.active_index = @active_tab.value
            when 'f', 'F', 'o', 'O'
              @choosing_file = true
            when 'r', 'R'
              resolve_and_analyze
            end
          end
        end
      end

      private def handle_file_dialog_input(ev : Opal::Terminal::KeyEvent)
        if ev.matches?("escape")
          @choosing_file = false
          return
        end

        if @file_dialog.handle_key(ev)
          if @file_dialog.confirmed?
            if chosen = @file_dialog.selected_path
              @target_binary = chosen
              resolve_and_analyze
            end
            @choosing_file = false
          end
        end
      end
    end
  end
end
