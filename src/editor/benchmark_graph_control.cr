# =============================================================================
# LibGodot - Visual Benchmark Comparison Graph Control
# =============================================================================
# Renders responsive comparative performance bar charts for Crystal vs GDScript
# vs C++ vs Rust directly in the Godot Editor without needing an external browser.
# =============================================================================

require "../lapis"

module Lapis
  struct BenchmarkComparisonItem
    getter name : String
    getter crystal_ms : Float64
    getter gdscript_ms : Float64?
    getter cpp_ms : Float64?
    getter rust_ms : Float64?
    getter speedup : Float64?
    getter details : String

    def initialize(
      @name : String,
      @crystal_ms : Float64,
      @gdscript_ms : Float64? = nil,
      @cpp_ms : Float64? = nil,
      @rust_ms : Float64? = nil,
      @speedup : Float64? = nil,
      @details : String = ""
    )
    end
  end

  @[Tool]
  node BenchmarkGraphControl < VBoxContainer do
    @items = [] of BenchmarkComparisonItem

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
      call("set_h_size_flags", 3_i64) # SIZE_EXPAND_FILL
      call("set_v_size_flags", 3_i64) # SIZE_EXPAND_FILL
      call("add_theme_constant_override", "separation", 8)
    end

    def clear_entries : Void
      @items.clear
      count = call_i64("get_child_count") rescue 0_i64
      count.times do
        if child = call_obj("get_child", 0)
          call("remove_child", child)
          child.destroy rescue nil
        end
      end
    end

    def add_comparison(
      name : String,
      crystal_ms : Float64,
      gdscript_ms : Float64? = nil,
      cpp_ms : Float64? = nil,
      rust_ms : Float64? = nil,
      speedup : Float64? = nil,
      details : String = ""
    ) : Void
      item = BenchmarkComparisonItem.new(name, crystal_ms, gdscript_ms, cpp_ms, rust_ms, speedup, details)
      @items << item
      render_entry(item)
    end

    def set_comparisons(new_items : Array(BenchmarkComparisonItem)) : Void
      clear_entries
      @items = new_items.dup
      @items.each { |it| render_entry(it) }
    end

    private def render_entry(item : BenchmarkComparisonItem) : Void
      panel = Godot.create(Godot::PanelContainer)
      return unless panel
      panel.call("set_h_size_flags", 3_i64)

      vbox = Godot.create(Godot::VBoxContainer)
      return unless vbox
      vbox.call("set_h_size_flags", 3_i64)
      vbox.call("add_theme_constant_override", "separation", 4)
      panel.call("add_child", vbox)

      # Header: Name + Speedup badge
      header_row = Godot.create(Godot::HBoxContainer)
      if header_row
        lbl_name = Godot.create(Godot::Label)
        if lbl_name
          lbl_name.call("set_text", item.name)
          lbl_name.call("add_theme_font_size_override", "font_size", 13)
          lbl_name.call("add_theme_color_override", "font_color", Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
          header_row.call("add_child", lbl_name)
        end

        spacer = Godot.create(Godot::Control)
        if spacer
          spacer.call("set_h_size_flags", 3_i64)
          header_row.call("add_child", spacer)
        end

        if sp = item.speedup
          lbl_sp = Godot.create(Godot::Label)
          if lbl_sp
            lbl_sp.call("set_text", "#{sp.round(1)}x Faster than GDScript")
            lbl_sp.call("add_theme_color_override", "font_color", Color.new(0.3_f32, 1.0_f32, 0.4_f32, 1.0_f32))
            lbl_sp.call("add_theme_font_size_override", "font_size", 12)
            header_row.call("add_child", lbl_sp)
          end
        end

        vbox.call("add_child", header_row)
      end

      # Determine maximum ms for scale
      max_ms = item.crystal_ms
      max_ms = Math.max(max_ms, item.gdscript_ms || 0.0)
      max_ms = Math.max(max_ms, item.cpp_ms || 0.0)
      max_ms = Math.max(max_ms, item.rust_ms || 0.0)
      max_ms = 0.001 if max_ms <= 0.0

      # Bar 1: Crystal (Cyan)
      add_bar_row(vbox, "Crystal (Native)", item.crystal_ms, max_ms, Color.new(0.0_f32, 0.85_f32, 1.0_f32, 1.0_f32))

      # Bar 2: GDScript (Orange)
      if gd = item.gdscript_ms
        add_bar_row(vbox, "GDScript", gd, max_ms, Color.new(1.0_f32, 0.6_f32, 0.0_f32, 1.0_f32))
      end

      # Bar 3: C++ (Purple)
      if cpp = item.cpp_ms
        add_bar_row(vbox, "C++", cpp, max_ms, Color.new(0.65_f32, 0.45_f32, 1.0_f32, 1.0_f32))
      end

      # Bar 4: Rust (Red)
      if rust = item.rust_ms
        add_bar_row(vbox, "Rust", rust, max_ms, Color.new(0.95_f32, 0.35_f32, 0.35_f32, 1.0_f32))
      end

      call("add_child", panel)
    end

    private def add_bar_row(container : Node, label_text : String, value_ms : Float64, max_ms : Float64, color : Color) : Void
      row = Godot.create(Godot::HBoxContainer)
      return unless row
      row.call("add_theme_constant_override", "separation", 8)

      lbl = Godot.create(Godot::Label)
      if lbl
        lbl.call("set_text", label_text)
        lbl.call("set_custom_minimum_size", Vector2.new(120_f32, 0_f32))
        lbl.call("add_theme_font_size_override", "font_size", 11)
        lbl.call("add_theme_color_override", "font_color", Color.new(0.85_f32, 0.85_f32, 0.85_f32, 1.0_f32))
        row.call("add_child", lbl)
      end

      progress = Godot.create(Godot::ProgressBar)
      if progress
        progress.call("set_h_size_flags", 3_i64)
        progress.call("set_min", 0.0_f64)
        progress.call("set_max", max_ms)
        progress.call("set_value", value_ms)
        progress.call("set_show_percentage", false)
        progress.call("set_custom_minimum_size", Vector2.new(0_f32, 14_f32))
        progress.call("add_theme_color_override", "font_color", color)
        row.call("add_child", progress)
      end

      lbl_val = Godot.create(Godot::Label)
      if lbl_val
        lbl_val.call("set_text", "#{value_ms.round(2)} ms")
        lbl_val.call("set_custom_minimum_size", Vector2.new(80_f32, 0_f32))
        lbl_val.call("add_theme_font_size_override", "font_size", 11)
        lbl_val.call("add_theme_color_override", "font_color", color)
        row.call("add_child", lbl_val)
      end

      container.call("add_child", row)
    end
  end
end
