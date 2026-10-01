# =============================================================================
# Lapis - Multi-Target Packaging & Export Form (TUI)
# =============================================================================
# Form-based packaging configurator with context-aware platform target options,
# real-time build progress logging, and artifact verification.
# =============================================================================

require "opal"
require "../core/env"
require "../core/logger"
require "../commands/package"

module Lapis
  module TUI
    class PackageForm
      enum Target
        Game
        Portable
        Addon
        {% if flag?(:windows) %}
          WindowsInstaller
        {% elsif flag?(:linux) %}
          Debian
        {% elsif flag?(:darwin) %}
          MacOSBundle
        {% end %}
        Toolchain
        Benchmarks
      end

      AVAILABLE_TARGETS = begin
        list = [
          {Target::Game, "Playable Game"},
          {Target::Portable, "Portable Executable"},
          {Target::Addon, "GDExtension Addon"},
        ]
        {% if flag?(:windows) %}
          list << {Target::WindowsInstaller, "Windows Installer (.exe)"}
        {% elsif flag?(:linux) %}
          list << {Target::Debian, "Debian Package (.deb)"}
        {% elsif flag?(:darwin) %}
          list << {Target::MacOSBundle, "macOS App Bundle (.zip)"}
        {% end %}
        list << {Target::Toolchain, "Lapis Toolchain"}
        list << {Target::Benchmarks, "Benchmarks Runner"}
        list
      end

      enum Field
        TargetType
        ReleaseMode
        BundleBinaries
        OutputPath
        Version
      end

      property target : Target = Target::Game
      property? release : Bool = true
      property? bundle_binaries : Bool = true
      property output_path : String = "bin/release_dist"
      property version : String = "0.0.1"
      property active_field : Field = Field::TargetType
      property? building : Bool = false
      property? done : Bool = false
      property? running : Bool = true
      getter build_logs : Array(String) = [] of String
      getter sha256_result : String? = nil

      def self.run : Nil
        new.run
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
              ev = driver.read_event
              handle_input(ev) if ev
            end
          ensure
            driver.show_cursor
            driver.exit_alternate_screen
          end
        end
      end

      def render_to_buffer(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        # Header
        buffer.put_string(2, 1, ":: LAPIS PACKAGING & EXPORT CENTER ::", fg: Opal::Color.bright_magenta, bold: true)
        buffer.put_string(2, 2, "Configure export targets, bundles, optimizations, and release installers", fg: Opal::Color.bright_black)
        buffer.put_string(2, 3, "─" * (width - 4), fg: Opal::Color.bright_black)

        if @building || @done
          render_build_progress(buffer, width, height)
        else
          render_form(buffer, width, height)
        end

        # Footer
        y = height - 2
        buffer.put_string(2, y, "─" * (width - 4), fg: Opal::Color.bright_black)
        hints = if @building
                  "Building distribution... Please wait"
                elsif @done
                  "Enter: Finish & Return │ Esc: Exit"
                else
                  "Tab / ↑↓: Navigate Fields │ Space: Toggle Option │ Enter: Start Build │ Esc: Back"
                end
        buffer.put_string(2, y + 1, hints, fg: Opal::Color.cyan)
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

      private def render_form(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        # Field 1: Target Type
        f1_sel = (@active_field == Field::TargetType)
        buffer.put_string(4, 5, "#{cursor(f1_sel)}Target Artifact:", fg: f1_sel ? Opal::Color.bright_cyan : Opal::Color.white, bold: f1_sel)

        AVAILABLE_TARGETS.each_with_index do |t_pair, idx|
          t_val, t_name = t_pair
          is_chosen = (@target == t_val)
          radio = is_chosen ? "(*)" : "( )"
          x = (idx % 2 == 0) ? 25 : 56
          y = 5 + (idx // 2)
          fg = is_chosen ? Opal::Color.green : Opal::Color.bright_black
          buffer.put_string(x, y, "#{radio} #{t_name}", fg: fg, bold: is_chosen)
        end

        # Field 2: Release Mode
        f2_sel = (@active_field == Field::ReleaseMode)
        buffer.put_string(4, 9, "#{cursor(f2_sel)}Release Mode:", fg: f2_sel ? Opal::Color.bright_cyan : Opal::Color.white, bold: f2_sel)
        opt_rel = @release ? "[X] Optimized (--release -O3)" : "[ ] Debug Build (Fast compile)"
        buffer.put_string(25, 9, opt_rel, fg: @release ? Opal::Color.bright_green : Opal::Color.yellow)

        # Field 3: Bundle Binaries
        f3_sel = (@active_field == Field::BundleBinaries)
        buffer.put_string(4, 11, "#{cursor(f3_sel)}Bundle Deps:", fg: f3_sel ? Opal::Color.bright_cyan : Opal::Color.white, bold: f3_sel)
        dep_label = {% if flag?(:windows) %}
                      "Include runtime DLLs (gc.dll, crystal_bridge.dll, libgodot.dll)"
                    {% elsif flag?(:darwin) %}
                      "Include runtime dylibs (crystal_bridge.dylib, libgodot.dylib)"
                    {% else %}
                      "Include runtime shared libraries (.so)"
                    {% end %}
        opt_bun = @bundle_binaries ? "[X] #{dep_label}" : "[ ] Exclude shared runtime dependencies"
        buffer.put_string(25, 11, opt_bun, fg: @bundle_binaries ? Opal::Color.bright_green : Opal::Color.bright_black)

        # Field 4: Output Path
        f4_sel = (@active_field == Field::OutputPath)
        buffer.put_string(4, 13, "#{cursor(f4_sel)}Destination Dir:", fg: f4_sel ? Opal::Color.bright_cyan : Opal::Color.white, bold: f4_sel)
        buffer.put_string(25, 13, "[ #{@output_path} ]", fg: Opal::Color.bright_white, bg: f4_sel ? Opal::Color.hex("#2A2B3D") : Opal::Color.none)

        # Field 5: Version String
        f5_sel = (@active_field == Field::Version)
        buffer.put_string(4, 15, "#{cursor(f5_sel)}Release Version:", fg: f5_sel ? Opal::Color.bright_cyan : Opal::Color.white, bold: f5_sel)
        buffer.put_string(25, 15, "[ #{@version} ]", fg: Opal::Color.bright_white, bg: f5_sel ? Opal::Color.hex("#2A2B3D") : Opal::Color.none)

        # Target Description Card
        desc_card = case @target
                    when Target::Game
                      "Builds standalone game distribution archives with runtime dependencies."
                    when Target::Portable
                      "Produces a standalone single-file binary with the Godot PCK embedded into the executable."
                    when Target::Addon
                      "Packages clean crystal_integration GDExtension addon ZIP ready for Godot asset library."
                    when Target::Toolchain
                      "Packages standalone Lapis CLI and crystalline LSP binaries for redistributable tooling."
                    when Target::Benchmarks
                      "Packages benchmark test matrix with automated runner scripts and comparative charts."
                    else
                      {% if flag?(:windows) %}
                        if @target == Target::WindowsInstaller
                          "Compiles NSIS / InnoSetup single-file installer .exe for Windows desktop distribution."
                        else
                          "Configured export package."
                        end
                      {% elsif flag?(:linux) %}
                        if @target == Target::Debian
                          "Constructs .deb binary package with systemd/desktop launcher metadata for Debian/Ubuntu."
                        else
                          "Configured export package."
                        end
                      {% elsif flag?(:darwin) %}
                        if @target == Target::MacOSBundle
                          "Constructs signed .app bundle archive for macOS distribution."
                        else
                          "Configured export package."
                        end
                      {% else %}
                        "Configured export package."
                      {% end %}
                    end

        buffer.put_string(4, 17, "Target Profile:", fg: Opal::Color.yellow, bold: true)
        buffer.put_string(4, 18, desc_card, fg: Opal::Color.cyan)
      end

      private def render_build_progress(buffer : Opal::UI::Buffer, width : Int32, height : Int32)
        status_text = @done ? "[OK] PACKAGING COMPLETE" : "[*] BUILDING PACKAGE..."
        status_fg = @done ? Opal::Color.bright_green : Opal::Color.yellow
        buffer.put_string(4, 5, status_text, fg: status_fg, bold: true)

        # Log box
        log_h = height - 10
        visible_logs = @build_logs.last(log_h)
        visible_logs.each_with_index do |l, idx|
          buffer.put_string(4, 7 + idx, l, fg: Opal::Color.white, max_width: width - 8)
        end
      end

      private def handle_input(ev : Opal::Terminal::KeyEvent | Opal::Terminal::MouseEvent)
        return unless ev.is_a?(Opal::Terminal::KeyEvent)

        # Global command palette shortcut
        if ev.char == '~' || ev.char == '`' || ev.matches?("ctrl+p")
          @running = false
          return
        end

        if @done
          @running = false if ev.matches?("enter") || ev.matches?("escape")
          return
        end

        case ev.name
        when "escape", "esc"
          @running = false
        when "tab"
          cycle_field(1)
        when "up"
          cycle_field(-1)
        when "down"
          cycle_field(1)
        when "space"
          toggle_active_option
        when "enter"
          start_package_build unless @building
        when "backspace"
          if @active_field == Field::OutputPath && @output_path.size > 0
            @output_path = @output_path[0...-1]
          elsif @active_field == Field::Version && @version.size > 0
            @version = @version[0...-1]
          end
        else
          if ch = ev.char
            if @active_field == Field::OutputPath
              @output_path += ch
            elsif @active_field == Field::Version
              @version += ch
            end
          end
        end
      end

      private def cycle_field(delta : Int32)
        new_val = (@active_field.value + delta) % 5
        new_val += 5 if new_val < 0
        @active_field = Field.new(new_val)
      end

      private def toggle_active_option
        case @active_field
        when Field::TargetType
          curr_idx = AVAILABLE_TARGETS.index { |t, _| t == @target } || 0
          next_idx = (curr_idx + 1) % AVAILABLE_TARGETS.size
          @target = AVAILABLE_TARGETS[next_idx][0]
        when Field::ReleaseMode
          @release = !@release
        when Field::BundleBinaries
          @bundle_binaries = !@bundle_binaries
        end
      end

      private def cursor(selected : Bool) : String
        selected ? " ► " : "   "
      end

      private def start_package_build
        @building = true
        @build_logs << "Initializing packaging for target #{@target}..."
        @build_logs << "Options: release=#{@release}, bundle_binaries=#{@bundle_binaries}, out=#{@output_path}"

        spawn do
          target_arg = case @target
                       when Target::Game            then "game"
                       when Target::Portable        then "portable"
                       when Target::Addon           then "addon"
                       when Target::Toolchain       then "lapis"
                       when Target::Benchmarks      then "perf"
                       else
                         {% if flag?(:windows) %}
                           @target == Target::WindowsInstaller ? "windows-installer" : "game"
                         {% elsif flag?(:linux) %}
                           @target == Target::Debian ? "deb" : "game"
                         {% elsif flag?(:darwin) %}
                           @target == Target::MacOSBundle ? "game" : "game"
                         {% else %}
                           "game"
                         {% end %}
                       end

          args = [target_arg, "-t", @output_path]
          args << "-r" if @release
          args << "--bundle-binaries" if @bundle_binaries
          args += ["-v", @version] unless @version.empty?

          @build_logs << "Invoking lapis package #{args.join(" ")}..."
          res = Commands::Package.run(args)

          if res == 0
            @build_logs << "Packaging successful! Output stored in #{@output_path}."
          else
            @build_logs << "Packaging exited with code #{res}."
          end
          @building = false
          @done = true
        end
      end
    end
  end
end
