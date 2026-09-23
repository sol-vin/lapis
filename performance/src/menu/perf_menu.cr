# =============================================================================
# LibGodot Performance Benchmark - Interactive Selection Menu
# =============================================================================

require "lapis"
require "../framework/perf_registry"
require "../framework/perf_hud"

module PerfFramework
  class TestCard
    getter container : Godot::PanelContainer
    getter test_def : TestDefinition
    getter btn_run : Godot::Button
    getter spin_count : Godot::SpinBox
    getter spin_duration : Godot::SpinBox
    getter check_infinite : Godot::CheckBox

    def initialize(parent : Godot::Node, @test_def : TestDefinition, &on_run : (TestDefinition, Int32, Float64, Bool) -> Void)
      @container = Godot.create(Godot::PanelContainer)
      @container.set_h_size_flags(3_i64) # SIZE_EXPAND_FILL
      @container.set_custom_minimum_size(Godot::Vector2.new(340.0, 150.0))
      parent.add_child(@container)

      vbox = Godot.create(Godot::VBoxContainer)
      vbox.set_h_size_flags(3_i64)
      @container.add_child(vbox)

      # Title & Category
      header = Godot.create(Godot::HBoxContainer)
      header.set_h_size_flags(3_i64)
      vbox.add_child(header)

      lbl_title = Godot.create(Godot::Label)
      lbl_title.call("set_text", @test_def.title)
      header.add_child(lbl_title)

      spacer = Godot.create(Godot::Control)
      spacer.set_h_size_flags(3_i64)
      header.add_child(spacer)

      lbl_cat = Godot.create(Godot::Label)
      lbl_cat.call("set_text", "[#{@test_def.category}]")
      header.add_child(lbl_cat)

      # Description
      lbl_desc = Godot.create(Godot::Label)
      lbl_desc.call("set_text", @test_def.description)
      lbl_desc.call("set_autowrap_mode", 3_i64) # AUTOWRAP_WORD_SMART
      lbl_desc.set_h_size_flags(3_i64)
      vbox.add_child(lbl_desc)

      # Parameter Controls
      params_box = Godot.create(Godot::HBoxContainer)
      params_box.set_h_size_flags(3_i64)
      vbox.add_child(params_box)

      lbl_c = Godot.create(Godot::Label)
      lbl_c.call("set_text", "Count:")
      params_box.add_child(lbl_c)

      @spin_count = Godot.create(Godot::SpinBox)
      @spin_count.set_min(100.0)
      @spin_count.set_max(50000.0)
      @spin_count.set_step(100.0)
      @spin_count.set_value(@test_def.default_count.to_f64)
      params_box.add_child(@spin_count)

      lbl_d = Godot.create(Godot::Label)
      lbl_d.call("set_text", "Dur (s):")
      params_box.add_child(lbl_d)

      @spin_duration = Godot.create(Godot::SpinBox)
      @spin_duration.set_min(2.0)
      @spin_duration.set_max(600.0)
      @spin_duration.set_step(5.0)
      @spin_duration.set_value(@test_def.default_duration)
      params_box.add_child(@spin_duration)

      @check_infinite = Godot.create(Godot::CheckBox)
      @check_infinite.call("set_text", "∞ Infinite")
      params_box.add_child(@check_infinite)

      # Run Button
      btn_spacer = Godot.create(Godot::Control)
      btn_spacer.set_h_size_flags(3_i64)
      params_box.add_child(btn_spacer)

      @btn_run = Godot.create(Godot::Button)
      @btn_run.call("set_text", "▶ Run #{@test_def.id}")
      @btn_run.connect("pressed") do
        count = @spin_count.get_value.to_i32 rescue @test_def.default_count
        dur = @spin_duration.get_value rescue @test_def.default_duration
        is_inf = @check_infinite.is_pressed rescue false
        Godot.print("[PerfMenu] Card '#{@test_def.id}' clicked -> count=#{count} dur=#{dur} inf=#{is_inf}")
        on_run.call(@test_def, count, dur, is_inf)
      end
      params_box.add_child(@btn_run)
    end
  end

  node PerfMenu < Godot::Control do
    property on_launch_test : Proc(TestDefinition, Int32, Float64, Bool, Void)?
    property on_launch_all : Proc(Void)?

    @cards = Array(TestCard).new
    @dropdown : Godot::OptionButton?
    @spin_quick_count : Godot::SpinBox?
    @spin_quick_duration : Godot::SpinBox?
    @check_quick_infinite : Godot::CheckBox?

    def _ready : Void
      build_menu
    end

    def build_menu : Void
      # Dock below HUD (HUD occupies top ~195px), stretching to fill the remaining window
      set_anchors_preset(15_i64, false)    # PRESET_FULL_RECT
      set_anchor(0_i64, 0.0, false, false) # Left
      set_anchor(1_i64, 0.0, false, false) # Top
      set_anchor(2_i64, 1.0, false, false) # Right
      set_anchor(3_i64, 1.0, false, false) # Bottom
      set_offset(0_i64, 16.0)              # Left margin
      set_offset(1_i64, 208.0)             # Top offset (below HUD)
      set_offset(2_i64, -16.0)             # Right margin
      set_offset(3_i64, -12.0)             # Bottom margin
      set_h_size_flags(3_i64)              # SIZE_EXPAND_FILL
      set_v_size_flags(3_i64)              # SIZE_EXPAND_FILL

      root_vbox = Godot.create(Godot::VBoxContainer)
      root_vbox.set_anchors_preset(15_i64, false)
      root_vbox.set_h_size_flags(3_i64)
      root_vbox.set_v_size_flags(3_i64)
      add_child(root_vbox)

      # -------------------------------------------------------------------------
      # 1. Top Quick Selector Bar with OptionButton Dropdown
      # -------------------------------------------------------------------------
      top_panel = Godot.create(Godot::PanelContainer)
      top_panel.set_h_size_flags(3_i64)
      root_vbox.add_child(top_panel)

      top_bar = Godot.create(Godot::HBoxContainer)
      top_bar.set_h_size_flags(3_i64)
      top_panel.add_child(top_bar)

      lbl_pick = Godot.create(Godot::Label)
      lbl_pick.call("set_text", "⚡ Select Test:")
      top_bar.add_child(lbl_pick)

      # OptionButton Dropdown
      opt = Godot.create(Godot::OptionButton)
      opt.set_h_size_flags(3_i64) # Expand to take available horizontal space
      opt.call("add_item", "⚡ [0] Run All Tests Sequentially (Full Benchmark Suite)", 0_i64)

      all_tests = TestRegistry.all
      all_tests.each_with_index do |tdef, idx|
        opt.call("add_item", "[#{idx + 1}] #{tdef.title} (#{tdef.category})", (idx + 1).to_i64)
      end
      top_bar.add_child(opt)
      @dropdown = opt

      # Quick Count
      lbl_qc = Godot.create(Godot::Label)
      lbl_qc.call("set_text", "Count:")
      top_bar.add_child(lbl_qc)

      sp_count = Godot.create(Godot::SpinBox)
      sp_count.set_min(100.0)
      sp_count.set_max(50000.0)
      sp_count.set_step(100.0)
      sp_count.set_value(5000.0)
      top_bar.add_child(sp_count)
      @spin_quick_count = sp_count

      # Quick Duration
      lbl_qd = Godot.create(Godot::Label)
      lbl_qd.call("set_text", "Dur (s):")
      top_bar.add_child(lbl_qd)

      sp_dur = Godot.create(Godot::SpinBox)
      sp_dur.set_min(2.0)
      sp_dur.set_max(600.0)
      sp_dur.set_step(5.0)
      sp_dur.set_value(15.0)
      top_bar.add_child(sp_dur)
      @spin_quick_duration = sp_dur

      # Quick Infinite
      chk_inf = Godot.create(Godot::CheckBox)
      chk_inf.call("set_text", "∞")
      top_bar.add_child(chk_inf)
      @check_quick_infinite = chk_inf

      # Dropdown auto-update parameters
      opt.connect("item_selected") do
        sel_idx = opt.get_selected_id.to_i32 rescue 0
        if sel_idx > 0 && sel_idx <= all_tests.size
          selected_def = all_tests[sel_idx - 1]
          sp_count.set_value(selected_def.default_count.to_f64)
          sp_dur.set_value(selected_def.default_duration)
        end
      end

      # Launch Selected Button
      btn_quick_run = Godot.create(Godot::Button)
      btn_quick_run.call("set_text", "▶ Launch Selected")
      btn_quick_run.connect("pressed") do
        sel_idx = opt.get_selected_id.to_i32 rescue 0
        count = sp_count.get_value.to_i32 rescue 5000
        dur = sp_dur.get_value rescue 15.0
        is_inf = chk_inf.is_pressed rescue false

        Godot.print("[PerfMenu] Launch Selected pressed: idx=#{sel_idx} count=#{count} dur=#{dur} inf=#{is_inf}")

        if sel_idx == 0
          if cb = @on_launch_all
            cb.call
          end
        elsif sel_idx > 0 && sel_idx <= all_tests.size
          chosen_tdef = all_tests[sel_idx - 1]
          if cb = @on_launch_test
            cb.call(chosen_tdef, count, dur, is_inf)
          end
        end
      end
      top_bar.add_child(btn_quick_run)

      # Run All Button
      btn_run_all = Godot.create(Godot::Button)
      btn_run_all.call("set_text", "⚡ Run All (#{all_tests.size} Tests)")
      btn_run_all.connect("pressed") do
        Godot.print("[PerfMenu] Run All pressed")
        if cb = @on_launch_all
          cb.call
        end
      end
      top_bar.add_child(btn_run_all)

      # -------------------------------------------------------------------------
      # 2. Section Header
      # -------------------------------------------------------------------------
      lbl_section = Godot.create(Godot::Label)
      lbl_section.call("set_text", "📋 Individual Stress Test Catalog (Scroll or configure below):")
      lbl_section.set_h_size_flags(3_i64)
      root_vbox.add_child(lbl_section)

      # -------------------------------------------------------------------------
      # 3. Responsive ScrollContainer with Vertical Scrollbar
      # -------------------------------------------------------------------------
      scroll = Godot.create(Godot::ScrollContainer)
      scroll.set_h_size_flags(3_i64)                   # SIZE_EXPAND_FILL
      scroll.set_v_size_flags(3_i64)                   # SIZE_EXPAND_FILL
      scroll.call("set_horizontal_scroll_mode", 0_i64) # ScrollMode::DISABLED
      scroll.call("set_vertical_scroll_mode", 2_i64)   # ScrollMode::SHOW_ALWAYS
      root_vbox.add_child(scroll)

      # 2-column GridContainer inside ScrollContainer that expands to match window width
      grid = Godot.create(Godot::GridContainer)
      grid.call("set_columns", 2_i64)
      grid.set_h_size_flags(3_i64) # SIZE_EXPAND_FILL
      grid.set_v_size_flags(3_i64) # SIZE_EXPAND_FILL
      scroll.add_child(grid)

      @cards.clear
      all_tests.each do |tdef|
        card = TestCard.new(grid, tdef) do |chosen_def, count, dur, is_inf|
          Godot.print("[PerfMenu] Forwarding card launch: #{chosen_def.id}")
          if cb = @on_launch_test
            cb.call(chosen_def, count, dur, is_inf)
          else
            Godot.printerr("[PerfMenu ERROR] @on_launch_test callback was not set!")
          end
        end
        @cards << card
      end
    end
  end
end
