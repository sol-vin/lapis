# =============================================================================
# LibGodot - Crystal Editor Integration Main Screen Panel
# =============================================================================
# 100% Pure Crystal Node implementing the "Crystal" main dock tab.
# Provides build controls, recompilable addon management, Crystal log output,
# and an interactive unit test runner hooking into Crystal's spec framework.

require "../lapis"

module Godot
  @[Tool]
  node CrystalPanel < Control do
    property auto_recompile_addons : Bool = true

    @@instance : CrystalPanel? = nil
    @log_output : RichTextLabel? = nil
    @test_tree : Tree? = nil
    @addon_tree : Tree? = nil
    @status_badge : Label? = nil
    @test_status_label : Label? = nil
    @test_details : RichTextLabel? = nil

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
      @@instance = self
    end

    def self.instance : CrystalPanel?
      @@instance
    end

    def _ready : Void
      call("set_anchors_preset", 15) # PRESET_FULL_RECT
      call("set_h_size_flags", 3)     # SIZE_EXPAND_FILL
      call("set_v_size_flags", 3)     # SIZE_EXPAND_FILL

      setup_ui
      log_info("LibGodot Crystal Hub initialized.")
      refresh_addons_list
      refresh_spec_list
    end

    # =========================================================================
    # UI Layout Construction
    # =========================================================================

    def setup_ui : Void
      # Margin wrapper
      margin = Godot.create(Godot::MarginContainer)
      return unless margin
      margin.call("set_anchors_preset", 15)
      margin.call("set_h_size_flags", 3)
      margin.call("set_v_size_flags", 3)
      margin.call("add_theme_constant_override", "margin_left", 14)
      margin.call("add_theme_constant_override", "margin_top", 12)
      margin.call("add_theme_constant_override", "margin_right", 14)
      margin.call("add_theme_constant_override", "margin_bottom", 12)
      call("add_child", margin)

      root_vbox = Godot.create(Godot::VBoxContainer)
      return unless root_vbox
      root_vbox.call("set_h_size_flags", 3)
      root_vbox.call("set_v_size_flags", 3)
      root_vbox.call("add_theme_constant_override", "separation", 10)
      margin.call("add_child", root_vbox)

      # --- Top Header ---
      header_box = Godot.create(Godot::HBoxContainer)
      if header_box
        header_box.call("add_theme_constant_override", "separation", 12)

        # Title Label
        title = Godot.create(Godot::Label)
        if title
          title.call("set_text", "Crystal Engine Hub")
          title.call("add_theme_font_size_override", "font_size", 18)
          title.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          header_box.call("add_child", title)
        end

        # Status badge
        badge = Godot.create(Godot::Label)
        if badge
          badge.call("set_text", "LibGodot v#{::Godot::VERSION}")
          badge.call("add_theme_color_override", "font_color", Color.new(0.4_f32, 0.85_f32, 1.0_f32, 1.0_f32))
          header_box.call("add_child", badge)
          @status_badge = badge
        end

        # Spacer
        spacer = Godot.create(Godot::Control)
        if spacer
          spacer.call("set_h_size_flags", 3)
          header_box.call("add_child", spacer)
        end

        # Quick Build Game Button
        btn_quick_build = Godot.create(Godot::Button)
        if btn_quick_build
          btn_quick_build.call("set_text", "Build Game (Debug)")
          btn_quick_build.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) { on_build_game(false) }
          header_box.call("add_child", btn_quick_build)
        end

        # Quick Release Build Button
        btn_quick_release = Godot.create(Godot::Button)
        if btn_quick_release
          btn_quick_release.call("set_text", "Build Game (Release)")
          btn_quick_release.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) { on_build_game(true) }
          header_box.call("add_child", btn_quick_release)
        end

        # Quick Run Specs Button
        btn_quick_specs = Godot.create(Godot::Button)
        if btn_quick_specs
          btn_quick_specs.call("set_text", "Run Specs")
          btn_quick_specs.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) { on_run_all_specs }
          header_box.call("add_child", btn_quick_specs)
        end

        [btn_quick_build, btn_quick_release, btn_quick_specs].each do |btn|
          next unless btn
          btn.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_hover_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_pressed_color", Color.new(0.9_f32, 0.9_f32, 1.0_f32, 1.0_f32))
        end

        root_vbox.call("add_child", header_box)
      end

      # Separator
      sep = Godot.create(Godot::HSeparator)
      root_vbox.call("add_child", sep) if sep

      # --- Main Tabs ---
      tabs = Godot.create(Godot::TabContainer)
      return unless tabs
      tabs.call("set_h_size_flags", 3)
      tabs.call("set_v_size_flags", 3)
      tabs.call("add_theme_color_override", "font_selected_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
      tabs.call("add_theme_color_override", "font_unselected_color", Color.new(0.85_f32, 0.9_f32, 1.0_f32, 1.0_f32))
      tabs.call("add_theme_color_override", "font_hovered_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))

      create_build_tab(tabs)
      create_addons_tab(tabs)
      create_test_runner_tab(tabs)
      create_log_tab(tabs)

      root_vbox.call("add_child", tabs)
    end

    # --- Tab 1: Build & Project Management ---
    def create_build_tab(tabs : Node) : Void
      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "Build & Project")
      vbox.call("add_theme_constant_override", "separation", 14)

      # Project Info Panel
      info_group = Godot.create(Godot::VBoxContainer)
      if info_group
        info_group.call("add_theme_constant_override", "separation", 6)
        lbl_header = Godot.create(Godot::Label)
        if lbl_header
          lbl_header.call("set_text", "Target Project Configuration:")
          lbl_header.call("add_theme_font_size_override", "font_size", 14)
          lbl_header.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          info_group.call("add_child", lbl_header)
        end

        lbl_entry = Godot.create(Godot::Label)
        if lbl_entry
          lbl_entry.call("set_text", "  Entry Point: #{detect_project_entry}")
          lbl_entry.call("add_theme_color_override", "font_color", Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
          info_group.call("add_child", lbl_entry)
        end

        lbl_out = Godot.create(Godot::Label)
        if lbl_out
          lbl_out.call("set_text", "  Target Library: bin/game.#{library_extension}")
          lbl_out.call("add_theme_color_override", "font_color", Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
          info_group.call("add_child", lbl_out)
        end

        vbox.call("add_child", info_group)
      end

      # Build Actions Row
      btn_row = Godot.create(Godot::HBoxContainer)
      if btn_row
        btn_row.call("add_theme_constant_override", "separation", 10)

        btn_build_debug = Godot.create(Godot::Button)
        if btn_build_debug
          btn_build_debug.call("set_text", "Build Game (Debug)")
          btn_build_debug.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) { on_build_game(false) }
          btn_row.call("add_child", btn_build_debug)
        end

        btn_build_rel = Godot.create(Godot::Button)
        if btn_build_rel
          btn_build_rel.call("set_text", "Build Game (Release -O3)")
          btn_build_rel.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) { on_build_game(true) }
          btn_row.call("add_child", btn_build_rel)
        end

        btn_pkg = Godot.create(Godot::Button)
        if btn_pkg
          btn_pkg.call("set_text", "Package Standalone Game")
          btn_pkg.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) { on_package_game }
          btn_row.call("add_child", btn_pkg)
        end

        btn_clean = Godot.create(Godot::Button)
        if btn_clean
          btn_clean.call("set_text", "Clean Artifacts")
          btn_clean.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) { on_clean_build }
          btn_row.call("add_child", btn_clean)
        end

        btn_reload = Godot.create(Godot::Button)
        if btn_reload
          btn_reload.call("set_text", "Reload GDExtensions")
          btn_reload.connect("pressed", flags: ::Godot::ConnectFlags::Deferred) { on_reload_extensions }
          btn_row.call("add_child", btn_reload)
        end

        [btn_build_debug, btn_build_rel, btn_pkg, btn_clean, btn_reload].each do |btn|
          next unless btn
          btn.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_hover_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_pressed_color", Color.new(0.9_f32, 0.9_f32, 1.0_f32, 1.0_f32))
        end

        vbox.call("add_child", btn_row)
      end

      # Options
      chk_auto = Godot.create(Godot::CheckBox)
      if chk_auto
        chk_auto.call("set_text", "Auto-recompile modified Crystal addons when building or running (F5)")
        chk_auto.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        chk_auto.call("add_theme_color_override", "font_pressed_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        chk_auto.call("add_theme_color_override", "font_hover_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        chk_auto.call("add_theme_color_override", "font_hover_pressed_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        chk_auto.call("add_theme_color_override", "font_focus_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        chk_auto.call("set_pressed", @auto_recompile_addons)
        chk_auto.connect("toggled") do |_args|
          @auto_recompile_addons = chk_auto.call_bool("is_pressed")
        end
        vbox.call("add_child", chk_auto)
      end

      tabs.call("add_child", vbox)
    end

    # --- Tab 2: Addon Manager ---
    def create_addons_tab(tabs : Node) : Void
      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "Addon Manager")
      vbox.call("add_theme_constant_override", "separation", 10)

      # Top toolbar for addons
      top_row = Godot.create(Godot::HBoxContainer)
      if top_row
        top_row.call("add_theme_constant_override", "separation", 10)

        lbl = Godot.create(Godot::Label)
        if lbl
          lbl.call("set_text", "Auto-Detected Crystal Addons in res://addons:")
          lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          top_row.call("add_child", lbl)
        end

        spacer = Godot.create(Godot::Control)
        spacer.call("set_h_size_flags", 3) if spacer
        top_row.call("add_child", spacer) if spacer

        btn_recompile_all = Godot.create(Godot::Button)
        if btn_recompile_all
          btn_recompile_all.call("set_text", "Recompile All Addons")
          btn_recompile_all.connect("pressed") { on_recompile_all_addons }
          top_row.call("add_child", btn_recompile_all)
        end

        btn_refresh = Godot.create(Godot::Button)
        if btn_refresh
          btn_refresh.call("set_text", "Scan Addons")
          btn_refresh.connect("pressed") { refresh_addons_list }
          top_row.call("add_child", btn_refresh)
        end

        [btn_recompile_all, btn_refresh].each do |btn|
          next unless btn
          btn.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_hover_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_pressed_color", Color.new(0.9_f32, 0.9_f32, 1.0_f32, 1.0_f32))
        end

        vbox.call("add_child", top_row)
      end

      # Tree view for addons
      tree = Godot.create(Godot::Tree)
      if tree
        tree.call("set_h_size_flags", 3)
        tree.call("set_v_size_flags", 3)
        tree.call("set_columns", 4)
        tree.call("set_column_title", 0, "Addon Name")
        tree.call("set_column_title", 1, "Target Type")
        tree.call("set_column_title", 2, "Binary Status")
        tree.call("set_column_title", 3, "Action")
        tree.call("set_column_titles_visible", true)
        tree.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        tree.call("add_theme_color_override", "title_button_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        @addon_tree = tree
        vbox.call("add_child", tree)
      end

      tabs.call("add_child", vbox)
    end

    # --- Tab 3: Crystal Unit Test Runner ---
    def create_test_runner_tab(tabs : Node) : Void
      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "Unit Test Runner")
      vbox.call("add_theme_constant_override", "separation", 10)

      # Test Controls
      ctrl_row = Godot.create(Godot::HBoxContainer)
      if ctrl_row
        ctrl_row.call("add_theme_constant_override", "separation", 10)

        btn_run_all = Godot.create(Godot::Button)
        if btn_run_all
          btn_run_all.call("set_text", "▶ Run All Specs")
          btn_run_all.connect("pressed") { on_run_all_specs }
          ctrl_row.call("add_child", btn_run_all)
        end

        btn_run_sel = Godot.create(Godot::Button)
        if btn_run_sel
          btn_run_sel.call("set_text", "Run Selected Spec")
          btn_run_sel.connect("pressed") { on_run_selected_spec }
          ctrl_row.call("add_child", btn_run_sel)
        end

        btn_refresh = Godot.create(Godot::Button)
        if btn_refresh
          btn_refresh.call("set_text", "Refresh Specs")
          btn_refresh.connect("pressed") { refresh_spec_list }
          ctrl_row.call("add_child", btn_refresh)
        end

        [btn_run_all, btn_run_sel, btn_refresh].each do |btn|
          next unless btn
          btn.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_hover_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_pressed_color", Color.new(0.9_f32, 0.9_f32, 1.0_f32, 1.0_f32))
        end

        lbl_summary = Godot.create(Godot::Label)
        if lbl_summary
          lbl_summary.call("set_text", "Ready to execute Crystal unit specs.")
          lbl_summary.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          @test_status_label = lbl_summary
          ctrl_row.call("add_child", lbl_summary)
        end

        vbox.call("add_child", ctrl_row)
      end

      # Split container: Test Tree on top/left, Details below
      split = Godot.create(Godot::VSplitContainer)
      if split
        split.call("set_h_size_flags", 3)
        split.call("set_v_size_flags", 3)

        # Spec Tree
        tree = Godot.create(Godot::Tree)
        if tree
          tree.call("set_h_size_flags", 3)
          tree.call("set_v_size_flags", 3)
          tree.call("set_columns", 3)
          tree.call("set_column_title", 0, "Specification Suite / Example")
          tree.call("set_column_title", 1, "Status")
          tree.call("set_column_title", 2, "Source Location")
          tree.call("set_column_titles_visible", true)
          tree.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          tree.call("add_theme_color_override", "title_button_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          tree.connect("item_activated") { on_run_selected_spec }
          @test_tree = tree
          split.call("add_child", tree)
        end

        # Test Details Output
        details = Godot.create(Godot::RichTextLabel)
        if details
          details.call("set_h_size_flags", 3)
          details.call("set_v_size_flags", 3)
          details.call("set_use_bbcode", true)
          details.call("set_selection_enabled", true)
          details.call("add_theme_color_override", "default_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          details.call("set_text", "[color=#b0c4de]Select a test or run specs to view assertion details and stack traces.[/color]")
          @test_details = details
          split.call("add_child", details)
        end

        vbox.call("add_child", split)
      end

      tabs.call("add_child", vbox)
    end

    # --- Tab 4: Crystal Log ---
    def create_log_tab(tabs : Node) : Void
      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "Crystal Log")
      vbox.call("add_theme_constant_override", "separation", 8)

      bar = Godot.create(Godot::HBoxContainer)
      if bar
        bar.call("add_theme_constant_override", "separation", 10)

        btn_clear = Godot.create(Godot::Button)
        if btn_clear
          btn_clear.call("set_text", "Clear Log")
          btn_clear.connect("pressed") { clear_log }
          bar.call("add_child", btn_clear)
        end

        btn_copy = Godot.create(Godot::Button)
        if btn_copy
          btn_copy.call("set_text", "Copy Log")
          btn_copy.connect("pressed") do
            if log = @log_output
              text = log.call_str("get_parsed_text")
              Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr).call("clipboard_set", text) unless text.empty?
            end
          end
          bar.call("add_child", btn_copy)
        end

        [btn_clear, btn_copy].each do |btn|
          next unless btn
          btn.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_hover_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_pressed_color", Color.new(0.9_f32, 0.9_f32, 1.0_f32, 1.0_f32))
        end

        vbox.call("add_child", bar)
      end

      log_box = Godot.create(Godot::RichTextLabel)
      if log_box
        log_box.call("set_h_size_flags", 3)
        log_box.call("set_v_size_flags", 3)
        log_box.call("set_use_bbcode", true)
        log_box.call("set_scroll_follow", true)
        log_box.call("set_selection_enabled", true)
        log_box.call("add_theme_color_override", "default_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        @log_output = log_box
        vbox.call("add_child", log_box)
      end

      tabs.call("add_child", vbox)
    end

    # =========================================================================
    # Logging Utilities
    # =========================================================================

    def log_info(msg : String) : Void
      append_log("[color=#66ccff][INFO][/color] [color=#ffffff]#{msg}[/color]")
      Godot.print("[CrystalHub] #{msg}")
    end

    def log_success(msg : String) : Void
      append_log("[color=#44ff88][SUCCESS][/color] [color=#ffffff]#{msg}[/color]")
      Godot.print("[CrystalHub] #{msg}")
    end

    def log_warn(msg : String) : Void
      append_log("[color=#ffbb33][WARN][/color] [color=#ffffff]#{msg}[/color]")
      Godot.print("[CrystalHub] #{msg}")
    end

    def log_error(msg : String) : Void
      append_log("[color=#ff4444][ERROR][/color] [color=#ff8888]#{msg}[/color]")
      Godot.printerr("[CrystalHub] #{msg}")
    end

    def append_log(line : String) : Void
      if log = @log_output
        if line.includes?("[color=")
          log.call("append_text", "#{line}\n")
        else
          log.call("append_text", "[color=#ffffff]#{line}[/color]\n")
        end
      end
    end

    def clear_log : Void
      if log = @log_output
        log.call("clear")
      end
    end

    # =========================================================================
    # Build & Project Operations
    # =========================================================================

    def on_build_game(is_release : Bool) : Void
      log_info("Starting Crystal build (#{is_release ? "Release -O3" : "Debug"})...")

      # Recompile any modified addons first if option enabled
      if @auto_recompile_addons
        recompile_modified_addons_silent
      end

      entry = detect_project_entry
      out_lib = "bin/game.#{library_extension}"
      link_flags = library_link_flags

      args = ["build", "--link-flags", link_flags]
      if is_release
        args << "--release"
      else
        args << "--single-module"
      end
      args << entry
      args << "-o"
      args << out_lib

      out_dir = File.dirname(out_lib)
      Dir.mkdir_p(out_dir) unless Dir.exists?(out_dir)

      compiler_env = CrystalIntegrationPlugin.build_compiler_env
      log_info("Executing: crystal #{args.join(" ")}")
      output_io = IO::Memory.new
      status = Process.run("crystal", args, env: compiler_env, output: output_io, error: output_io)
      output_str = output_io.to_s.strip

      if !output_str.empty?
        output_str.each_line do |l|
          if l.includes?("error") || l.includes?("Error")
            log_error("  #{l}")
          else
            append_log("  [color=#ffffff]#{l}[/color]")
          end
        end
      end

      if status.success?
        log_success("Game library built successfully -> #{out_lib}")
        # Sync to root bin if in subfolder
        if File.directory?("../bin")
          begin
            File.copy(out_lib, "../bin/#{File.basename(out_lib)}")
            log_info("Synced binary to workspace root: ../bin/#{File.basename(out_lib)}")
          rescue
          end
        end
        addon_bin_target = "addons/crystal_integration/bin/#{File.basename(out_lib)}"
        if File.directory?("addons/crystal_integration/bin")
          begin
            File.copy(out_lib, addon_bin_target)
            log_info("Synced binary to addon: #{addon_bin_target}")
          rescue
          end
        end
        on_reload_extensions
      else
        log_error("Crystal build failed with exit code #{status.exit_code}.")
        CrystalIntegrationPlugin.report_build_failure("Crystal build", output_str, output_str, status.exit_code)
      end
    rescue ex
      log_error("Error during build: #{ex.message}")
      CrystalIntegrationPlugin.report_build_failure("Crystal build", "", "Error during build: #{ex.message}", 1)
    end

    def on_package_game : Void
      log_info("Packaging standalone game executable...")
      lapis_candidates = [
        "bin/lapis.exe", "bin/lapis",
        "../bin/lapis.exe", "../bin/lapis",
        "../../bin/lapis.exe", "../../bin/lapis"
      ]
      lapis_bin = lapis_candidates.find { |p| File.exists?(p) } || Process.find_executable("lapis")
      if !lapis_bin
        log_error("lapis toolchain not found.")
        return
      end

      output_io = IO::Memory.new
      status = Process.run(File.expand_path(lapis_bin), ["package", "game", "-p", ".", "-f"], output: output_io, error: output_io)
      output_io.to_s.each_line { |l| append_log("  #{l}") }

      if status.success?
        log_success("Standalone package generated successfully!")
      else
        log_error("Packaging exited with code #{status.exit_code}.")
      end
    rescue ex
      log_error("Failed to package game: #{ex.message}")
    end

    def on_clean_build : Void
      log_info("Cleaning build artifacts...")
      ["bin/game.dll", "bin/game.so", "bin/game.dylib", "bin/game.exe", "bin/game"].each do |f|
        File.delete(f) if File.exists?(f)
      end
      log_success("Clean completed.")
    end

    def on_reload_extensions : Void
      if Godot::CrystalIntegrationPlugin.building? || Godot::CrystalIntegrationPlugin.reload_pending?
        log_info("Build or reload already in progress, skipping duplicate request.")
        return
      end
      gd_ext_mgr = Godot::GDExtensionManager.new(Godot::GDExtensionManager.singleton_ptr)
      ext_path = "res://addons/crystal_integration/crystal.gdextension"
      if gd_ext_mgr.is_extension_loaded(ext_path)
        Godot::CrystalIntegrationPlugin.reload_pending = true
        gd_ext_mgr.call_deferred("reload_extension", ext_path)
        log_info("Scheduled deferred GDExtension reload.")
      else
        log_info("GDExtension not dynamically reloadable or loaded under another path.")
      end
    rescue ex
      log_warn("GDExtension reload notice: #{ex.message}")
    end

    # =========================================================================
    # Addon Detection & Recompilation
    # =========================================================================

    def refresh_addons_list : Void
      tree = @addon_tree
      return unless tree
      tree.call("clear")

      root = tree.call_obj("create_item")
      return unless root

      addons_path = "addons"
      addons_path = "../addons" unless Dir.exists?(addons_path)
      return unless Dir.exists?(addons_path)

      Dir.children(addons_path).each do |entry|
        next if entry == "crystal_integration"
        full_dir = File.join(addons_path, entry)
        next unless Dir.exists?(full_dir)

        # Check if it has Crystal source or recompilable target
        main_cr = File.join(full_dir, "src", "main.cr")
        has_src = File.exists?(main_cr)
        has_makefile = File.exists?(File.join(full_dir, "Makefile"))
        is_recompilable = has_src || has_makefile

        # Check for binaries
        bin_dir = File.join(full_dir, "bin")
        bin_files = Dir.exists?(bin_dir) ? Dir.children(bin_dir).select { |f| f.ends_with?(".dll") || f.ends_with?(".so") || f.ends_with?(".dylib") } : [] of String
        bin_files.reject! { |f| f.starts_with?("crystal_bridge") || ["gc.dll", "iconv-2.dll", "pcre2-8.dll", "libgodot.dll"].includes?(f) }

        item = tree.call_obj("create_item", root)
        next unless item

        item.call("set_text", 0, entry)
        item.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        if is_recompilable
          item.call("set_text", 1, "Recompilable (Source found)")
          item.call("set_custom_color", 1, Color.new(0.4_f32, 1.0_f32, 0.5_f32, 1.0_f32))

          # Check if modified
          if bin_files.empty?
            item.call("set_text", 2, "Missing Binary (Needs compile)")
            item.call("set_custom_color", 2, Color.new(1.0_f32, 0.4_f32, 0.4_f32, 1.0_f32))
          else
            bin_time = File.info(File.join(bin_dir, bin_files[0])).modification_time
            src_time = File.info(main_cr).modification_time
            if src_time > bin_time
              item.call("set_text", 2, "Source Modified (Needs recompile)")
              item.call("set_custom_color", 2, Color.new(1.0_f32, 0.8_f32, 0.2_f32, 1.0_f32))
            else
              item.call("set_text", 2, "Up-to-date (#{bin_files[0]})")
              item.call("set_custom_color", 2, Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
            end
          end
          item.call("set_text", 3, "Recompile")
          item.call("set_custom_color", 3, Color.new(0.5_f32, 0.9_f32, 1.0_f32, 1.0_f32))
        else
          item.call("set_text", 1, "Precompiled Binary Only")
          item.call("set_custom_color", 1, Color.new(0.7_f32, 0.7_f32, 1.0_f32, 1.0_f32))
          item.call("set_text", 2, bin_files.empty? ? "No binary found" : "Binary plugin (#{bin_files[0]})")
          item.call("set_custom_color", 2, Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
          item.call("set_text", 3, "Non-Recompilable")
          item.call("set_custom_color", 3, Color.new(0.8_f32, 0.8_f32, 0.8_f32, 1.0_f32))
        end
      end
    rescue ex
      log_error("Error scanning addons: #{ex.message}")
    end

    def on_recompile_all_addons : Void
      log_info("Recompiling all recompilable addons...")
      lapis_candidates = [
        "bin/lapis.exe", "bin/lapis",
        "../bin/lapis.exe", "../bin/lapis",
        "../../bin/lapis.exe", "../../bin/lapis"
      ]
      lapis_bin = lapis_candidates.find { |p| File.exists?(p) } || Process.find_executable("lapis")
      if !lapis_bin
        log_error("lapis toolchain not found.")
        return
      end

      output_io = IO::Memory.new
      status = Process.run(File.expand_path(lapis_bin), ["build", "addons"], output: output_io, error: output_io)
      output_io.to_s.each_line { |l| append_log("  #{l}") }

      if status.success?
        log_success("Addon recompilation finished cleanly.")
        refresh_addons_list
        on_reload_extensions
      else
        log_error("Addon recompilation exited with code #{status.exit_code}.")
      end
    rescue ex
      log_error("Failed to recompile addons: #{ex.message}")
    end

    def recompile_modified_addons_silent : Void
      lapis_candidates = [
        "bin/lapis.exe", "bin/lapis",
        "../bin/lapis.exe", "../bin/lapis",
        "../../bin/lapis.exe", "../../bin/lapis"
      ]
      lapis_bin = lapis_candidates.find { |p| File.exists?(p) } || Process.find_executable("lapis")
      return unless lapis_bin

      output_io = IO::Memory.new
      Process.run(File.expand_path(lapis_bin), ["build", "addons"], output: output_io, error: output_io)
    rescue
    end

    # =========================================================================
    # Crystal Unit Test Runner
    # =========================================================================

    def resolve_spec_context : Tuple(String, String)
      # 1. First priority: Check ProjectSettings for res://spec (the open project's spec folder)
      if !Godot::ProjectSettings.singleton_ptr.null?
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        res_spec = ps.call_str("globalize_path", "res://spec").gsub('\\', '/')
        res_root = ps.call_str("globalize_path", "res://").gsub('\\', '/')
        if !res_spec.empty? && Dir.exists?(res_spec)
          return {res_spec, res_root.rstrip('/')}
        end
      end

      # 2. Candidate directories relative to current working directory
      if Dir.exists?("spec")
        {File.expand_path("spec").gsub('\\', '/'), File.expand_path(".").gsub('\\', '/')}
      elsif Dir.exists?("../spec")
        {File.expand_path("../spec").gsub('\\', '/'), File.expand_path("..").gsub('\\', '/')}
      else
        {"spec", "."}
      end
    end

    def relative_source_location(path : String, cwd : String) : String
      norm_path = path.gsub('\\', '/')
      norm_cwd = cwd.gsub('\\', '/').rstrip('/')

      if norm_path.downcase.starts_with?("#{norm_cwd.downcase}/")
        norm_path[(norm_cwd.size + 1)..]
      else
        begin
          Path[norm_path].relative_to(Path[norm_cwd]).to_s.gsub('\\', '/')
        rescue
          norm_path
        end
      end
    end

    def refresh_spec_list : Void
      tree = @test_tree
      return unless tree
      tree.call("clear")

      root = tree.call_obj("create_item")
      return unless root
      root.call("set_text", 0, "Crystal Specifications")
      root.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
      root.call("set_text", 1, "[⚪ Idle]")
      root.call("set_custom_color", 1, Color.new(0.9_f32, 0.9_f32, 0.9_f32, 1.0_f32))

      spec_dir, cwd = resolve_spec_context
      return unless Dir.exists?(spec_dir)

      # Use Dir.children to avoid Windows path separator / escape issues with Dir.glob
      spec_files = Dir.children(spec_dir)
        .select { |f| f.ends_with?("_spec.cr") }
        .sort
        .map { |f| File.join(spec_dir, f).gsub('\\', '/') }

      total_specs = 0
      spec_files.each do |f|
        file_name = File.basename(f)
        file_item = tree.call_obj("create_item", root)
        next unless file_item

        rel_file = relative_source_location(f, cwd)

        file_item.call("set_text", 0, file_name)
        file_item.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        file_item.call("set_text", 1, "[⚪ Idle]")
        file_item.call("set_custom_color", 1, Color.new(0.9_f32, 0.9_f32, 0.9_f32, 1.0_f32))
        file_item.call("set_text", 2, rel_file)
        file_item.call("set_custom_color", 2, Color.new(0.6_f32, 0.85_f32, 1.0_f32, 1.0_f32))
        file_item.call("set_collapsed", false)

        current_desc_item : Node? = nil

        # Parse describe/context/it or [Spec X] inside file
        begin
          line_num = 0
          File.each_line(f) do |line|
            line_num += 1
            stripped = line.strip
            if stripped =~ /^(describe|context)(\s+|\()/
              desc_text = stripped.sub(/^(describe|context)\s*\(?\s*/, "").sub(/\s*\)?\s*\bdo\b.*$/, "").strip("\"'")
              desc_item = tree.call_obj("create_item", file_item)
              if desc_item
                desc_item.call("set_text", 0, desc_text)
                desc_item.call("set_custom_color", 0, Color.new(0.95_f32, 0.95_f32, 1.0_f32, 1.0_f32))
                desc_item.call("set_text", 1, "[⚪ Idle]")
                desc_item.call("set_custom_color", 1, Color.new(0.9_f32, 0.9_f32, 0.9_f32, 1.0_f32))
                desc_item.call("set_text", 2, "#{rel_file}:#{line_num}")
                desc_item.call("set_custom_color", 2, Color.new(0.6_f32, 0.85_f32, 1.0_f32, 1.0_f32))
                desc_item.call("set_collapsed", false)
                current_desc_item = desc_item
              end
            elsif stripped =~ /^(it|pending)(\s+|\()/
              it_text = stripped.sub(/^(it|pending)\s*\(?\s*["']?/, "").sub(/["']?\s*\)?\s*(do|\{).*$/, "").strip("\"'")
              parent_target = current_desc_item || file_item
              it_item = tree.call_obj("create_item", parent_target)
              if it_item
                it_item.call("set_text", 0, "  • #{it_text}")
                it_item.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
                it_item.call("set_text", 1, "[⚪ Idle]")
                it_item.call("set_custom_color", 1, Color.new(0.9_f32, 0.9_f32, 0.9_f32, 1.0_f32))
                it_item.call("set_text", 2, "#{rel_file}:#{line_num}")
                it_item.call("set_custom_color", 2, Color.new(0.6_f32, 0.85_f32, 1.0_f32, 1.0_f32))
                total_specs += 1
              end
            elsif stripped =~ /^\[Spec\s+\d+\]/
              spec_text = stripped.gsub(/^\[Spec\s+\d+\]\s*/, "")
              it_item = tree.call_obj("create_item", file_item)
              if it_item
                it_item.call("set_text", 0, "  • #{spec_text}")
                it_item.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
                it_item.call("set_text", 1, "[⚪ Idle]")
                it_item.call("set_custom_color", 1, Color.new(0.9_f32, 0.9_f32, 0.9_f32, 1.0_f32))
                it_item.call("set_text", 2, "#{rel_file}:#{line_num}")
                it_item.call("set_custom_color", 2, Color.new(0.6_f32, 0.85_f32, 1.0_f32, 1.0_f32))
                total_specs += 1
              end
            end
          end
        rescue ex
          log_error("Error parsing spec file #{f}: #{ex.message}")
        end

        file_item.call("set_collapsed", false)
      end

      if lbl = @test_status_label
        lbl.call("set_text", "Discovered #{spec_files.size} spec files (#{total_specs} test cases). Ready to run.")
        lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
      end
    end

    def update_tree_item_status_recursive(item : Node, status_str : String, status_col : Color) : Void
      item.call("set_text", 1, status_str)
      item.call("set_custom_color", 1, status_col)
      child = item.call_obj("get_first_child")
      while child && !child.pointer.null?
        update_tree_item_status_recursive(child, status_str, status_col)
        child = child.call_obj("get_next")
      end
    end

    def on_run_all_specs : Void
      log_info("Executing Crystal unit test specifications...")
      if lbl = @test_status_label
        lbl.call("set_text", "Running crystal spec in background...")
        lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 0.85_f32, 0.2_f32, 1.0_f32))
      end

      # Mark all items as running
      if tree = @test_tree
        if root = tree.call_obj("get_root")
          update_tree_item_status_recursive(root, "[⏳ Running...]", Color.new(1.0_f32, 0.85_f32, 0.2_f32, 1.0_f32))
        end
      end

      spec_dir, cwd = resolve_spec_context

      output_io = IO::Memory.new
      start_time = ::Time.instant
      status = Process.run("crystal", ["spec", "--no-color"], chdir: cwd, output: output_io, error: output_io)
      elapsed = (::Time.instant - start_time).total_seconds.round(2)
      output_text = output_io.to_s

      # Log full output in white
      output_text.each_line { |l| append_log("  [color=#ffffff]#{l}[/color]") }

      passed = status.success?
      if details = @test_details
        if passed
          details.call("set_text", "[color=#44ff88][b]All Crystal specifications passed successfully![/b][/color]\n[color=#ffffff]Execution Time: #{elapsed}s[/color]\n\n[color=#f5f5f5]#{output_text}[/color]")
        else
          details.call("set_text", "[color=#ff4444][b]Specification Failures Detected:[/b][/color]\n[color=#ffffff]Execution Time: #{elapsed}s[/color]\n\n[color=#ff8888]#{output_text}[/color]")
        end
      end

      if tree = @test_tree
        if root = tree.call_obj("get_root")
          status_str = passed ? "[✅ PASSED]" : "[❌ FAILED]"
          status_col = passed ? Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32) : Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32)
          update_tree_item_status_recursive(root, status_str, status_col)
        end
      end

      if lbl = @test_status_label
        if passed
          lbl.call("set_text", "✅ All specifications passed cleanly in #{elapsed}s!")
          lbl.call("add_theme_color_override", "font_color", Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32))
          log_success("All specifications passed cleanly in #{elapsed}s!")
        else
          lbl.call("set_text", "❌ Failures detected in #{elapsed}s. See details below.")
          lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32))
          log_error("Specification failures detected in #{elapsed}s.")
        end
      end
    rescue ex
      log_error("Error running specs: #{ex.message}")
    end

    def on_run_selected_spec : Void
      tree = @test_tree
      return unless tree
      selected = tree.call_obj("get_selected")
      if !selected || selected.pointer.null?
        on_run_all_specs
        return
      end

      path = selected.call_str("get_text", 2)
      if path.empty?
        on_run_all_specs
        return
      end

      spec_dir, cwd = resolve_spec_context

      log_info("Running selected specification: #{path}...")
      update_tree_item_status_recursive(selected, "[⏳ Running...]", Color.new(1.0_f32, 0.85_f32, 0.2_f32, 1.0_f32))
      output_io = IO::Memory.new
      start_time = ::Time.instant
      status = Process.run("crystal", ["spec", path, "--no-color"], chdir: cwd, output: output_io, error: output_io)
      elapsed = (::Time.instant - start_time).total_seconds.round(2)
      output_text = output_io.to_s
      output_text.each_line { |l| append_log("  [color=#ffffff]#{l}[/color]") }

      passed = status.success?
      status_str = passed ? "[✅ PASSED]" : "[❌ FAILED]"
      status_col = passed ? Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32) : Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32)
      update_tree_item_status_recursive(selected, status_str, status_col)

      if details = @test_details
        if passed
          details.call("set_text", "[color=#44ff88][b]Results for #{path} (#{elapsed}s):[/b][/color]\n\n[color=#f5f5f5]#{output_text}[/color]")
        else
          details.call("set_text", "[color=#ff4444][b]Results for #{path} (#{elapsed}s):[/b][/color]\n\n[color=#ff8888]#{output_text}[/color]")
        end
      end
    rescue ex
      log_error("Error running selected spec: #{ex.message}")
    end

    # =========================================================================
    # Helpers
    # =========================================================================

    def detect_project_entry : String
      return "src/main.cr" if File.exists?("src/main.cr")
      if !Godot::ProjectSettings.singleton_ptr.null?
        ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
        global_entry = ps.call_str("globalize_path", "res://src/main.cr").gsub('\\', '/')
        return global_entry if !global_entry.empty? && File.exists?(global_entry)
      end
      "src/main.cr"
    end

    def library_extension : String
      {% if flag?(:windows) %}
        "dll"
      {% elsif flag?(:darwin) %}
        "dylib"
      {% else %}
        "so"
      {% end %}
    end

    def library_link_flags : String
      {% if flag?(:windows) %}
        "/DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init"
      {% elsif flag?(:darwin) %}
        "-dynamiclib"
      {% else %}
        "-shared"
      {% end %}
    end
  end
end

alias CrystalPanel = Godot::CrystalPanel
