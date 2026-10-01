# =============================================================================
# LibGodot - Crystal Editor Integration Main Screen Panel
# =============================================================================
# 100% Pure Crystal Node implementing the "Crystal" main dock tab.
# Provides build controls, recompilable addon management, Crystal log output,
# and an interactive unit test runner hooking into Crystal's spec framework.

require "../lapis"
require "json"

module Lapis
  include Godot

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
    @benchmarks_tree : Tree? = nil
    @benchmarks_status_label : Label? = nil
    @benchmarks_log : RichTextLabel? = nil
    @benchmarks_category_filter : String? = nil
    @benchmarks_iterations_spin : SpinBox? = nil

    # Crystal Log GUI fields
    @log_filter_level : LogLevel? = nil
    @log_filter_channel : String? = nil
    @log_search_query : String = ""
    @log_auto_scroll : Bool = true
    @log_frozen : Bool = false
    @log_context_mode : String = "memory"

    @btn_filter_all : Button? = nil
    @btn_filter_err : Button? = nil
    @btn_filter_warn : Button? = nil
    @btn_filter_info : Button? = nil
    @btn_filter_debug : Button? = nil
    @btn_filter_trace : Button? = nil
    @channel_select : OptionButton? = nil
    @context_select : OptionButton? = nil
    @search_line_edit : LineEdit? = nil
    @btn_auto_scroll : Button? = nil
    @btn_freeze : Button? = nil
    @log_public_only : Bool = false
    @btn_public_only : Button? = nil

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
      @@instance = self
    end

    def self.instance : CrystalPanel?
      @@instance
    end

    def _ready : Void
      call("set_anchors_preset", 15) # PRESET_FULL_RECT
      call("set_h_size_flags", 3)    # SIZE_EXPAND_FILL
      call("set_v_size_flags", 3)    # SIZE_EXPAND_FILL
      call("set_custom_minimum_size", Vector2.new(0_f32, 240_f32))

      setup_ui
      log_info("LibGodot Crystal Hub initialized.")
      refresh_addons_list
      refresh_spec_list
      refresh_benchmarks_list
      refresh_log_view
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
      add_child(margin)

      root_vbox = Godot.create(Godot::VBoxContainer)
      return unless root_vbox
      root_vbox.call("set_h_size_flags", 3)
      root_vbox.call("set_v_size_flags", 3)
      root_vbox.call("add_theme_constant_override", "separation", 10)
      margin.add_child(root_vbox)

      # --- Top Header ---
      header_box = Godot.create(Godot::HBoxContainer)
      if header_box
        header_box.call("add_theme_constant_override", "separation", 12)

        # Title Label
        title = Godot.create(Godot::Label)
        if title
          title.text = "Crystal Engine Hub"
          title.call("add_theme_font_size_override", "font_size", 18)
          title.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          header_box.add_child(title)
        end

        # Status badge
        badge = Godot.create(Godot::Label)
        if badge
          badge.text = "LibGodot v#{::Godot::VERSION}"
          badge.call("add_theme_color_override", "font_color", Color.new(0.4_f32, 0.85_f32, 1.0_f32, 1.0_f32))
          header_box.add_child(badge)
          @status_badge = badge
        end

        # Spacer
        spacer = Godot.create(Godot::Control)
        if spacer
          spacer.call("set_h_size_flags", 3)
          header_box.add_child(spacer)
        end

        # Quick Build Game Button
        btn_quick_build = Godot.create(Godot::Button)
        if btn_quick_build
          btn_quick_build.text = "Build Game (Debug)"
          btn_quick_build.pressed.connect(flags: ::Godot::ConnectFlags::Deferred) { on_build_game(false) }
          header_box.add_child(btn_quick_build)
        end

        # Quick Release Build Button
        btn_quick_release = Godot.create(Godot::Button)
        if btn_quick_release
          btn_quick_release.text = "Build Game (Release)"
          btn_quick_release.pressed.connect(flags: ::Godot::ConnectFlags::Deferred) { on_build_game(true) }
          header_box.add_child(btn_quick_release)
        end

        # Quick Run Specs Button
        btn_quick_specs = Godot.create(Godot::Button)
        if btn_quick_specs
          btn_quick_specs.text = "Run Specs"
          btn_quick_specs.pressed.connect(flags: ::Godot::ConnectFlags::Deferred) { on_run_all_specs }
          header_box.add_child(btn_quick_specs)
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
      create_benchmarks_tab(tabs)
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
        tree.call("set_columns", 6)
        tree.call("set_column_title", 0, "Addon Name")
        tree.call("set_column_title", 1, "Type")
        tree.call("set_column_title", 2, "Status")
        tree.call("set_column_title", 3, "Dependencies")
        tree.call("set_column_title", 4, "Description")
        tree.call("set_column_title", 5, "Action")
        tree.call("set_column_titles_visible", true)
        tree.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        tree.call("add_theme_color_override", "title_button_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        tree.connect("item_activated") { on_recompile_all_addons }
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

        btn_run_editor = Godot.create(Godot::Button)
        if btn_run_editor
          btn_run_editor.call("set_text", "▶ Run In-Editor Tests")
          btn_run_editor.connect("pressed") { on_run_in_editor_tests }
          ctrl_row.call("add_child", btn_run_editor)
        end

        btn_run_sel = Godot.create(Godot::Button)
        if btn_run_sel
          btn_run_sel.call("set_text", "Run Selected Test")
          btn_run_sel.connect("pressed") { on_run_selected_spec }
          ctrl_row.call("add_child", btn_run_sel)
        end

        btn_refresh = Godot.create(Godot::Button)
        if btn_refresh
          btn_refresh.call("set_text", "Refresh Tests")
          btn_refresh.connect("pressed") { refresh_spec_list }
          ctrl_row.call("add_child", btn_refresh)
        end

        [btn_run_all, btn_run_editor, btn_run_sel, btn_refresh].each do |btn|
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

    # --- Tab 4: Benchmarks ---
    def create_benchmarks_tab(tabs : Node) : Void
      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "Benchmarks")
      vbox.call("add_theme_constant_override", "separation", 10)

      ctrl_row = Godot.create(Godot::HBoxContainer)
      if ctrl_row
        ctrl_row.call("add_theme_constant_override", "separation", 10)

        btn_run_all = Godot.create(Godot::Button)
        if btn_run_all
          btn_run_all.call("set_text", "▶ Run All Benchmarks")
          btn_run_all.connect("pressed") { on_run_benchmarks }
          ctrl_row.call("add_child", btn_run_all)
        end

        btn_run_sel = Godot.create(Godot::Button)
        if btn_run_sel
          btn_run_sel.call("set_text", "Run Selected")
          btn_run_sel.connect("pressed") { on_run_selected_benchmark }
          ctrl_row.call("add_child", btn_run_sel)
        end

        # Category / Group Filter Dropdown
        cat_select = Godot.create(Godot::OptionButton)
        if cat_select
          cat_select.call("add_item", "All Categories & Groups")
          cat_select.call("add_item", "Comparison Groups Only")
          cat_select.call("add_item", "Compute")
          cat_select.call("add_item", "EngineCore")
          cat_select.call("add_item", "Toolchain")
          cat_select.call("add_item", "Custom")
          cat_select.connect("item_selected") do |args|
            item_id = args.first?.try(&.as_i64) || 0_i64
            @benchmarks_category_filter = case item_id
                                          when 1 then "groups"
                                          when 2 then "compute"
                                          when 3 then "enginecore"
                                          when 4 then "toolchain"
                                          when 5 then "custom"
                                          else        nil
                                          end
            refresh_benchmarks_list
          end
          ctrl_row.call("add_child", cat_select)
        end

        # Iterations SpinBox
        spin_iter = Godot.create(Godot::SpinBox)
        if spin_iter
          spin_iter.call("set_min", 1.0_f64)
          spin_iter.call("set_max", 10.0_f64)
          spin_iter.call("set_step", 1.0_f64)
          spin_iter.call("set_value", 3.0_f64)
          spin_iter.call("set_prefix", "Iter: ")
          @benchmarks_iterations_spin = spin_iter
          ctrl_row.call("add_child", spin_iter)
        end

        btn_html = Godot.create(Godot::Button)
        if btn_html
          btn_html.call("set_text", "Open HTML Report")
          btn_html.connect("pressed") { on_open_benchmarks_html }
          ctrl_row.call("add_child", btn_html)
        end

        btn_refresh = Godot.create(Godot::Button)
        if btn_refresh
          btn_refresh.call("set_text", "Refresh List")
          btn_refresh.connect("pressed") { refresh_benchmarks_list }
          ctrl_row.call("add_child", btn_refresh)
        end

        [btn_run_all, btn_run_sel, btn_html, btn_refresh].each do |btn|
          next unless btn
          btn.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_hover_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          btn.call("add_theme_color_override", "font_pressed_color", Color.new(0.9_f32, 0.9_f32, 1.0_f32, 1.0_f32))
        end

        lbl_status = Godot.create(Godot::Label)
        if lbl_status
          lbl_status.call("set_text", "Ready to execute Crystal performance benchmarks.")
          lbl_status.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          @benchmarks_status_label = lbl_status
          ctrl_row.call("add_child", lbl_status)
        end

        vbox.call("add_child", ctrl_row)
      end

      split = Godot.create(Godot::VSplitContainer)
      if split
        split.call("set_h_size_flags", 3)
        split.call("set_v_size_flags", 3)

        tree = Godot.create(Godot::Tree)
        if tree
          tree.call("set_h_size_flags", 3)
          tree.call("set_v_size_flags", 3)
          tree.call("set_columns", 6)
          tree.call("set_column_title", 0, "Benchmark / Group")
          tree.call("set_column_title", 1, "Category / Target")
          tree.call("set_column_title", 2, "Crystal (Native)")
          tree.call("set_column_title", 3, "GDScript")
          tree.call("set_column_title", 4, "Speedup Ratio")
          tree.call("set_column_title", 5, "Multi-Lang / Custom Metrics")
          tree.call("set_column_titles_visible", true)
          tree.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          tree.call("add_theme_color_override", "title_button_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          tree.connect("item_activated") { on_run_selected_benchmark }
          @benchmarks_tree = tree
          split.call("add_child", tree)
        end

        log_box = Godot.create(Godot::RichTextLabel)
        if log_box
          log_box.call("set_h_size_flags", 3)
          log_box.call("set_v_size_flags", 3)
          log_box.call("set_use_bbcode", true)
          log_box.call("set_selection_enabled", true)
          log_box.call("add_theme_color_override", "default_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          log_box.call("set_text", "[color=#8b949e]Benchmark execution logs, multi-language compiler diagnostics, and throughput metrics will stream here.[/color]")
          @benchmarks_log = log_box
          split.call("add_child", log_box)
        end

        vbox.call("add_child", split)
      end

      tabs.call("add_child", vbox)
    end

    # --- Tab 5: Crystal Log ---
    def create_log_tab(tabs : Node) : Void
      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "Crystal Log")
      vbox.call("add_theme_constant_override", "separation", 8)

      # --- Top Filter Bar: Badges, Context, Channel ---
      filter_bar = Godot.create(Godot::HBoxContainer)
      if filter_bar
        filter_bar.call("add_theme_constant_override", "separation", 8)

        # Filter Pills
        btn_all = Godot.create(Godot::Button)
        if btn_all
          btn_all.call("set_text", "All (0)")
          btn_all.connect("pressed") do
            @log_filter_level = nil
            refresh_log_view
          end
          filter_bar.call("add_child", btn_all)
          @btn_filter_all = btn_all
        end

        btn_err = Godot.create(Godot::Button)
        if btn_err
          btn_err.call("set_text", "Errors (0)")
          btn_err.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 0.35_f32, 0.35_f32, 1.0_f32))
          btn_err.connect("pressed") do
            @log_filter_level = LogLevel::Error
            refresh_log_view
          end
          filter_bar.call("add_child", btn_err)
          @btn_filter_err = btn_err
        end

        btn_warn = Godot.create(Godot::Button)
        if btn_warn
          btn_warn.call("set_text", "Warnings (0)")
          btn_warn.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 0.72_f32, 0.42_f32, 1.0_f32))
          btn_warn.connect("pressed") do
            @log_filter_level = LogLevel::Warn
            refresh_log_view
          end
          filter_bar.call("add_child", btn_warn)
          @btn_filter_warn = btn_warn
        end

        btn_info = Godot.create(Godot::Button)
        if btn_info
          btn_info.call("set_text", "Info (0)")
          btn_info.call("add_theme_color_override", "font_color", Color.new(0.55_f32, 0.91_f32, 0.99_f32, 1.0_f32))
          btn_info.connect("pressed") do
            @log_filter_level = LogLevel::Info
            refresh_log_view
          end
          filter_bar.call("add_child", btn_info)
          @btn_filter_info = btn_info
        end

        btn_debug = Godot.create(Godot::Button)
        if btn_debug
          btn_debug.call("set_text", "Debug (0)")
          btn_debug.call("add_theme_color_override", "font_color", Color.new(0.31_f32, 0.98_f32, 0.48_f32, 1.0_f32))
          btn_debug.connect("pressed") do
            @log_filter_level = LogLevel::Debug
            refresh_log_view
          end
          filter_bar.call("add_child", btn_debug)
          @btn_filter_debug = btn_debug
        end

        btn_trace = Godot.create(Godot::Button)
        if btn_trace
          btn_trace.call("set_text", "Trace (0)")
          btn_trace.call("add_theme_color_override", "font_color", Color.new(0.6_f32, 0.65_f32, 0.75_f32, 1.0_f32))
          btn_trace.connect("pressed") do
            @log_filter_level = LogLevel::Trace
            refresh_log_view
          end
          filter_bar.call("add_child", btn_trace)
          @btn_filter_trace = btn_trace
        end

        # Public Safe Mode Toggle Pill
        btn_pub = Godot.create(Godot::Button)
        if btn_pub
          btn_pub.call("set_text", "Public Safe: OFF")
          btn_pub.connect("pressed") do
            @log_public_only = !@log_public_only
            btn_pub.call("set_text", @log_public_only ? "Public Safe: ON" : "Public Safe: OFF")
            btn_pub.call("add_theme_color_override", "font_color", @log_public_only ? Color.new(0.4_f32, 1.0_f32, 0.6_f32, 1.0_f32) : Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
            refresh_log_view
          end
          filter_bar.call("add_child", btn_pub)
          @btn_public_only = btn_pub
        end

        # Context Selector OptionButton
        ctx_opt = Godot.create(Godot::OptionButton)
        if ctx_opt
          ctx_opt.call("add_item", "In-Memory Ring Buffer", 0)
          ctx_opt.call("add_item", "Editor File (log/editor.log)", 1)
          ctx_opt.call("add_item", "Crystal File (log/editor-crystal.log)", 2)
          ctx_opt.call("add_item", "Crash Dump (log/crash.log)", 3)
          ctx_opt.call("add_item", "Public Log (log/public.log)", 4)
          ctx_opt.connect("item_selected") do |args|
            item_id = args.first?.try(&.as_i64) || 0_i64
            @log_context_mode = case item_id
                                when 1 then "editor"
                                when 2 then "crystal"
                                when 3 then "crash"
                                when 4 then "public"
                                else        "memory"
                                end
            refresh_log_view
          end
          filter_bar.call("add_child", ctx_opt)
          @context_select = ctx_opt
        end

        # Channel Selector OptionButton
        chan_opt = Godot.create(Godot::OptionButton)
        if chan_opt
          chan_opt.call("add_item", "All Channels", 0)
          channels = ["General", "Public", "Inspector", "ClassDB", "Bridge", "Compiler", "GC", "Editor", "Runtime"]
          channels.each_with_index do |ch, idx|
            chan_opt.call("add_item", ch, idx + 1)
          end
          chan_opt.connect("item_selected") do |args|
            idx = args.first?.try(&.as_i64) || 0_i64
            @log_filter_channel = (idx == 0) ? nil : channels[idx - 1]?
            refresh_log_view
          end
          filter_bar.call("add_child", chan_opt)
          @channel_select = chan_opt
        end

        vbox.call("add_child", filter_bar)
      end

      # --- Second Bar: Search, Auto-Scroll, Freeze, Clear, Copy, Open Folder ---
      action_bar = Godot.create(Godot::HBoxContainer)
      if action_bar
        action_bar.call("add_theme_constant_override", "separation", 8)

        search = Godot.create(Godot::LineEdit)
        if search
          search.call("set_placeholder_text", "Search logs... (live filter)")
          search.call("set_h_size_flags", 3)
          search.connect("text_changed") do |args|
            @log_search_query = args.first?.try(&.to_s) || ""
            refresh_log_view
          end
          action_bar.call("add_child", search)
          @search_line_edit = search
        end

        btn_scroll = Godot.create(Godot::Button)
        if btn_scroll
          btn_scroll.call("set_text", "Auto-Scroll: ON")
          btn_scroll.connect("pressed") do
            @log_auto_scroll = !@log_auto_scroll
            btn_scroll.call("set_text", @log_auto_scroll ? "Auto-Scroll: ON" : "Auto-Scroll: OFF")
          end
          action_bar.call("add_child", btn_scroll)
          @btn_auto_scroll = btn_scroll
        end

        btn_freeze = Godot.create(Godot::Button)
        if btn_freeze
          btn_freeze.call("set_text", "Freeze: OFF")
          btn_freeze.connect("pressed") do
            @log_frozen = !@log_frozen
            btn_freeze.call("set_text", @log_frozen ? "Freeze: ON" : "Freeze: OFF")
          end
          action_bar.call("add_child", btn_freeze)
          @btn_freeze = btn_freeze
        end

        btn_refresh = Godot.create(Godot::Button)
        if btn_refresh
          btn_refresh.call("set_text", "Refresh")
          btn_refresh.connect("pressed") { refresh_log_view }
          action_bar.call("add_child", btn_refresh)
        end

        btn_copy = Godot.create(Godot::Button)
        if btn_copy
          btn_copy.call("set_text", "Copy")
          btn_copy.connect("pressed") do
            if log = @log_output
              text = log.call_str("get_parsed_text")
              Godot::DisplayServer.new(Godot::DisplayServer.singleton_ptr).call("clipboard_set", text) unless text.empty?
            end
          end
          action_bar.call("add_child", btn_copy)
        end

        btn_clear = Godot.create(Godot::Button)
        if btn_clear
          btn_clear.call("set_text", "Clear")
          btn_clear.connect("pressed") { clear_log }
          action_bar.call("add_child", btn_clear)
        end

        btn_open = Godot.create(Godot::Button)
        if btn_open
          btn_open.call("set_text", "Open log/ Folder")
          btn_open.connect("pressed") do
            ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
            glob_path = ps.call_str("globalize_path", "res://log")
            os = Godot::OS.new(Godot::OS.singleton_ptr)
            os.call("shell_open", "file:///#{glob_path.gsub('\\', '/')}")
          end
          action_bar.call("add_child", btn_open)
        end

        vbox.call("add_child", action_bar)
      end

      # --- Log Viewport (RichTextLabel) ---
      log_box = Godot.create(Godot::RichTextLabel)
      if log_box
        log_box.call("set_h_size_flags", 3)
        log_box.call("set_v_size_flags", 3)
        log_box.call("set_use_bbcode", true)
        log_box.call("set_scroll_follow", true)
        log_box.call("set_selection_enabled", true)
        log_box.call("add_theme_color_override", "default_color", Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
        log_box.connect("meta_clicked") do |args|
          meta_str = args.first?.try(&.to_s) || ""
          if meta_str.starts_with?("file://") || meta_str.starts_with?("res://")
            os = Godot::OS.new(Godot::OS.singleton_ptr)
            os.call("shell_open", meta_str)
          end
        end
        @log_output = log_box
        vbox.call("add_child", log_box)
      end

      tabs.call("add_child", vbox)
    end

    # =========================================================================
    # Logging Utilities & Live Filter Dispatch
    # =========================================================================

    def refresh_log_view : Void
      return if @log_frozen
      records = fetch_active_records

      # If Public Safe mode is active, filter out secret/confidential records and non-public info
      if @log_public_only
        records = records.select { |r| r.level.error? || (r.public? && !r.confidential?) }
      end

      # Update badge counts
      all_cnt = records.size
      err_cnt = records.count(&.level.error?)
      warn_cnt = records.count(&.level.warn?)
      info_cnt = records.count(&.level.info?)
      debug_cnt = records.count(&.level.debug?)
      trace_cnt = records.count(&.level.trace?)

      @btn_filter_all.try &.call("set_text", "All (#{all_cnt})")
      @btn_filter_err.try &.call("set_text", "Errors (#{err_cnt})")
      @btn_filter_warn.try &.call("set_text", "Warnings (#{warn_cnt})")
      @btn_filter_info.try &.call("set_text", "Info (#{info_cnt})")
      @btn_filter_debug.try &.call("set_text", "Debug (#{debug_cnt})")
      @btn_filter_trace.try &.call("set_text", "Trace (#{trace_cnt})")

      # Filter records
      filtered = records.select do |r|
        pass_level = @log_filter_level.nil? || r.level == @log_filter_level
        pass_channel = @log_filter_channel.nil? || r.channel.downcase == @log_filter_channel.not_nil!.downcase
        pass_search = @log_search_query.empty? ||
                      r.message.downcase.includes?(@log_search_query.downcase) ||
                      r.channel.downcase.includes?(@log_search_query.downcase)
        pass_level && pass_channel && pass_search
      end

      if log = @log_output
        log.call("clear")
        bbcode = filtered.map(&.to_bbcode(include_location: true)).join("\n")
        log.call("append_text", bbcode)
        if @log_auto_scroll
          log.call("scroll_to_line", filtered.size)
        end
      end
    end

    private def fetch_active_records : Array(LogRecord)
      case @log_context_mode
      when "editor"
        load_records_from_file("res://log/editor.log", "Editor")
      when "crystal"
        load_records_from_file("res://log/editor-crystal.log", "Crystal")
      when "crash"
        load_records_from_file("res://log/crash.log", "Crash")
      when "public"
        load_records_from_file("res://log/public.log", "Public")
      else
        Godot.logger.ring_buffer.snapshot
      end
    end

    private def load_records_from_file(res_path : String, default_chan : String) : Array(LogRecord)
      ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
      global_path = ps.call_str("globalize_path", res_path)
      return [] of LogRecord unless File.exists?(global_path)

      records = [] of LogRecord
      File.each_line(global_path) do |line|
        level = LogLevel.from_line(line, default: LogLevel::Info)

        chan = default_chan
        if line =~ /\[([A-Za-z0-9_-]+)\]/
          matched = $1
          chan = matched unless LogLevel.all_name_tags.includes?(matched)
        end

        records << LogRecord.new(level: level, channel: chan, message: line)
      end
      records
    rescue
      [] of LogRecord
    end

    def log_info(msg : String) : Void
      Godot.log_info("Editor", msg)
      refresh_log_view
    end

    def log_success(msg : String) : Void
      Godot.log_info("Editor", msg)
      refresh_log_view
    end

    def log_warn(msg : String) : Void
      Godot.log_warn("Editor", msg)
      refresh_log_view
    end

    def log_error(msg : String) : Void
      Godot.log_error("Editor", msg)
      refresh_log_view
    end

    def append_log(line : String) : Void
      Godot.log_info("Editor", line)
      refresh_log_view
    end

    def clear_log : Void
      Godot.logger.ring_buffer.clear
      if log = @log_output
        log.call("clear")
      end
      refresh_log_view
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

    def find_lapis_executable : String?
      if sys_lapis = Process.find_executable("lapis")
        return sys_lapis
      end
      lapis_candidates = [
        "addons/crystal_integration/bin/lapis.exe", "addons/crystal_integration/bin/lapis",
        "bin/lapis.exe", "bin/lapis",
        "../bin/lapis.exe", "../bin/lapis",
        "../../bin/lapis.exe", "../../bin/lapis",
      ]
      lapis_candidates.find { |p| File.exists?(p) }
    end

    def on_package_game : Void
      log_info("Packaging standalone game executable...")
      lapis_bin = find_lapis_executable
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
        Godot::Bridge.set_reloading(true)
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

        # Parse plugin.cfg
        cfg_path = File.join(full_dir, "plugin.cfg")
        display_name = entry
        version = ""
        description = ""
        dependencies = [] of String

        if File.exists?(cfg_path)
          begin
            File.each_line(cfg_path) do |line|
              t = line.strip
              if t =~ /^name\s*=\s*["']([^"']+)["']/
                display_name = $1
              elsif t =~ /^version\s*=\s*["']([^"']+)["']/
                version = $1
              elsif t =~ /^description\s*=\s*["']([^"']+)["']/
                description = $1
              elsif t =~ /^dependencies\s*=\s*\[(.*)\]/
                $1.scan(/["']([^"']+)["']/) { |m| dependencies << m[1].strip unless m[1].strip.empty? }
              elsif t =~ /^dependencies\s*=\s*["']([^"']+)["']/
                $1.split(',').each { |d| dependencies << d.strip unless d.strip.empty? }
              end
            end
          rescue
          end
        end

        # Parse addon.json if exists
        json_path = File.join(full_dir, "addon.json")
        if File.exists?(json_path)
          begin
            j_val = ::JSON.parse(File.read(json_path))
            description = j_val["description"]?.try(&.as_s) || description if description.empty?
            if j_deps = j_val["dependencies"]?.try(&.as_a)
              j_deps.each do |jd|
                s = jd.as_s rescue nil
                dependencies << s if s && !dependencies.includes?(s)
              end
            end
          rescue
          end
        end

        # Check if it has Crystal source or recompilable target
        main_cr = File.join(full_dir, "src", "main.cr")
        has_src = File.exists?(main_cr) || Dir.glob(File.join(full_dir, "src/**/*.cr")).size > 0
        has_makefile = File.exists?(File.join(full_dir, "Makefile"))
        has_shard = File.exists?(File.join(full_dir, "shard.yml"))
        is_recompilable = has_src || has_makefile || has_shard

        # Check for binaries
        bin_dir = File.join(full_dir, "bin")
        bin_files = Dir.exists?(bin_dir) ? Dir.children(bin_dir).select { |f| f.ends_with?(".dll") || f.ends_with?(".so") || f.ends_with?(".dylib") } : [] of String
        bin_files.reject! { |f| f.starts_with?("crystal_bridge") || ["gc.dll", "iconv-2.dll", "pcre2-8.dll", "libgodot.dll"].includes?(f) }
        has_gdext = Dir.glob(File.join(full_dir, "**/*.gdextension")).size > 0

        item = tree.call_obj("create_item", root)
        next unless item

        # Col 0: Name (and Version)
        title_str = version.empty? ? display_name : "#{display_name} (v#{version})"
        item.call("set_text", 0, title_str)
        item.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))

        # Col 1: Type
        if is_recompilable
          item.call("set_text", 1, "Crystal Source")
          item.call("set_custom_color", 1, Color.new(0.4_f32, 1.0_f32, 0.5_f32, 1.0_f32))
        elsif has_gdext || !bin_files.empty?
          item.call("set_text", 1, "GDExtension (Binary)")
          item.call("set_custom_color", 1, Color.new(0.4_f32, 0.85_f32, 1.0_f32, 1.0_f32))
        else
          item.call("set_text", 1, "GDScript Plugin")
          item.call("set_custom_color", 1, Color.new(1.0_f32, 0.9_f32, 0.4_f32, 1.0_f32))
        end

        # Col 2: Status
        if is_recompilable
          if bin_files.empty?
            item.call("set_text", 2, "Missing Binary")
            item.call("set_custom_color", 2, Color.new(1.0_f32, 0.4_f32, 0.4_f32, 1.0_f32))
          else
            bin_time = File.info(File.join(bin_dir, bin_files[0])).modification_time
            src_target = File.exists?(main_cr) ? main_cr : File.join(full_dir, "shard.yml")
            src_time = File.exists?(src_target) ? File.info(src_target).modification_time : bin_time
            if src_time > bin_time
              item.call("set_text", 2, "Needs recompile")
              item.call("set_custom_color", 2, Color.new(1.0_f32, 0.8_f32, 0.2_f32, 1.0_f32))
            else
              item.call("set_text", 2, "Up-to-date")
              item.call("set_custom_color", 2, Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
            end
          end
        elsif has_gdext || !bin_files.empty?
          item.call("set_text", 2, "Ready (Precompiled)")
          item.call("set_custom_color", 2, Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
        else
          item.call("set_text", 2, "Ready (Script)")
          item.call("set_custom_color", 2, Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
        end

        # Col 3: Dependencies
        deps_text = dependencies.empty? ? "-" : dependencies.join(", ")
        item.call("set_text", 3, deps_text)
        item.call("set_custom_color", 3, Color.new(0.8_f32, 0.8_f32, 0.9_f32, 1.0_f32))

        # Col 4: Description
        desc_clean = description.empty? ? "No description" : description.lines.first?.try(&.strip) || "No description"
        desc_clean = desc_clean[0...35] + "..." if desc_clean.size > 38
        item.call("set_text", 4, desc_clean)
        item.call("set_custom_color", 4, Color.new(0.85_f32, 0.85_f32, 0.85_f32, 1.0_f32))

        # Col 5: Action
        if is_recompilable
          item.call("set_text", 5, "Recompile")
          item.call("set_custom_color", 5, Color.new(0.5_f32, 0.9_f32, 1.0_f32, 1.0_f32))
        else
          item.call("set_text", 5, "-")
          item.call("set_custom_color", 5, Color.new(0.6_f32, 0.6_f32, 0.6_f32, 1.0_f32))
        end
      end
    rescue ex
      log_error("Error scanning addons: #{ex.message}")
    end

    def on_recompile_all_addons : Void
      log_info("Recompiling all recompilable addons...")
      lapis_bin = find_lapis_executable
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
      lapis_bin = find_lapis_executable
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

    private def find_spec_files_recursive(dir : String) : Array(String)
      files = [] of String
      return files unless Dir.exists?(dir)
      Dir.children(dir).sort.each do |child|
        full = File.join(dir, child).gsub('\\', '/')
        if Dir.exists?(full)
          files.concat(find_spec_files_recursive(full))
        elsif child.ends_with?("_spec.cr")
          files << full
        end
      end
      files
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

      spec_files = find_spec_files_recursive(spec_dir)

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

      # Populate registered In-Editor Lapis::Test suites
      editor_tests = ::Lapis::Test::Registry.all_tests
      if !editor_tests.empty?
        framework_root = tree.call_obj("create_item", root)
        if framework_root
          framework_root.call("set_text", 0, "In-Editor Test Suites (Lapis::Test)")
          framework_root.call("set_custom_color", 0, Color.new(0.4_f32, 0.9_f32, 1.0_f32, 1.0_f32))
          framework_root.call("set_text", 1, "[⚪ Ready]")
          framework_root.call("set_custom_color", 1, Color.new(0.9_f32, 0.9_f32, 0.9_f32, 1.0_f32))
          framework_root.call("set_text", 2, "editor_all")
          framework_root.call("set_collapsed", false)

          ::Lapis::Test::Registry.categories.each do |cat|
            cat_item = tree.call_obj("create_item", framework_root)
            next unless cat_item
            cat_tests = ::Lapis::Test::Registry.for_category(cat)
            cat_item.call("set_text", 0, "#{cat} (#{cat_tests.size} tests)")
            cat_item.call("set_custom_color", 0, Color.new(0.9_f32, 0.95_f32, 1.0_f32, 1.0_f32))
            cat_item.call("set_text", 1, "[⚪ Ready]")
            cat_item.call("set_text", 2, "category:#{cat}")
            cat_item.call("set_collapsed", false)

            cat_tests.each do |t|
              t_item = tree.call_obj("create_item", cat_item)
              next unless t_item
              t_item.call("set_text", 0, "  • #{t.name}")
              t_item.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
              t_item.call("set_text", 1, "[⚪ Ready]")
              t_item.call("set_text", 2, "test:#{cat}/#{t.name}")
            end
          end
        end
      end

      if lbl = @test_status_label
        lbl.call("set_text", "Discovered #{spec_files.size} spec files (#{total_specs} specs) + #{editor_tests.size} in-editor tests. Ready.")
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
      if path.empty? || path == "editor_all"
        on_run_in_editor_tests
        return
      end

      if path.starts_with?("category:")
        cat = path.sub(/^category:/, "")
        log_info("Running In-Editor category: #{cat}...")
        results = ::Lapis::Test::Registry.run_category(cat, self)
        display_test_results("Category: #{cat}", results, selected)
        return
      elsif path.starts_with?("test:")
        parts = path.sub(/^test:/, "").split('/', 2)
        cat = parts[0]
        test_name = parts[1]? || ""
        log_info("Running In-Editor test: [#{cat}] #{test_name}...")
        results = ::Lapis::Test::Registry.run_category(cat, self, filter: test_name)
        display_test_results("[#{cat}] #{test_name}", results, selected)
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

    def on_run_in_editor_tests : Void
      log_info("Executing In-Editor Lapis::Test suites...")
      if lbl = @test_status_label
        lbl.call("set_text", "Running In-Editor test suites...")
        lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 0.85_f32, 0.2_f32, 1.0_f32))
      end

      start_time = ::Time.instant
      results = ::Lapis::Test::Registry.run_all(self)
      display_test_results("In-Editor Suites", results, nil)
    rescue ex
      log_error("Error running in-editor tests: #{ex.message}")
    end

    private def display_test_results(title : String, results : Array(::Lapis::Test::TestResult), target_item : Node?) : Void
      passed_count = results.count(&.passed)
      total_count = results.size
      all_passed = (passed_count == total_count && total_count > 0)

      output_io = IO::Memory.new
      output_io.puts "Execution Results: #{title}"
      output_io.puts "Total: #{total_count} | Passed: #{passed_count} | Failed: #{total_count - passed_count}"
      output_io.puts "--------------------------------------------------"
      results.each do |r|
        status_tag = r.passed ? "[PASS]" : "[FAIL]"
        output_io.puts "  #{status_tag} [#{r.category}] #{r.name} (#{r.duration_ms.round(1)}ms)"
        unless r.passed
          output_io.puts "    Error: #{r.message}"
        end
      end

      output_text = output_io.to_s

      if details = @test_details
        if all_passed
          details.call("set_text", "[color=#44ff88][b]All #{total_count} tests in #{title} passed cleanly![/b][/color]\n\n[color=#f5f5f5]#{output_text}[/color]")
        else
          details.call("set_text", "[color=#ff4444][b]Failures Detected in #{title} (#{total_count - passed_count}/#{total_count}):[/b][/color]\n\n[color=#ff8888]#{output_text}[/color]")
        end
      end

      if item = target_item
        status_str = all_passed ? "[✅ PASSED]" : "[❌ FAILED]"
        status_col = all_passed ? Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32) : Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32)
        update_tree_item_status_recursive(item, status_str, status_col)
      end

      if lbl = @test_status_label
        if all_passed
          lbl.call("set_text", "✅ #{title}: All #{total_count} tests passed cleanly!")
          lbl.call("add_theme_color_override", "font_color", Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32))
          log_success("#{title}: All #{total_count} tests passed!")
        else
          lbl.call("set_text", "❌ #{title}: #{total_count - passed_count}/#{total_count} tests failed.")
          lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32))
          log_error("#{title}: Failures detected.")
        end
      end
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

    # =========================================================================
    # Benchmarks Operations
    # =========================================================================

    def refresh_benchmarks_list : Void
      tree = @benchmarks_tree
      return unless tree
      tree.call("clear")

      root = tree.call_obj("create_item")
      return unless root
      root.call("set_text", 0, "All Registered Benchmarks & Comparison Groups")
      root.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))

      filter = @benchmarks_category_filter

      # 1. Comparison Groups Section
      if filter.nil? || filter == "groups"
        groups_root = tree.call_obj("create_item", root)
        if groups_root
          groups_root.call("set_text", 0, "Comparison Groups (Side-by-Side & Multi-Language)")
          groups_root.call("set_custom_color", 0, Color.new(0.0_f32, 0.85_f32, 1.0_f32, 1.0_f32))

          # MatrixMultiplication Group
          grp_matmul = tree.call_obj("create_item", groups_root)
          if grp_matmul
            grp_matmul.call("set_text", 0, "MatrixMultiplication")
            grp_matmul.call("set_text", 1, "Compute Group")
            grp_matmul.call("set_text", 2, "Ready")
            grp_matmul.call("set_text", 5, "Crystal, C++, Rust, C#, GDScript")
            grp_matmul.call("set_custom_color", 0, Color.new(0.4_f32, 0.9_f32, 1.0_f32, 1.0_f32))

            [
              {"Matmul (Crystal)", "Crystal Baseline", "Ready", "-", "1.0x (Baseline)", "LLVM -O3"},
              {"Matmul (C++)", "C++ Target", "Ready", "-", "-", "GCC/Clang -O3"},
              {"Matmul (Rust)", "Rust Target", "Ready", "-", "-", "rustc -O"},
              {"Matmul (C#)", "C# Target", "Ready", "-", "-", ".NET 8 RyuJIT"},
              {"Matmul (GDScript)", "GDScript Target", "-", "Ready", "-", "Godot VM Bytecode"},
            ].each do |(t_name, t_cat, t_cr, t_gd, t_sp, t_meta)|
              item = tree.call_obj("create_item", grp_matmul)
              next unless item
              item.call("set_text", 0, t_name)
              item.call("set_text", 1, t_cat)
              item.call("set_text", 2, t_cr)
              item.call("set_text", 3, t_gd)
              item.call("set_text", 4, t_sp)
              item.call("set_text", 5, t_meta)
            end
          end

          # CompileTime Group
          grp_comp = tree.call_obj("create_item", groups_root)
          if grp_comp
            grp_comp.call("set_text", 0, "CompileTime")
            grp_comp.call("set_text", 1, "Toolchain Group")
            grp_comp.call("set_text", 2, "Ready")
            grp_comp.call("set_text", 5, "Debug vs Release compile times & binary footprint")
            grp_comp.call("set_custom_color", 0, Color.new(0.85_f32, 0.65_f32, 1.0_f32, 1.0_f32))

            [
              {"Crystal Compiler", "Toolchain", "Ready", "-", "-", "Debug vs Release"},
              {"C++ Compiler", "Toolchain", "Ready", "-", "-", "Debug vs Release"},
              {"C# Compiler", "Toolchain", "Ready", "-", "-", "Debug vs Release"},
              {"Rust Compiler", "Toolchain", "Ready", "-", "-", "Debug vs Release"},
            ].each do |(t_name, t_cat, t_cr, t_gd, t_sp, t_meta)|
              item = tree.call_obj("create_item", grp_comp)
              next unless item
              item.call("set_text", 0, t_name)
              item.call("set_text", 1, t_cat)
              item.call("set_text", 2, t_cr)
              item.call("set_text", 3, t_gd)
              item.call("set_text", 4, t_sp)
              item.call("set_text", 5, t_meta)
            end
          end

          # Shaders Group
          grp_shader = tree.call_obj("create_item", groups_root)
          if grp_shader
            grp_shader.call("set_text", 0, "Shaders")
            grp_shader.call("set_text", 1, "EngineCore Group")
            grp_shader.call("set_text", 2, "Ready")
            grp_shader.call("set_text", 5, "Throughput, Uniform Updates & VisualShader AST")
            grp_shader.call("set_custom_color", 0, Color.new(1.0_f32, 0.6_f32, 0.0_f32, 1.0_f32))

            [
              {"ShaderCompilation", "EngineCore", "Ready", "-", "-", "1,000 shader permutations"},
              {"ShaderUniforms", "EngineCore", "Ready", "-", "-", "50,000 uniform updates"},
              {"VisualShader", "EngineCore", "Ready", "-", "-", "200 visual shader graphs"},
            ].each do |(t_name, t_cat, t_cr, t_gd, t_sp, t_meta)|
              item = tree.call_obj("create_item", grp_shader)
              next unless item
              item.call("set_text", 0, t_name)
              item.call("set_text", 1, t_cat)
              item.call("set_text", 2, t_cr)
              item.call("set_text", 3, t_gd)
              item.call("set_text", 4, t_sp)
              item.call("set_text", 5, t_meta)
            end
          end

          # ProceduralNoise Group
          grp_noise = tree.call_obj("create_item", groups_root)
          if grp_noise
            grp_noise.call("set_text", 0, "ProceduralNoise")
            grp_noise.call("set_text", 1, "EngineCore Group")
            grp_noise.call("set_text", 2, "Ready")
            grp_noise.call("set_text", 5, "FastNoiseLite Perlin, Simplex, and Cellular Voronoi")
            grp_noise.call("set_custom_color", 0, Color.new(0.3_f32, 0.85_f32, 0.5_f32, 1.0_f32))

            [
              {"PerlinNoise", "EngineCore", "Ready", "-", "-", "2D Perlin grid (250k samples)"},
              {"SimplexNoise", "EngineCore", "Ready", "-", "-", "3D Simplex Smooth (100k samples)"},
              {"CellularNoise", "EngineCore", "Ready", "-", "-", "2D Cellular Voronoi (250k samples)"},
            ].each do |(t_name, t_cat, t_cr, t_gd, t_sp, t_meta)|
              item = tree.call_obj("create_item", grp_noise)
              next unless item
              item.call("set_text", 0, t_name)
              item.call("set_text", 1, t_cat)
              item.call("set_text", 2, t_cr)
              item.call("set_text", 3, t_gd)
              item.call("set_text", 4, t_sp)
              item.call("set_text", 5, t_meta)
            end
          end

          # SceneGraph Group
          grp_scene = tree.call_obj("create_item", groups_root)
          if grp_scene
            grp_scene.call("set_text", 0, "SceneGraph")
            grp_scene.call("set_text", 1, "EngineCore Group")
            grp_scene.call("set_text", 2, "Ready")
            grp_scene.call("set_text", 5, "Node lifecycle, recursive traversal & group queries")
            grp_scene.call("set_custom_color", 0, Color.new(0.9_f32, 0.7_f32, 0.2_f32, 1.0_f32))

            [
              {"NodeLifecycle", "EngineCore", "Ready", "-", "-", "20,000 nodes alloc, free, reparent"},
              {"TreeTraversal", "EngineCore", "Ready", "-", "-", "20,000 nodes recursive traversal"},
              {"NodeGroups", "EngineCore", "Ready", "-", "-", "20,000 nodes group partitions"},
            ].each do |(t_name, t_cat, t_cr, t_gd, t_sp, t_meta)|
              item = tree.call_obj("create_item", grp_scene)
              next unless item
              item.call("set_text", 0, t_name)
              item.call("set_text", 1, t_cat)
              item.call("set_text", 2, t_cr)
              item.call("set_text", 3, t_gd)
              item.call("set_text", 4, t_sp)
              item.call("set_text", 5, t_meta)
            end
          end
        end
      end

      # 2. Custom Project Benchmarks Section
      custom_cases = ::Lapis::Benchmark.all
      if (filter.nil? || filter == "custom") && !custom_cases.empty?
        cust_group = tree.call_obj("create_item", root)
        if cust_group
          cust_group.call("set_text", 0, "Custom Project Benchmarks (#{custom_cases.size})")
          cust_group.call("set_custom_color", 0, Color.new(0.4_f32, 0.9_f32, 1.0_f32, 1.0_f32))
          custom_cases.each do |c|
            item = tree.call_obj("create_item", cust_group)
            next unless item
            item.call("set_text", 0, c.name)
            item.call("set_text", 1, c.category.display_name)
            item.call("set_text", 2, "Ready")
            item.call("set_text", 3, "-")
            item.call("set_text", 4, "-")
            item.call("set_text", 5, "Project benchmark")
          end
        end
      end

      # 3. Builtin Individual Benchmarks (Categorized)
      builtin_names = [
        {"Matmul", "Compute", "Dense 2D matrix multiplication (N=300, float64)"},
        {"Primes", "Compute", "Sieve of Atkin + Prefix Trie search (Limit=500k)"},
        {"Brainfuck", "Compute", "Brainfuck AST interpreter + dynamic tape"},
        {"Base64", "Compute", "Base64 strict encode & decode loop"},
        {"JSON", "Compute", "JSON parse & 3D coordinate aggregation"},
        {"NBody", "Compute", "3D orbital dynamics physics integration"},
        {"BinaryTrees", "Compute", "GC pressure & binary tree allocation"},
        {"Mandelbrot", "Compute", "2D coordinate escape-time fractal"},
        {"TransformMath", "Compute", "Transform3D translations & rotations"},
        {"VectorMath2D", "Compute", "Vector2 lerp, dot, and normalization"},
        {"NodeLifecycle", "EngineCore", "Node2D lifecycle operations (20k)"},
        {"MaterialResources", "EngineCore", "StandardMaterial3D properties & refcounting"},
        {"Signals", "EngineCore", "Signal connection & dynamic emission"},
        {"PerlinNoise", "EngineCore", "FastNoiseLite 2D Perlin noise"},
        {"SimplexNoise", "EngineCore", "FastNoiseLite 3D Simplex Smooth noise"},
        {"CellularNoise", "EngineCore", "FastNoiseLite 2D Cellular Voronoi noise"},
        {"SurfaceTool", "EngineCore", "SurfaceTool procedural mesh generation"},
        {"AStar2D", "EngineCore", "AStar2D pathfinding on 100x100 grid"},
        {"TreeTraversal", "EngineCore", "Scene tree recursive traversal"},
        {"ImageProcessing", "EngineCore", "Image procedural pixel computation"},
        {"TransformHierarchy", "EngineCore", "Node3D hierarchy transformations"},
        {"NodeGroups", "EngineCore", "Node grouping & query operations"},
        {"DictionaryOps", "EngineCore", "Godot Dictionary 50k insertions"},
        {"ConfigFileOps", "EngineCore", "ConfigFile parsing & querying"},
        {"ShaderCompilation", "EngineCore", "Shader compilation throughput (1k)"},
        {"ShaderUniforms", "EngineCore", "High-frequency uniform parameter dispatch (50k)"},
        {"VisualShader", "EngineCore", "VisualShader AST node graph construction (200)"},
        {"CompileTimes", "Toolchain", "Multi-language compilation & binary size"},
      ]

      if filter.nil? || filter == "compute"
        comp_group = tree.call_obj("create_item", root)
        if comp_group
          comp_group.call("set_text", 0, "Standard Compute Benchmarks")
          comp_group.call("set_custom_color", 0, Color.new(0.0_f32, 0.82_f32, 1.0_f32, 1.0_f32))
          builtin_names.select { |(_, cat, _)| cat == "Compute" }.each do |(b_name, b_cat, b_desc)|
            item = tree.call_obj("create_item", comp_group)
            next unless item
            item.call("set_text", 0, b_name)
            item.call("set_text", 1, b_cat)
            item.call("set_text", 2, "Ready")
            item.call("set_text", 3, "-")
            item.call("set_text", 4, "-")
            item.call("set_text", 5, b_desc)
          end
        end
      end

      if filter.nil? || filter == "enginecore"
        eng_group = tree.call_obj("create_item", root)
        if eng_group
          eng_group.call("set_text", 0, "Engine Core & Shader Benchmarks")
          eng_group.call("set_custom_color", 0, Color.new(1.0_f32, 0.6_f32, 0.0_f32, 1.0_f32))
          builtin_names.select { |(_, cat, _)| cat == "EngineCore" }.each do |(b_name, b_cat, b_desc)|
            item = tree.call_obj("create_item", eng_group)
            next unless item
            item.call("set_text", 0, b_name)
            item.call("set_text", 1, b_cat)
            item.call("set_text", 2, "Ready")
            item.call("set_text", 3, "-")
            item.call("set_text", 4, "-")
            item.call("set_text", 5, b_desc)
          end
        end
      end

      if filter.nil? || filter == "toolchain"
        tool_group = tree.call_obj("create_item", root)
        if tool_group
          tool_group.call("set_text", 0, "Toolchain & Compilation Benchmarks")
          tool_group.call("set_custom_color", 0, Color.new(0.85_f32, 0.65_f32, 1.0_f32, 1.0_f32))
          builtin_names.select { |(_, cat, _)| cat == "Toolchain" }.each do |(b_name, b_cat, b_desc)|
            item = tree.call_obj("create_item", tool_group)
            next unless item
            item.call("set_text", 0, b_name)
            item.call("set_text", 1, b_cat)
            item.call("set_text", 2, "Ready")
            item.call("set_text", 3, "-")
            item.call("set_text", 4, "-")
            item.call("set_text", 5, b_desc)
          end
        end
      end

      total_count = custom_cases.size + builtin_names.size
      @benchmarks_status_label.try &.call("set_text", "#{total_count} benchmarks and 5 comparison groups ready. Click 'Run All' or 'Run Selected'.")
    end

    def on_run_selected_benchmark : Void
      tree = @benchmarks_tree
      return unless tree

      selected = tree.call_obj("get_selected")
      unless selected && !selected.pointer.null?
        log_warn("No benchmark or group selected. Running all benchmarks.")
        on_run_benchmarks
        return
      end

      target_name = selected.call_str("get_text", 0).strip
      target_cat = selected.call_str("get_text", 1).strip

      if target_cat.includes?("Group")
        log_info("Executing comparison group: #{target_name}")
        on_run_benchmarks(group_name: target_name)
      else
        clean_name = target_name.sub(/\s*\(.*\)/, "").strip
        log_info("Executing selected benchmark: #{clean_name}")
        on_run_benchmarks(benchmark_name: clean_name)
      end
    end

    def on_run_benchmarks(group_name : String? = nil, benchmark_name : String? = nil) : Void
      log_info("Starting Lapis benchmark execution...")
      @benchmarks_status_label.try &.call("set_text", "Executing benchmarks...")

      iters = 3
      if spin = @benchmarks_iterations_spin
        iters = spin.call_f64("get_value").to_i
      end

      lapis_exe = find_lapis_executable || "lapis"
      args = ["benchmarks", "run", "html", "-i", iters.to_s, "--no-tui"]
      args += ["-g", group_name] if group_name
      args += ["-f", benchmark_name] if benchmark_name

      if log_box = @benchmarks_log
        log_box.call("set_text", "[color=#00d2ff]━━━ Starting Benchmark Execution (Iterations: #{iters}) ━━━[/color]\n")
      end

      output_io = IO::Memory.new
      start_time = ::Time.instant

      # Spawn subprocess
      res = Process.run(lapis_exe, args, output: output_io, error: output_io)
      elapsed = (::Time.instant - start_time).total_seconds.round(2)
      out_str = output_io.to_s

      if log_box = @benchmarks_log
        log_box.call("append_text", out_str)
      end

      if res.success?
        log_success("Benchmark execution completed in #{elapsed}s!")
        @benchmarks_status_label.try &.call("set_text", "Benchmarks complete! HTML & XML reports updated (#{elapsed}s).")
        latest_xml = "benchmarks/reports/benchmarks_latest.xml"
        if File.exists?(latest_xml)
          populate_benchmark_results_from_xml(latest_xml)
        end
      else
        log_error("Benchmark execution finished with exit code #{res.exit_code}.")
        @benchmarks_status_label.try &.call("set_text", "Benchmark run failed. Check Benchmark Log below.")
      end
      append_log(out_str)
    end

    def populate_benchmark_results_from_xml(xml_path : String) : Void
      tree = @benchmarks_tree
      return unless tree && File.exists?(xml_path)

      root = tree.call_obj("get_root")
      return unless root

      xml_text = File.read(xml_path)

      # Match each case block
      xml_text.scan(/<case name="([^"]+)"[^>]*>(.*?)<\/case>/m).each do |match|
        c_name = match[1]
        case_content = match[2]

        cr_ms = case_content.match(/<crystal ms="([^"]+)"/).try &.[1] || "0.0"
        gd_ms = case_content.match(/<gdscript ms="([^"]+)"/).try &.[1]
        sp = case_content.match(/<speedup ratio="([^"]+)"/).try &.[1]
        cpp_ms = case_content.match(/<cpp ms="([^"]+)"/).try &.[1]
        rs_ms = case_content.match(/<rust ms="([^"]+)"/).try &.[1]
        cs_ms = case_content.match(/<csharp ms="([^"]+)"/).try &.[1]

        # Extract custom metrics
        metric_parts = [] of String
        case_content.scan(/<metric key="([^"]+)" value="([^"]+)"/).each do |m_match|
          k = m_match[1]
          v = m_match[2].to_f? || 0.0
          if k == "shaders_per_sec"
            metric_parts << "#{v.to_i} shaders/sec"
          elsif k == "updates_per_sec"
            metric_parts << "#{(v / 1000.0).round(1)}k updates/sec"
          elsif k == "graphs_per_sec"
            metric_parts << "#{v.to_i} graphs/sec"
          elsif k == "cr_debug_ms"
            metric_parts << "Cr Debug: #{v.to_i}ms"
          elsif k == "cr_release_ms"
            metric_parts << "Cr Release: #{v.to_i}ms"
          elsif k == "cpp_release_ms"
            metric_parts << "C++: #{v.to_i}ms"
          elsif k == "rs_release_ms"
            metric_parts << "Rust: #{v.to_i}ms"
          elsif k == "cs_release_ms"
            metric_parts << "C#: #{v.to_i}ms"
          end
        end

        multi_lang_str = String.build do |m_io|
          m_io << "C++: #{cpp_ms}ms " if cpp_ms
          m_io << "Rust: #{rs_ms}ms " if rs_ms
          m_io << "C#: #{cs_ms}ms " if cs_ms
          m_io << metric_parts.join(", ") unless metric_parts.empty?
        end

        gd_str = gd_ms ? "#{gd_ms} ms" : "-"
        sp_str = sp ? "#{sp}x" : "-"

        find_and_update_benchmark_tree_item(root, c_name, "#{cr_ms} ms", gd_str, sp_str, multi_lang_str)

        # Update specific multi-lang rows under groups
        if c_name == "Matmul"
          find_and_update_child_row(root, "Matmul (Crystal)", "#{cr_ms} ms", gd_str, sp_str, "LLVM -O3")
          find_and_update_child_row(root, "Matmul (C++)", cpp_ms ? "#{cpp_ms} ms" : "-", "-", "-", "GCC/Clang -O3")
          find_and_update_child_row(root, "Matmul (Rust)", rs_ms ? "#{rs_ms} ms" : "-", "-", "-", "rustc -O")
          find_and_update_child_row(root, "Matmul (C#)", cs_ms ? "#{cs_ms} ms" : "-", "-", "-", ".NET 8 RyuJIT")
          find_and_update_child_row(root, "Matmul (GDScript)", "-", gd_str, "-", "Godot VM Bytecode")
        end
      end
    end

    def find_and_update_child_row(item : Node, target_name : String, cr_ms : String, gd_ms : String, sp : String, metrics : String) : Bool
      item_name = item.call_str("get_text", 0).strip
      if item_name == target_name
        item.call("set_text", 2, cr_ms)
        item.call("set_custom_color", 2, Color.new(0.0_f32, 0.82_f32, 1.0_f32, 1.0_f32))
        item.call("set_text", 3, gd_ms)
        item.call("set_custom_color", 3, Color.new(1.0_f32, 0.6_f32, 0.0_f32, 1.0_f32))
        item.call("set_text", 4, sp)
        item.call("set_custom_color", 4, Color.new(0.25_f32, 0.85_f32, 0.35_f32, 1.0_f32))
        item.call("set_text", 5, metrics) unless metrics.empty?
        return true
      end

      child = item.call_obj("get_first_child")
      while child && !child.pointer.null?
        if find_and_update_child_row(child, target_name, cr_ms, gd_ms, sp, metrics)
          return true
        end
        child = child.call_obj("get_next")
      end
      false
    end

    def find_and_update_benchmark_tree_item(item : Node, name : String, cr_ms : String, gd_ms : String, sp : String, metrics : String = "") : Bool
      item_name = item.call_str("get_text", 0).strip
      if item_name == name || item_name.downcase == name.downcase
        item.call("set_text", 2, cr_ms)
        item.call("set_custom_color", 2, Color.new(0.0_f32, 0.82_f32, 1.0_f32, 1.0_f32))
        item.call("set_text", 3, gd_ms)
        item.call("set_custom_color", 3, Color.new(1.0_f32, 0.6_f32, 0.0_f32, 1.0_f32))
        item.call("set_text", 4, sp)
        item.call("set_custom_color", 4, Color.new(0.25_f32, 0.85_f32, 0.35_f32, 1.0_f32))
        item.call("set_text", 5, metrics) unless metrics.empty?
        return true
      end

      child = item.call_obj("get_first_child")
      while child && !child.pointer.null?
        if find_and_update_benchmark_tree_item(child, name, cr_ms, gd_ms, sp, metrics)
          return true
        end
        child = child.call_obj("get_next")
      end
      false
    end

    def on_open_benchmarks_html : Void
      report_candidates = [
        "benchmarks/reports/benchmark_report.html",
        "benchmarks/reports/benchmarks.html",
        "benchmarks/results/benchmark_report.html",
      ]
      found = report_candidates.find { |p| File.exists?(p) }
      if found
        full_path = File.expand_path(found)
        if !Godot::OS.singleton_ptr.null?
          os = Godot::OS.new(Godot::OS.singleton_ptr)
          os.call("shell_open", "file:///#{full_path.gsub('\\', '/')}")
          log_info("Opened benchmark report: #{full_path}")
        end
      else
        log_error("Benchmark report HTML not found. Run benchmarks first.")
      end
    end
  end
end

alias CrystalPanel = Lapis::CrystalPanel

module Godot
  alias CrystalPanel = ::Lapis::CrystalPanel
end
