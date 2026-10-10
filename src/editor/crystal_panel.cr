# =============================================================================
# LibGodot - Crystal Editor Integration Main Screen Panel
# =============================================================================
# 100% Pure Crystal Node implementing the "Crystal" main dock tab.
# Provides build controls, recompilable addon management, Crystal log output,
# and an interactive unit test runner hooking into Crystal's spec framework.

require "../lapis"
require "json"
require "./async_command_runner"
require "./toolchain"
require "./benchmark_graph_control"

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
    @benchmarks_all_lang_chk : CheckBox? = nil
    @benchmark_graph : BenchmarkGraphControl? = nil

    # Doctor GUI fields
    @doctor_tree : Tree? = nil
    @doctor_status_lbl : Label? = nil
    @doctor_log : RichTextLabel? = nil

    # Shards GUI fields
    @shards_tree : Tree? = nil
    @shards_status_lbl : Label? = nil
    @shards_log : RichTextLabel? = nil

    # ClassDB GUI fields
    @classdb_tree : Tree? = nil
    @classdb_filter : LineEdit? = nil

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
      refresh_doctor_list
      refresh_shards_list
      refresh_classdb_list
      refresh_log_view
    end

    def _physics_process(delta : Float64) : Void
      AsyncCommandRunner.instance.poll
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
      create_doctor_tab(tabs)
      create_shards_tab(tabs)
      create_classdb_tab(tabs)
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

        chk_all = Godot.create(Godot::CheckBox)
        if chk_all
          chk_all.call("set_text", "All Languages")
          chk_all.call("set_tooltip_text", "Include C++, Rust, C# along with Crystal and GDScript")
          chk_all.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          @benchmarks_all_lang_chk = chk_all
          ctrl_row.call("add_child", chk_all)
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

        bench_subtabs = Godot.create(Godot::TabContainer)
        if bench_subtabs
          bench_subtabs.call("set_h_size_flags", 3)
          bench_subtabs.call("set_v_size_flags", 3)

          # Subtab 1: Visual Comparison Graphs
          graph_scroll = Godot.create(Godot::ScrollContainer)
          if graph_scroll
            graph_scroll.call("set_name", "Visual Comparison")
            graph_scroll.call("set_h_size_flags", 3)
            graph_scroll.call("set_v_size_flags", 3)

            graph_ctrl = Godot.create("BenchmarkGraphControl")
            if graph_ctrl
              graph_scroll.call("add_child", graph_ctrl)
              @benchmark_graph = graph_ctrl.as?(BenchmarkGraphControl) || BenchmarkGraphControl.new(graph_ctrl.pointer)
            end
            bench_subtabs.call("add_child", graph_scroll)
          end

          # Subtab 2: Data Table
          tree = Godot.create(Godot::Tree)
          if tree
            tree.call("set_name", "Data Table")
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
            bench_subtabs.call("add_child", tree)
          end

          split.call("add_child", bench_subtabs)
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

    # --- Tab 6: Doctor & Diagnostics ---
    def create_doctor_tab(tabs : Node) : Void
      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "Doctor & Health")
      vbox.call("add_theme_constant_override", "separation", 10)

      top_row = Godot.create(Godot::HBoxContainer)
      if top_row
        top_row.call("add_theme_constant_override", "separation", 10)

        lbl = Godot.create(Godot::Label)
        if lbl
          lbl.call("set_text", "Lapis Development Environment & Toolchain Diagnostics:")
          lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          top_row.call("add_child", lbl)
        end

        spacer = Godot.create(Godot::Control)
        spacer.call("set_h_size_flags", 3_i64) if spacer
        top_row.call("add_child", spacer) if spacer

        btn_run = Godot.create(Godot::Button)
        if btn_run
          btn_run.call("set_text", "Run Diagnostics")
          btn_run.connect("pressed") { refresh_doctor_list }
          top_row.call("add_child", btn_run)
        end

        btn_fix = Godot.create(Godot::Button)
        if btn_fix
          btn_fix.call("set_text", "Autofix Environment")
          btn_fix.call("add_theme_color_override", "font_color", Color.new(0.4_f32, 1.0_f32, 0.6_f32, 1.0_f32))
          btn_fix.connect("pressed") { on_run_doctor_autofix }
          top_row.call("add_child", btn_fix)
        end

        [btn_run, btn_fix].each do |b|
          next unless b
          b.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        end

        vbox.call("add_child", top_row)
      end

      split = Godot.create(Godot::VSplitContainer)
      if split
        split.call("set_h_size_flags", 3_i64)
        split.call("set_v_size_flags", 3_i64)

        tree = Godot.create(Godot::Tree)
        if tree
          tree.call("set_h_size_flags", 3_i64)
          tree.call("set_v_size_flags", 3_i64)
          tree.call("set_columns", 3)
          tree.call("set_column_title", 0, "Diagnostic Check")
          tree.call("set_column_title", 1, "Status")
          tree.call("set_column_title", 2, "Details & Recommendations")
          tree.call("set_column_titles_visible", true)
          tree.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          tree.call("add_theme_color_override", "title_button_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          @doctor_tree = tree
          split.call("add_child", tree)
        end

        log_box = Godot.create(Godot::RichTextLabel)
        if log_box
          log_box.call("set_h_size_flags", 3_i64)
          log_box.call("set_v_size_flags", 3_i64)
          log_box.call("set_use_bbcode", true)
          log_box.call("set_selection_enabled", true)
          log_box.call("add_theme_color_override", "default_color", Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
          log_box.call("set_text", "[color=#8b949e]Diagnostic logs and autofix remediation details will stream here.[/color]")
          @doctor_log = log_box
          split.call("add_child", log_box)
        end

        vbox.call("add_child", split)
      end

      tabs.call("add_child", vbox)
    end

    # --- Tab 7: Shards & Dependencies ---
    def create_shards_tab(tabs : Node) : Void
      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "Shards & Dependencies")
      vbox.call("add_theme_constant_override", "separation", 10)

      top_row = Godot.create(Godot::HBoxContainer)
      if top_row
        top_row.call("add_theme_constant_override", "separation", 10)

        lbl = Godot.create(Godot::Label)
        if lbl
          lbl.call("set_text", "Project Dependencies (shard.yml):")
          lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          top_row.call("add_child", lbl)
        end

        spacer = Godot.create(Godot::Control)
        spacer.call("set_h_size_flags", 3_i64) if spacer
        top_row.call("add_child", spacer) if spacer

        btn_install = Godot.create(Godot::Button)
        if btn_install
          btn_install.call("set_text", "Install Shards (shards install)")
          btn_install.connect("pressed") { on_shards_install }
          top_row.call("add_child", btn_install)
        end

        btn_update = Godot.create(Godot::Button)
        if btn_update
          btn_update.call("set_text", "Update Shards (shards update)")
          btn_update.connect("pressed") { on_shards_update }
          top_row.call("add_child", btn_update)
        end

        btn_refresh = Godot.create(Godot::Button)
        if btn_refresh
          btn_refresh.call("set_text", "Refresh")
          btn_refresh.connect("pressed") { refresh_shards_list }
          top_row.call("add_child", btn_refresh)
        end

        [btn_install, btn_update, btn_refresh].each do |b|
          next unless b
          b.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        end

        vbox.call("add_child", top_row)
      end

      split = Godot.create(Godot::VSplitContainer)
      if split
        split.call("set_h_size_flags", 3_i64)
        split.call("set_v_size_flags", 3_i64)

        tree = Godot.create(Godot::Tree)
        if tree
          tree.call("set_h_size_flags", 3_i64)
          tree.call("set_v_size_flags", 3_i64)
          tree.call("set_columns", 4)
          tree.call("set_column_title", 0, "Dependency Name")
          tree.call("set_column_title", 1, "Requirement")
          tree.call("set_column_title", 2, "Status in lib/")
          tree.call("set_column_title", 3, "Source")
          tree.call("set_column_titles_visible", true)
          tree.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          tree.call("add_theme_color_override", "title_button_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          @shards_tree = tree
          split.call("add_child", tree)
        end

        log_box = Godot.create(Godot::RichTextLabel)
        if log_box
          log_box.call("set_h_size_flags", 3_i64)
          log_box.call("set_v_size_flags", 3_i64)
          log_box.call("set_use_bbcode", true)
          log_box.call("set_selection_enabled", true)
          log_box.call("add_theme_color_override", "default_color", Color.new(0.95_f32, 0.95_f32, 0.95_f32, 1.0_f32))
          log_box.call("set_text", "[color=#8b949e]Shards operations output and dependency tree info will stream here.[/color]")
          @shards_log = log_box
          split.call("add_child", log_box)
        end

        vbox.call("add_child", split)
      end

      tabs.call("add_child", vbox)
    end

    # --- Tab 8: ClassDB Registry ---
    def create_classdb_tab(tabs : Node) : Void
      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_name", "ClassDB Registry")
      vbox.call("add_theme_constant_override", "separation", 10)

      top_row = Godot.create(Godot::HBoxContainer)
      if top_row
        top_row.call("add_theme_constant_override", "separation", 10)

        lbl = Godot.create(Godot::Label)
        if lbl
          lbl.call("set_text", "Registered Crystal Classes & Reflection in ClassDB:")
          lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          top_row.call("add_child", lbl)
        end

        spacer = Godot.create(Godot::Control)
        spacer.call("set_h_size_flags", 3_i64) if spacer
        top_row.call("add_child", spacer) if spacer

        filter_edit = Godot.create(Godot::LineEdit)
        if filter_edit
          filter_edit.call("set_placeholder_text", "Filter classes or properties...")
          filter_edit.call("set_custom_minimum_size", Vector2.new(220_f32, 0_f32))
          filter_edit.connect("text_changed") { |_args| refresh_classdb_list }
          top_row.call("add_child", filter_edit)
          @classdb_filter = filter_edit
        end

        btn_refresh = Godot.create(Godot::Button)
        if btn_refresh
          btn_refresh.call("set_text", "Refresh List")
          btn_refresh.connect("pressed") { refresh_classdb_list }
          top_row.call("add_child", btn_refresh)
        end

        vbox.call("add_child", top_row)
      end

      tree = Godot.create(Godot::Tree)
      if tree
        tree.call("set_h_size_flags", 3_i64)
        tree.call("set_v_size_flags", 3_i64)
        tree.call("set_columns", 3)
        tree.call("set_column_title", 0, "Class / Member Name")
        tree.call("set_column_title", 1, "Category / Type")
        tree.call("set_column_title", 2, "Inheritance / Signature / Hints")
        tree.call("set_column_titles_visible", true)
        tree.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        tree.call("add_theme_color_override", "title_button_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        @classdb_tree = tree
        vbox.call("add_child", tree)
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
      if AsyncCommandRunner.instance.running?
        log_warn("A command (#{AsyncCommandRunner.instance.active_command_name}) is already running!")
        return
      end

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
      log_info("Executing asynchronously: crystal #{args.join(" ")}")

      started = AsyncCommandRunner.instance.run(
        name: "Crystal Build (#{is_release ? "Release" : "Debug"})",
        command: "crystal",
        args: args,
        env: compiler_env,
        on_line: ->(line : String) {
          if line.includes?("error") || line.includes?("Error")
            log_error("  #{line}")
          else
            append_log("  [color=#ffffff]#{line}[/color]")
          end
          nil
        }
      ) do |exit_code, elapsed_sec, output_str|
        if exit_code == 0
          log_success("Game library built successfully in #{elapsed_sec.round(2)}s -> #{out_lib}")
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
          log_error("Crystal build failed with exit code #{exit_code} after #{elapsed_sec.round(2)}s.")
          CrystalIntegrationPlugin.report_build_failure("Crystal build", output_str, output_str, exit_code)
        end
      end

      unless started
        log_warn("Failed to launch background build process.")
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
      if AsyncCommandRunner.instance.running?
        log_warn("A command is already running (#{AsyncCommandRunner.instance.active_command_name})")
        return
      end

      log_info("Executing Crystal unit test specifications...")
      @test_status_label.try do |lbl|
        lbl.call("set_text", "Running crystal spec in background...")
        lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 0.85_f32, 0.2_f32, 1.0_f32))
      end

      # Mark all items as running
      if run_tree = @test_tree
        if running_root = run_tree.call_obj("get_root")
          update_tree_item_status_recursive(running_root, "[⏳ Running...]", Color.new(1.0_f32, 0.85_f32, 0.2_f32, 1.0_f32))
        end
      end

      spec_dir, cwd = resolve_spec_context

      started = AsyncCommandRunner.instance.run(
        name: "Crystal Specs",
        command: "crystal",
        args: ["spec", "--no-color"],
        chdir: cwd,
        on_line: ->(l : String) {
          append_log("  [color=#ffffff]#{l}[/color]")
          nil
        }
      ) do |exit_code, elapsed_sec, output_text|
        elapsed = elapsed_sec.round(2)
        passed = (exit_code == 0)

        @test_details.try do |details|
          if passed
            details.call("set_text", "[color=#44ff88][b]All Crystal specifications passed successfully![/b][/color]\n[color=#ffffff]Execution Time: #{elapsed}s[/color]\n\n[color=#f5f5f5]#{output_text}[/color]")
          else
            details.call("set_text", "[color=#ff4444][b]Specification Failures Detected:[/b][/color]\n[color=#ffffff]Execution Time: #{elapsed}s[/color]\n\n[color=#ff8888]#{output_text}[/color]")
          end
        end

        if res_tree = @test_tree
          if res_root = res_tree.call_obj("get_root")
            status_str = passed ? "[✅ PASSED]" : "[❌ FAILED]"
            status_col = passed ? Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32) : Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32)
            update_tree_item_status_recursive(res_root, status_str, status_col)
          end
        end

        @test_status_label.try do |finish_lbl|
          if passed
            finish_lbl.call("set_text", "✅ All specifications passed cleanly in #{elapsed}s!")
            finish_lbl.call("add_theme_color_override", "font_color", Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32))
            log_success("All specifications passed cleanly in #{elapsed}s!")
          else
            finish_lbl.call("set_text", "❌ Failures detected in #{elapsed}s. See details below.")
            finish_lbl.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32))
            log_error("Specification failures detected in #{elapsed}s.")
          end
        end
      end

      unless started
        log_warn("Failed to launch background spec runner.")
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
      if AsyncCommandRunner.instance.running?
        log_warn("A command is already running (#{AsyncCommandRunner.instance.active_command_name})")
        return
      end

      log_info("Starting Lapis benchmark execution...")
      @benchmarks_status_label.try &.call("set_text", "Executing benchmarks in background...")
      @benchmark_graph.try &.clear_entries

      iters = 3
      if spin = @benchmarks_iterations_spin
        iters = spin.call_f64("get_value").to_i
      end

      lapis_exe = find_lapis_executable || "lapis"
      args = ["benchmarks", "run", "html", "-i", iters.to_s, "--no-tui"]
      args += ["-g", group_name] if group_name
      args += ["-f", benchmark_name] if benchmark_name

      if @benchmarks_all_lang_chk.try(&.call_bool("is_pressed"))
        args << "--all-languages"
      end

      if log_box = @benchmarks_log
        log_box.call("set_text", "[color=#00d2ff]━━━ Starting Benchmark Execution (Iterations: #{iters}) ━━━[/color]\n")
      end

      started = AsyncCommandRunner.instance.run(
        name: "Lapis Benchmarks",
        command: lapis_exe,
        args: args,
        on_line: ->(line : String) {
          @benchmarks_log.try &.call("append_text", "#{line}\n")
          nil
        }
      ) do |exit_code, elapsed_sec, out_str|
        elapsed = elapsed_sec.round(2)
        if exit_code == 0
          log_success("Benchmark execution completed in #{elapsed}s!")
          @benchmarks_status_label.try &.call("set_text", "Benchmarks complete! HTML & XML reports updated (#{elapsed}s).")
          latest_xml = "benchmarks/reports/benchmarks_latest.xml"
          if File.exists?(latest_xml)
            populate_benchmark_results_from_xml(latest_xml)
          end
        else
          log_error("Benchmark execution finished with exit code #{exit_code}.")
          @benchmarks_status_label.try &.call("set_text", "Benchmark run failed. Check Benchmark Log below.")
        end
        append_log(out_str)
      end

      unless started
        log_warn("Failed to launch background benchmark runner.")
      end
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

        # Update visual comparison graph
        if graph = @benchmark_graph
          graph.add_comparison(
            name: c_name,
            crystal_ms: cr_ms.to_f? || 0.0,
            gdscript_ms: gd_ms.try(&.to_f?),
            cpp_ms: cpp_ms.try(&.to_f?),
            rust_ms: rs_ms.try(&.to_f?),
            speedup: sp.try(&.to_f?)
          )
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

    # =========================================================================
    # Doctor & Diagnostics Operations
    # =========================================================================

    def refresh_doctor_list : Void
      tree = @doctor_tree
      return unless tree
      tree.call("clear")

      root = tree.call_obj("create_item")
      return unless root
      root.call("set_text", 0, "Lapis Development Environment Health")
      root.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))

      checks = [] of Tuple(String, Symbol, String)

      # 1. Crystal Compiler
      if cr_exe = Process.find_executable("crystal")
        ver_io = IO::Memory.new
        Process.run(cr_exe, ["--version"], output: ver_io, error: ver_io) rescue nil
        ver_str = ver_io.to_s.lines.first?.try(&.strip) || "Installed"
        checks << {"Crystal Compiler", :pass, "#{cr_exe} (#{ver_str})"}
      else
        checks << {"Crystal Compiler", :fail, "Not found in PATH. Install Crystal 1.20+"}
      end

      # 2. Godot Engine Binary
      godot_candidates = [
        "godot.exe", "godot",
        "bin/godot.exe", "bin/godot",
        "../bin/godot.exe", "../bin/godot",
      ]
      found_godot = godot_candidates.find { |p| File.exists?(p) } || Process.find_executable("godot")
      if found_godot
        checks << {"Godot Engine Binary", :pass, "Detected at #{found_godot}"}
      else
        checks << {"Godot Engine Binary", :warn, "Not found in PATH or bin/. Launching via editor host."}
      end

      # 3. C++ Toolchain
      cxx_candidates = {% if flag?(:windows) %} ["g++", "clang++", "cl"] {% else %} ["g++", "clang++"] {% end %}
      found_cxx = cxx_candidates.find { |c| Process.find_executable(c) }
      if found_cxx
        checks << {"C++ Compiler (#{found_cxx})", :pass, "Available for compiling crystal_bridge and C++ extensions."}
      else
        checks << {"C++ Compiler", :warn, "No C++ compiler found (g++/clang++/cl). Needed if rebuilding bridge DLL."}
      end

      # 4. GNU Make
      if Process.find_executable("make")
        checks << {"GNU Make", :pass, "make tool found in PATH for 'make all' orchestration."}
      else
        checks << {"GNU Make", :warn, "make not found in PATH. Use 'lapis build' or install make."}
      end

      # 5. Radare2 Debugger
      if Process.find_executable("r2")
        checks << {"Radare2 Debugger (r2)", :pass, "Installed for native crash forensics and debugging."}
      else
        checks << {"Radare2 Debugger (r2)", :warn, "Optional: 'r2' not in PATH. Install radare2 for native crash forensics."}
      end

      # 6. Shards Package Manager
      if Process.find_executable("shards")
        checks << {"Shards Package Manager", :pass, "shards CLI ready for shard.yml dependency resolution."}
      else
        checks << {"Shards Package Manager", :fail, "shards CLI not found in PATH."}
      end

      # 7. Runtime DLLs / Shared Libraries
      required_libs = {% if flag?(:windows) %}
        ["gc.dll", "libgodot.dll", "crystal_bridge.dll"]
      {% else %}
        ["libgodot.so", "crystal_bridge.so"]
      {% end %}
      missing_libs = required_libs.reject { |lib_name| File.exists?("bin/#{lib_name}") || File.exists?("../bin/#{lib_name}") || File.exists?("addons/crystal_integration/bin/#{lib_name}") }
      if missing_libs.empty?
        checks << {"Runtime Shared Libraries", :pass, "All essential runtime DLLs/libraries present."}
      else
        checks << {"Runtime Shared Libraries", :fail, "Missing runtime libraries in bin/: #{missing_libs.join(", ")}"}
      end

      # 8. Lapis CLI Toolchain
      if lapis_path = find_lapis_executable
        checks << {"Lapis CLI Toolchain", :pass, "Resolved at #{lapis_path}"}
      else
        checks << {"Lapis CLI Toolchain", :warn, "lapis binary not found. Build via 'make lapis' or run 'crystal src/main.cr'."}
      end

      pass_count = 0
      warn_count = 0
      fail_count = 0

      checks.each do |(name, status, details)|
        item = tree.call_obj("create_item", root)
        next unless item
        item.call("set_text", 0, name)
        item.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))

        case status
        when :pass
          pass_count += 1
          item.call("set_text", 1, "✔ PASSED")
          item.call("set_custom_color", 1, Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32))
        when :warn
          warn_count += 1
          item.call("set_text", 1, "⚠ WARNING")
          item.call("set_custom_color", 1, Color.new(1.0_f32, 0.75_f32, 0.2_f32, 1.0_f32))
        when :fail
          fail_count += 1
          item.call("set_text", 1, "✘ FAILED")
          item.call("set_custom_color", 1, Color.new(1.0_f32, 0.3_f32, 0.3_f32, 1.0_f32))
        end

        item.call("set_text", 2, details)
        item.call("set_custom_color", 2, Color.new(0.85_f32, 0.85_f32, 0.9_f32, 1.0_f32))
      end

      if log_box = @doctor_log
        summary_color = fail_count > 0 ? "#ff4444" : (warn_count > 0 ? "#ffaa00" : "#44ff88")
        log_box.call("set_text", "[color=#{summary_color}][b]Diagnostics Summary: #{pass_count} passed, #{warn_count} warnings, #{fail_count} failed.[/b][/color]\n[color=#8b949e]Click 'Autofix Environment' to automatically remediate detectable gaps or missing components.[/color]\n")
      end
    end

    def on_run_doctor_autofix : Void
      if AsyncCommandRunner.instance.running?
        log_warn("A command is already running (#{AsyncCommandRunner.instance.active_command_name})")
        return
      end

      lapis_exe = find_lapis_executable || "lapis"
      if log_box = @doctor_log
        log_box.call("append_text", "[color=#00d2ff]━━━ Executing lapis doctor autofix ━━━[/color]\n")
      end

      started = AsyncCommandRunner.instance.run(
        name: "Doctor Autofix",
        command: lapis_exe,
        args: ["doctor", "autofix"],
        on_line: ->(line : String) {
          @doctor_log.try &.call("append_text", "#{line}\n")
          nil
        }
      ) do |exit_code, elapsed_sec, out_str|
        if exit_code == 0
          log_success("Doctor autofix completed successfully (#{elapsed_sec.round(2)}s).")
        else
          log_warn("Doctor autofix completed with exit code #{exit_code}.")
        end
        refresh_doctor_list
      end

      unless started
        log_warn("Failed to launch background doctor autofix process.")
      end
    end

    # =========================================================================
    # Shards & Dependencies Operations
    # =========================================================================

    def refresh_shards_list : Void
      tree = @shards_tree
      return unless tree
      tree.call("clear")

      root = tree.call_obj("create_item")
      return unless root
      root.call("set_text", 0, "shard.yml Dependencies")
      root.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))

      shard_file = ["shard.yml", "../shard.yml"].find { |f| File.exists?(f) }
      unless shard_file
        if log_box = @shards_log
          log_box.call("set_text", "[color=#ffaa00]No shard.yml detected in project or parent directory.[/color]")
        end
        return
      end

      in_deps = false
      in_dev_deps = false
      dep_count = 0

      current_name = ""
      current_req = ""
      current_src = ""

      commit_dep = ->(section : String) {
        return if current_name.empty?
        dep_count += 1
        item = tree.call_obj("create_item", root)
        if item
          item.call("set_text", 0, "#{current_name} (#{section})")
          item.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          item.call("set_text", 1, current_req.empty? ? "*" : current_req)
          item.call("set_custom_color", 1, Color.new(0.6_f32, 0.85_f32, 1.0_f32, 1.0_f32))

          lib_dir = ["lib/#{current_name}", "../lib/#{current_name}"].find { |d| Dir.exists?(d) }
          if lib_dir
            item.call("set_text", 2, "✔ Installed")
            item.call("set_custom_color", 2, Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32))
          else
            item.call("set_text", 2, "✘ Missing")
            item.call("set_custom_color", 2, Color.new(1.0_f32, 0.4_f32, 0.4_f32, 1.0_f32))
          end

          item.call("set_text", 3, current_src)
          item.call("set_custom_color", 3, Color.new(0.8_f32, 0.8_f32, 0.9_f32, 1.0_f32))
        end
        current_name = ""
        current_req = ""
        current_src = ""
      }

      current_section = "Runtime"
      File.each_line(shard_file) do |line|
        trimmed = line.strip
        if trimmed == "dependencies:"
          commit_dep.call(current_section)
          in_deps = true
          in_dev_deps = false
          current_section = "Runtime"
          next
        elsif trimmed == "development_dependencies:"
          commit_dep.call(current_section)
          in_deps = false
          in_dev_deps = true
          current_section = "Dev"
          next
        elsif !line.starts_with?(" ") && !line.starts_with?("\t") && trimmed.includes?(":")
          commit_dep.call(current_section)
          in_deps = false
          in_dev_deps = false
          next
        end

        next unless in_deps || in_dev_deps

        if line =~ /^[ \t]{2}([A-Za-z0-9_-]+):/
          commit_dep.call(current_section)
          current_name = $1
        elsif line =~ /^[ \t]{4}github:\s*([^\s#]+)/
          current_src = "github: #{$1}"
        elsif line =~ /^[ \t]{4}path:\s*([^\s#]+)/
          current_src = "path: #{$1}"
        elsif line =~ /^[ \t]{4}version:\s*["']?([^"'#]+)["']?/
          current_req = $1.strip
        end
      end
      commit_dep.call(current_section)

      if log_box = @shards_log
        log_box.call("set_text", "[color=#8b949e]Found #{dep_count} dependencies in #{shard_file}. Click 'Install Shards' to resolve or 'Update Shards' to fetch latest versions.[/color]\n")
      end
    end

    def on_shards_install : Void
      if AsyncCommandRunner.instance.running?
        log_warn("A command is already running (#{AsyncCommandRunner.instance.active_command_name})")
        return
      end

      if log_box = @shards_log
        log_box.call("append_text", "[color=#00d2ff]━━━ Executing shards install ━━━[/color]\n")
      end

      started = AsyncCommandRunner.instance.run(
        name: "Shards Install",
        command: "shards",
        args: ["install"],
        on_line: ->(line : String) {
          @shards_log.try &.call("append_text", "#{line}\n")
          nil
        }
      ) do |exit_code, elapsed_sec, out_str|
        if exit_code == 0
          log_success("shards install finished successfully (#{elapsed_sec.round(2)}s).")
        else
          log_error("shards install failed with code #{exit_code}.")
        end
        refresh_shards_list
      end

      unless started
        log_warn("Failed to launch shards install.")
      end
    end

    def on_shards_update : Void
      if AsyncCommandRunner.instance.running?
        log_warn("A command is already running (#{AsyncCommandRunner.instance.active_command_name})")
        return
      end

      if log_box = @shards_log
        log_box.call("append_text", "[color=#00d2ff]━━━ Executing shards update ━━━[/color]\n")
      end

      started = AsyncCommandRunner.instance.run(
        name: "Shards Update",
        command: "shards",
        args: ["update"],
        on_line: ->(line : String) {
          @shards_log.try &.call("append_text", "#{line}\n")
          nil
        }
      ) do |exit_code, elapsed_sec, out_str|
        if exit_code == 0
          log_success("shards update finished successfully (#{elapsed_sec.round(2)}s).")
        else
          log_error("shards update failed with code #{exit_code}.")
        end
        refresh_shards_list
      end

      unless started
        log_warn("Failed to launch shards update.")
      end
    end

    # =========================================================================
    # ClassDB Registry Operations
    # =========================================================================

    def refresh_classdb_list : Void
      tree = @classdb_tree
      return unless tree
      tree.call("clear")

      root = tree.call_obj("create_item")
      return unless root
      root.call("set_text", 0, "Registered Classes in ClassDB")
      root.call("set_custom_color", 0, Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))

      cdb_ptr = Bridge.get_singleton("ClassDB")
      return if cdb_ptr.null?
      cdb = Godot::ClassDB.new(cdb_ptr)

      filter_text = @classdb_filter.try(&.call_str("get_text").strip.downcase) || ""

      # Category roots
      ext_root = tree.call_obj("create_item", root)
      if ext_root
        ext_root.call("set_text", 0, "Crystal & GDExtension Classes")
        ext_root.call("set_custom_color", 0, Color.new(0.0_f32, 0.85_f32, 1.0_f32, 1.0_f32))
      end

      editor_root = tree.call_obj("create_item", root)
      if editor_root
        editor_root.call("set_text", 0, "Editor Classes")
        editor_root.call("set_custom_color", 0, Color.new(1.0_f32, 0.8_f32, 0.3_f32, 1.0_f32))
      end

      core_root = tree.call_obj("create_item", root)
      if core_root
        core_root.call("set_text", 0, "Godot Core Classes")
        core_root.call("set_custom_color", 0, Color.new(0.7_f32, 0.7_f32, 0.8_f32, 1.0_f32))
      end

      known_crystal_classes = [
        "CrystalPanel", "CrystalConsoleDock", "BenchmarkGraphControl",
        "CrystalIntegrationPlugin", "CrystalDebuggerPlugin", "CrystalLanguage", "CrystalScript",
        "ToolTester2D", "ToolTester3D", "RunTesterPanel",
        "DummyDialoguePlugin", "DummyInventoryPlugin", "DummyAudioPlugin"
      ]

      # Find additional custom classes declared in src/
      if Dir.exists?("src")
        Dir.glob("src/**/*.cr").each do |cr_file|
          File.each_line(cr_file) do |line|
            if line =~ /^\s*(?:@\[Tool\]\s*)?node\s+([A-Za-z0-9_]+)\s*</
              cls = $1
              known_crystal_classes << cls unless known_crystal_classes.includes?(cls)
            elsif line =~ /^\s*class\s+([A-Za-z0-9_]+)\s*<\s*Godot::/
              cls = $1
              known_crystal_classes << cls unless known_crystal_classes.includes?(cls)
            end
          end
        rescue
        end
      end

      common_engine_classes = [
        "Node", "Node2D", "Node3D", "CanvasItem", "Control",
        "CharacterBody2D", "CharacterBody3D", "RigidBody2D", "RigidBody3D",
        "StaticBody2D", "StaticBody3D", "Area2D", "Area3D", "Camera2D", "Camera3D",
        "Resource", "RefCounted", "PackedScene", "AudioStream", "Texture2D",
        "MeshInstance3D", "AnimationPlayer", "Timer", "CollisionShape2D", "CollisionShape3D",
        "Sprite2D", "Sprite3D", "Label", "Button", "Tree", "RichTextLabel",
        "ProgressBar", "LineEdit", "TextEdit", "CodeEdit", "EditorPlugin",
        "EditorInterface", "ScriptEditor", "EditorFileSystem"
      ]

      all_candidates = (known_crystal_classes + common_engine_classes).uniq

      all_candidates.each do |c_name|
        next if !filter_text.empty? && !c_name.downcase.includes?(filter_text)
        next unless cdb.class_exists(c_name)

        is_crystal = known_crystal_classes.includes?(c_name)
        is_editor = c_name.starts_with?("Editor") && !is_crystal
        parent = cdb.get_parent_class(c_name) rescue ""

        target_parent = if is_crystal
                          ext_root
                        elsif is_editor
                          editor_root
                        else
                          core_root
                        end
        next unless target_parent

        item = tree.call_obj("create_item", target_parent)
        next unless item
        item.call("set_text", 0, c_name)
        item.call("set_custom_color", 0, is_crystal ? Color.new(0.4_f32, 0.9_f32, 1.0_f32, 1.0_f32) : Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))

        cat_desc = is_crystal ? "Crystal Extension" : (is_editor ? "Editor Class" : "Core Engine")
        item.call("set_text", 1, cat_desc)
        item.call("set_custom_color", 1, Color.new(0.6_f32, 0.8_f32, 1.0_f32, 1.0_f32))

        item.call("set_text", 2, "< #{parent}")
        item.call("set_custom_color", 2, Color.new(0.8_f32, 0.8_f32, 0.8_f32, 1.0_f32))
      end
    end
  end
end

alias CrystalPanel = Lapis::CrystalPanel

module Godot
  alias CrystalPanel = ::Lapis::CrystalPanel
end
