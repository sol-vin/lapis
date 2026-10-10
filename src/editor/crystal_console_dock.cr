# =============================================================================
# LibGodot - Crystal Editor Bottom Console Dock
# =============================================================================
# Lightweight bottom panel companion docked alongside Output and Debugger.
# Streams live compilation lines, execution logs, and provides instant build controls
# without forcing developers away from the 2D/3D viewport or Script Editor.
# =============================================================================

require "../lapis"
require "./async_command_runner"
require "./toolchain"

module Lapis
  @[Tool]
  node CrystalConsoleDock < VBoxContainer do
    @status_label : Label? = nil
    @progress_bar : ProgressBar? = nil
    @output_box : RichTextLabel? = nil
    @btn_build_debug : Button? = nil
    @btn_build_release : Button? = nil
    @btn_run_specs : Button? = nil
    @btn_doctor : Button? = nil
    @btn_cancel : Button? = nil

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
      self.name = "CrystalConsoleDock"
      call("set_h_size_flags", 3_i64) # SIZE_EXPAND_FILL
      call("set_v_size_flags", 3_i64) # SIZE_EXPAND_FILL
      call("set_custom_minimum_size", Vector2.new(0_f32, 180_f32))
    end

    def _ready : Void
      setup_ui
      set_status("Ready.", Color.new(0.8_f32, 0.9_f32, 1.0_f32, 1.0_f32))
    end

    def setup_ui : Void
      call("add_theme_constant_override", "separation", 6)

      # --- Top Action Toolbar ---
      toolbar = Godot.create(Godot::HBoxContainer)
      if toolbar
        toolbar.call("add_theme_constant_override", "separation", 8)

        # Status Label
        lbl_status = Godot.create(Godot::Label)
        if lbl_status
          lbl_status.call("set_text", "Ready.")
          lbl_status.call("add_theme_color_override", "font_color", Color.new(0.0_f32, 0.85_f32, 1.0_f32, 1.0_f32))
          toolbar.call("add_child", lbl_status)
          @status_label = lbl_status
        end

        # Spacer
        spacer = Godot.create(Godot::Control)
        if spacer
          spacer.call("set_h_size_flags", 3_i64)
          toolbar.call("add_child", spacer)
        end

        # Build (Debug)
        btn_debug = Godot.create(Godot::Button)
        if btn_debug
          btn_debug.call("set_text", "Build (Debug)")
          btn_debug.connect("pressed") { trigger_build(false) }
          toolbar.call("add_child", btn_debug)
          @btn_build_debug = btn_debug
        end

        # Build (Release)
        btn_rel = Godot.create(Godot::Button)
        if btn_rel
          btn_rel.call("set_text", "Build (Release)")
          btn_rel.connect("pressed") { trigger_build(true) }
          toolbar.call("add_child", btn_rel)
          @btn_build_release = btn_rel
        end

        # Run Specs
        btn_specs = Godot.create(Godot::Button)
        if btn_specs
          btn_specs.call("set_text", "Run Specs")
          btn_specs.connect("pressed") { trigger_specs }
          toolbar.call("add_child", btn_specs)
          @btn_run_specs = btn_specs
        end

        # Doctor
        btn_doc = Godot.create(Godot::Button)
        if btn_doc
          btn_doc.call("set_text", "Doctor")
          btn_doc.connect("pressed") { trigger_doctor }
          toolbar.call("add_child", btn_doc)
          @btn_doctor = btn_doc
        end

        # Cancel
        btn_cancel = Godot.create(Godot::Button)
        if btn_cancel
          btn_cancel.call("set_text", "Cancel")
          btn_cancel.call("set_disabled", true)
          btn_cancel.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 0.4_f32, 0.4_f32, 1.0_f32))
          btn_cancel.connect("pressed") { on_cancel_pressed }
          toolbar.call("add_child", btn_cancel)
          @btn_cancel = btn_cancel
        end

        # Clear
        btn_clear = Godot.create(Godot::Button)
        if btn_clear
          btn_clear.call("set_text", "Clear")
          btn_clear.connect("pressed") { clear_output }
          toolbar.call("add_child", btn_clear)
        end

        # Open Hub Button
        btn_hub = Godot.create(Godot::Button)
        if btn_hub
          btn_hub.call("set_text", "Open Hub")
          btn_hub.connect("pressed") { open_crystal_hub }
          toolbar.call("add_child", btn_hub)
        end

        call("add_child", toolbar)
      end

      # --- Progress Bar ---
      prog = Godot.create(Godot::ProgressBar)
      if prog
        prog.call("set_h_size_flags", 3_i64)
        prog.call("set_custom_minimum_size", Vector2.new(0_f32, 4_f32))
        prog.call("set_show_percentage", false)
        prog.call("set_visible", false)
        call("add_child", prog)
        @progress_bar = prog
      end

      # --- RichTextLabel Terminal Viewport ---
      rtl = Godot.create(Godot::RichTextLabel)
      if rtl
        rtl.call("set_h_size_flags", 3_i64)
        rtl.call("set_v_size_flags", 3_i64)
        rtl.call("set_use_bbcode", true)
        rtl.call("set_scroll_follow", true)
        rtl.call("set_selection_enabled", true)
        rtl.call("add_theme_color_override", "default_color", Color.new(0.92_f32, 0.92_f32, 0.95_f32, 1.0_f32))
        rtl.call("set_text", "[color=#5c6370]LibGodot Crystal Console Ready.[/color]\n")
        call("add_child", rtl)
        @output_box = rtl
      end
    end

    def append_line(text : String) : Void
      if out = @output_box
        formatted = if text.includes?("error") || text.includes?("Error")
                      "[color=#ff6b6b]#{text}[/color]"
                    elsif text.includes?("warning") || text.includes?("Warning")
                      "[color=#ffd166]#{text}[/color]"
                    elsif text.includes?("success") || text.includes?("Success") || text.includes?("PASSED")
                      "[color=#06d6a0]#{text}[/color]"
                    elsif text.starts_with?("==") || text.starts_with?("--")
                      "[color=#00d2ff]#{text}[/color]"
                    else
                      text
                    end
        out.call("append_text", "#{formatted}\n")
      end
    end

    def clear_output : Void
      @output_box.try &.call("clear")
    end

    def set_status(msg : String, color : Color = Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)) : Void
      if lbl = @status_label
        lbl.call("set_text", msg)
        lbl.call("add_theme_color_override", "font_color", color)
      end
    end

    def set_busy(busy : Bool, action_name : String = "") : Void
      @progress_bar.try &.call("set_visible", busy)
      @btn_build_debug.try &.call("set_disabled", busy)
      @btn_build_release.try &.call("set_disabled", busy)
      @btn_run_specs.try &.call("set_disabled", busy)
      @btn_doctor.try &.call("set_disabled", busy)
      @btn_cancel.try &.call("set_disabled", !busy)

      if busy
        set_status("Executing #{action_name}...", Color.new(1.0_f32, 0.85_f32, 0.2_f32, 1.0_f32))
      end
    end

    def on_cancel_pressed : Void
      AsyncCommandRunner.instance.cancel
      append_line("[color=#ff6b6b]Operation cancelled by user.[/color]")
      set_busy(false)
      set_status("Cancelled.", Color.new(1.0_f32, 0.4_f32, 0.4_f32, 1.0_f32))
    end

    def trigger_build(is_release : Bool) : Void
      return if AsyncCommandRunner.instance.running?
      mode_name = is_release ? "Release (-O3)" : "Debug"
      append_line("\n[color=#00d2ff]━━━ Starting Crystal Build (#{mode_name}) ━━━[/color]")
      set_busy(true, "Build (#{mode_name})")

      entry_file = "src/main.cr"
      out_dll = {% if flag?(:windows) %}
                  "bin/game.dll"
                {% elsif flag?(:darwin) %}
                  "bin/game.dylib"
                {% else %}
                  "bin/game.so"
                {% end %}
      link_flags = {% if flag?(:windows) %}
                     "/DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init"
                   {% elsif flag?(:darwin) %}
                     "-dynamiclib"
                   {% else %}
                     "-shared"
                   {% end %}

      lapis_bin = Toolchain.resolve_lapis_bin
      cmd, args = if lapis_bin
                    {lapis_bin, Toolchain.build_game_args(entry_file, out_dll, link_flags, is_release)}
                  else
                    build_args = ["build", "--link-flags", link_flags]
                    build_args << (is_release ? "--release" : "--single-module")
                    build_args += [entry_file, "-o", out_dll]
                    {"crystal", build_args}
                  end

      compiler_env = CrystalIntegrationPlugin.build_compiler_env
      AsyncCommandRunner.instance.set_on_line { |l| append_line(l) }

      AsyncCommandRunner.instance.run("build", cmd, args, env: compiler_env) do |exit_code, elapsed_sec, all_output|
        set_busy(false)
        if exit_code == 0
          set_status("Build succeeded in #{elapsed_sec.round(2)}s!", Color.new(0.2_f32, 0.9_f32, 0.4_f32, 1.0_f32))
          append_line("[color=#06d6a0]Build Succeeded in #{elapsed_sec.round(2)}s! -> #{out_dll}[/color]")
          CrystalIntegrationPlugin.trigger_extension_reload rescue nil
        else
          set_status("Build failed (exit #{exit_code})", Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32))
          append_line("[color=#ff6b6b]Build failed with exit code #{exit_code}.[/color]")
          CrystalIntegrationPlugin.report_build_failure("Build", all_output, "", exit_code) rescue nil
        end
      end
    end

    def trigger_specs : Void
      return if AsyncCommandRunner.instance.running?
      append_line("\n[color=#00d2ff]━━━ Running Crystal Specifications ━━━[/color]")
      set_busy(true, "Specs")

      AsyncCommandRunner.instance.set_on_line { |l| append_line(l) }
      AsyncCommandRunner.instance.run("spec", "crystal", ["spec", "--no-color"]) do |exit_code, elapsed_sec, _all_output|
        set_busy(false)
        if exit_code == 0
          set_status("Specs passed cleanly in #{elapsed_sec.round(2)}s!", Color.new(0.2_f32, 0.9_f32, 0.4_f32, 1.0_f32))
          append_line("[color=#06d6a0]All specifications passed successfully in #{elapsed_sec.round(2)}s![/color]")
        else
          set_status("Specs failed in #{elapsed_sec.round(2)}s", Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32))
          append_line("[color=#ff6b6b]Specification failures detected.[/color]")
        end
      end
    end

    def trigger_doctor : Void
      return if AsyncCommandRunner.instance.running?
      append_line("\n[color=#00d2ff]━━━ Running Lapis Environment Diagnostics ━━━[/color]")
      set_busy(true, "Doctor")

      lapis_bin = Toolchain.resolve_lapis_bin || "lapis"
      AsyncCommandRunner.instance.set_on_line { |l| append_line(l) }
      AsyncCommandRunner.instance.run("doctor", lapis_bin, ["doctor"]) do |exit_code, elapsed_sec, _all_output|
        set_busy(false)
        if exit_code == 0
          set_status("Environment healthy (#{elapsed_sec.round(2)}s)", Color.new(0.2_f32, 0.9_f32, 0.4_f32, 1.0_f32))
        else
          set_status("Doctor warnings detected (#{elapsed_sec.round(2)}s)", Color.new(1.0_f32, 0.8_f32, 0.2_f32, 1.0_f32))
        end
      end
    end

    def open_crystal_hub : Void
      if !Godot::EditorInterface.singleton_ptr.null?
        ei = Godot::EditorInterface.new(Godot::EditorInterface.singleton_ptr)
        ei.set_main_screen_editor("Crystal") rescue nil
      end
    end
  end
end
