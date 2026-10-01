# =============================================================================
# LibGodot Performance Benchmark - Standardized Visual Performance Monitor
# =============================================================================

require "lapis"
require "./perf_metrics"
require "./perf_base"

module PerfFramework
  # Graph renderer for metric lines using Line2D with dynamic viewport scaling.
  # Supports dual-trace plotting (e.g. Engine Static RAM vs Crystal GC Active RAM).
  class MetricGraphView
    getter container : Godot::PanelContainer
    getter graph_area : Godot::Control
    getter line : Godot::Line2D
    getter line2 : Godot::Line2D?
    getter title_label : Godot::Label
    getter value_label : Godot::Label
    getter color : Godot::Color
    getter color2 : Godot::Color?
    getter max_samples : Int32

    def initialize(
      parent : Godot::Node,
      title : String,
      color : Godot::Color,
      max_samples : Int32 = 80,
      color2 : Godot::Color? = nil,
    )
      @color = color
      @color2 = color2
      @max_samples = max_samples

      @container = Godot.create(Godot::PanelContainer)
      @container.set_h_size_flags(3_i64) # SIZE_EXPAND_FILL
      @container.set_v_size_flags(3_i64) # SIZE_EXPAND_FILL
      @container.set_custom_minimum_size(Godot::Vector2.new(180.0, 115.0))
      parent.add_child(@container)

      vbox = Godot.create(Godot::VBoxContainer)
      vbox.set_h_size_flags(3_i64)
      vbox.set_v_size_flags(3_i64)
      @container.add_child(vbox)

      # Title & Value Header
      header = Godot.create(Godot::HBoxContainer)
      header.set_h_size_flags(3_i64)
      vbox.add_child(header)

      @title_label = Godot.create(Godot::Label)
      @title_label.call("set_text", title)
      header.add_child(@title_label)

      spacer = Godot.create(Godot::Control)
      spacer.set_h_size_flags(3_i64)
      header.add_child(spacer)

      @value_label = Godot.create(Godot::Label)
      @value_label.call("set_text", "---")
      header.add_child(@value_label)

      # Graph Canvas
      @graph_area = Godot.create(Godot::Control)
      @graph_area.set_h_size_flags(3_i64)
      @graph_area.set_v_size_flags(3_i64)
      @graph_area.set_custom_minimum_size(Godot::Vector2.new(140.0, 60.0))
      vbox.add_child(@graph_area)

      # Primary plot line
      @line = Godot.create(Godot::Line2D)
      @line.set_width(2.0)
      @line.set_default_color(color)
      @graph_area.add_child(@line)

      # Optional secondary plot line
      if c2 = color2
        l2 = Godot.create(Godot::Line2D)
        l2.set_width(2.0)
        l2.set_default_color(c2)
        @graph_area.add_child(l2)
        @line2 = l2
      end
    end

    def update(samples : Array(Float64), current_text : String, min_val : Float64? = nil, max_val : Float64? = nil)
      @value_label.call("set_text", current_text)
      @line.clear_points
      @line2.try &.clear_points

      return if samples.empty?

      actual_min = min_val || samples.min
      actual_max = max_val || samples.max
      actual_max = actual_min + 0.001 if (actual_max - actual_min).abs < 0.0001

      # Calculate dynamically scaled width and height based on the current window size
      area_size = @graph_area.get_size
      graph_w = area_size.x > 30.0 ? (area_size.x - 4.0) : 240.0
      graph_h = area_size.y > 20.0 ? (area_size.y - 4.0) : 60.0
      step_x = graph_w / @max_samples.to_f64

      samples.each_with_index do |val, idx|
        norm = (val - actual_min) / (actual_max - actual_min)
        norm = norm.clamp(0.0, 1.0)
        px = (idx * step_x).to_f32 + 2.0_f32
        py = (graph_h - (norm * graph_h)).to_f32 + 2.0_f32
        @line.add_point(Godot::Vector2.new(px, py), -1_i64)
      end
    end

    # Dual-trace update plotting two synchronized series on the same normalized scale
    def update_dual(
      samples1 : Array(Float64),
      samples2 : Array(Float64),
      current_text : String,
      min_val : Float64? = nil,
      max_val : Float64? = nil,
    )
      @value_label.call("set_text", current_text)
      @line.clear_points
      @line2.try &.clear_points

      return if samples1.empty? && samples2.empty?

      all_min = Float64::MAX
      all_max = Float64::MIN

      unless samples1.empty?
        all_min = {all_min, samples1.min}.min
        all_max = {all_max, samples1.max}.max
      end

      unless samples2.empty?
        all_min = {all_min, samples2.min}.min
        all_max = {all_max, samples2.max}.max
      end

      actual_min = min_val || all_min
      actual_max = max_val || all_max
      actual_max = actual_min + 0.001 if (actual_max - actual_min).abs < 0.0001

      area_size = @graph_area.get_size
      graph_w = area_size.x > 30.0 ? (area_size.x - 4.0) : 240.0
      graph_h = area_size.y > 20.0 ? (area_size.y - 4.0) : 60.0
      step_x = graph_w / @max_samples.to_f64

      samples1.each_with_index do |val, idx|
        norm = (val - actual_min) / (actual_max - actual_min)
        norm = norm.clamp(0.0, 1.0)
        px = (idx * step_x).to_f32 + 2.0_f32
        py = (graph_h - (norm * graph_h)).to_f32 + 2.0_f32
        @line.add_point(Godot::Vector2.new(px, py), -1_i64)
      end

      if l2 = @line2
        samples2.each_with_index do |val, idx|
          norm = (val - actual_min) / (actual_max - actual_min)
          norm = norm.clamp(0.0, 1.0)
          px = (idx * step_x).to_f32 + 2.0_f32
          py = (graph_h - (norm * graph_h)).to_f32 + 2.0_f32
          l2.add_point(Godot::Vector2.new(px, py), -1_i64)
        end
      end
    end
  end

  @[Tool]
  node PerfHUD < Godot::Control do
    property active_test : PerfBase?
    property sampler : MetricsSampler = MetricsSampler.new
    property on_return_menu : Proc(Void)?

    @samples_fps = Array(Float64).new(100)
    @samples_frame_time = Array(Float64).new(100)
    @samples_ram = Array(Float64).new(100)
    @samples_gc = Array(Float64).new(100)
    @samples_objects = Array(Float64).new(100)
    @samples_nodes = Array(Float64).new(100)

    @graph_cpu : MetricGraphView?
    @graph_ram : MetricGraphView?
    @graph_objects : MetricGraphView?
    @graph_fps : MetricGraphView?

    @lbl_title : Godot::Label?
    @lbl_status : Godot::Label?
    @lbl_duration : Godot::Label?
    @lbl_warning : Godot::Label?
    @progress_bar : Godot::ProgressBar?
    @graphs_box : Godot::HBoxContainer?
    @hud_minimized : Bool = false
    @sample_timer : Float64 = 0.0

    def _ready : Void
      build_ui
    end

    def build_ui : Void
      set_anchor(0_i64, 0.0, false, false) # Left
      set_anchor(1_i64, 0.0, false, false) # Top
      set_anchor(2_i64, 1.0, false, false) # Right
      set_anchor(3_i64, 0.0, false, false) # Bottom
      set_offset(0_i64, 12.0)
      set_offset(1_i64, 12.0)
      set_offset(2_i64, -12.0)
      set_offset(3_i64, 200.0)
      set_custom_minimum_size(Godot::Vector2.new(0.0, 195.0))
      set_h_size_flags(3_i64) # SIZE_EXPAND_FILL

      # Root panel background
      bg = Godot.create(Godot::Panel)
      bg.set_anchor(0_i64, 0.0, false, false)
      bg.set_anchor(1_i64, 0.0, false, false)
      bg.set_anchor(2_i64, 1.0, false, false)
      bg.set_anchor(3_i64, 1.0, false, false)
      add_child(bg)

      # Main vertical layout
      vbox = Godot.create(Godot::VBoxContainer)
      vbox.set_anchor(0_i64, 0.0, false, false)
      vbox.set_anchor(1_i64, 0.0, false, false)
      vbox.set_anchor(2_i64, 1.0, false, false)
      vbox.set_anchor(3_i64, 1.0, false, false)
      vbox.set_offset(0_i64, 8.0)
      vbox.set_offset(1_i64, 8.0)
      vbox.set_offset(2_i64, -8.0)
      vbox.set_offset(3_i64, -8.0)
      vbox.set_h_size_flags(3_i64)
      add_child(vbox)

      # Top Status Bar
      top_bar = Godot.create(Godot::HBoxContainer)
      top_bar.set_h_size_flags(3_i64)
      vbox.add_child(top_bar)

      @lbl_title = Godot.create(Godot::Label)
      @lbl_title.not_nil!.call("set_text", "LibGodot Performance Monitor")
      top_bar.add_child(@lbl_title.not_nil!)

      # Spacer
      spacer = Godot.create(Godot::Control)
      spacer.set_h_size_flags(3_i64) # SizeFlags::ExpandFill
      top_bar.add_child(spacer)

      @lbl_status = Godot.create(Godot::Label)
      @lbl_status.not_nil!.call("set_text", "[STANDBY]")
      top_bar.add_child(@lbl_status.not_nil!)

      @lbl_duration = Godot.create(Godot::Label)
      @lbl_duration.not_nil!.call("set_text", "Mode: --")
      top_bar.add_child(@lbl_duration.not_nil!)

      @lbl_warning = Godot.create(Godot::Label)
      @lbl_warning.not_nil!.call("set_text", "")
      top_bar.add_child(@lbl_warning.not_nil!)

      # Action Buttons
      btn_gc = Godot.create(Godot::Button)
      btn_gc.call("set_text", "♻ Force GC")
      btn_gc.connect("pressed") do
        GC.collect
        @sampler.reset_baseline
        Godot.print("[PerfHUD] Forced Boehm GC cycle and reset baseline.")
      end
      top_bar.add_child(btn_gc)

      btn_pause = Godot.create(Godot::Button)
      btn_pause.call("set_text", "⏸ Pause")
      btn_pause.connect("pressed") do
        if test = @active_test
          test.toggle_pause
          btn_pause.call("set_text", test.is_paused ? "▶ Resume" : "⏸ Pause")
        end
      end
      top_bar.add_child(btn_pause)

      btn_toggle = Godot.create(Godot::Button)
      btn_toggle.call("set_text", "👁 HUD")
      btn_toggle.connect("pressed") do
        toggle_hud
      end
      top_bar.add_child(btn_toggle)

      btn_menu = Godot.create(Godot::Button)
      btn_menu.call("set_text", "⎋ Menu (Esc)")
      btn_menu.connect("pressed") do
        return_to_menu
      end
      top_bar.add_child(btn_menu)

      # Duration Progress Bar
      @progress_bar = Godot.create(Godot::ProgressBar)
      @progress_bar.not_nil!.set_h_size_flags(3_i64)
      @progress_bar.not_nil!.set_custom_minimum_size(Godot::Vector2.new(0.0, 6.0))
      @progress_bar.not_nil!.set_show_percentage(false)
      @progress_bar.not_nil!.set_visible(false)
      vbox.add_child(@progress_bar.not_nil!)

      # 4 Synchronized Charts Grid (expands equally across window width)
      @graphs_box = Godot.create(Godot::HBoxContainer)
      @graphs_box.not_nil!.set_h_size_flags(3_i64)
      @graphs_box.not_nil!.set_v_size_flags(3_i64)
      vbox.add_child(@graphs_box.not_nil!)

      # Graph 1: CPU & Frame Time
      @graph_cpu = MetricGraphView.new(
        @graphs_box.not_nil!,
        "CPU / Process",
        Godot::Color.new(0.3, 0.9, 0.5, 1.0) # Emerald
      )

      # Graph 2: Dual Trace RAM (Engine Static vs Crystal Boehm GC Active)
      @graph_ram = MetricGraphView.new(
        @graphs_box.not_nil!,
        "RAM: Engine / GC",
        Godot::Color.new(0.2, 0.8, 1.0, 1.0),        # Cyan = Godot Static RAM
        color2: Godot::Color.new(1.0, 0.4, 0.8, 1.0) # Magenta = Crystal GC Active RAM
      )

      # Graph 3: ObjectDB & Nodes
      @graph_objects = MetricGraphView.new(
        @graphs_box.not_nil!,
        "Objects & Nodes",
        Godot::Color.new(1.0, 0.6, 0.2, 1.0) # Amber
      )

      # Graph 4: FPS & Stability
      @graph_fps = MetricGraphView.new(
        @graphs_box.not_nil!,
        "FPS & Stability",
        Godot::Color.new(0.7, 1.0, 0.3, 1.0) # Lime
      )
    end

    def attach_test(test : PerfBase) : Void
      @active_test = test
      if lbl = @lbl_title
        lbl.call("set_text", "Stress Test: #{test.test_name}")
      end
    end

    def detach_test : Void
      @active_test = nil
      if lbl = @lbl_title
        lbl.call("set_text", "LibGodot Performance Monitor - Standby")
      end
      if lbl = @lbl_status
        lbl.call("set_text", "[STANDBY]")
      end
      if pb = @progress_bar
        pb.set_visible(false)
      end
    end

    def toggle_hud : Void
      @hud_minimized = !@hud_minimized
      if box = @graphs_box
        box.set_visible(!@hud_minimized)
      end
      if pb = @progress_bar
        pb.set_visible(!@hud_minimized && @active_test != nil)
      end
      set_offset(3_i64, @hud_minimized ? 42.0 : 200.0)
      set_custom_minimum_size(Godot::Vector2.new(0.0, @hud_minimized ? 38.0 : 195.0))
    end

    def return_to_menu : Void
      if cb = @on_return_menu
        cb.call
      end
    end

    def _process(delta : Float64) : Void
      # ESC key quick return to menu
      if Godot.input.is_physical_key_pressed(4194305_i64) # KEY_ESCAPE
        return_to_menu
        return
      end

      @sample_timer += delta
      return if @sample_timer < 0.1 # Sample at 10 Hz for responsive charts

      @sample_timer = 0.0
      snap = @sampler.sample_now

      # Push samples to history arrays
      push_sample(@samples_fps, snap.fps)
      push_sample(@samples_frame_time, snap.frame_time_ms)
      push_sample(@samples_ram, snap.static_ram_mb)
      push_sample(@samples_gc, snap.crystal_gc_active_mb)
      push_sample(@samples_objects, snap.object_count.to_f64)
      push_sample(@samples_nodes, snap.node_count.to_f64)

      # Update Charts
      if g_cpu = @graph_cpu
        g_cpu.update(
          @samples_frame_time,
          "#{snap.frame_time_ms.round(1)} ms",
          min_val: 0.0,
          max_val: 33.3
        )
      end

      if g_ram = @graph_ram
        g_ram.update_dual(
          @samples_ram,
          @samples_gc,
          "Godot: #{snap.static_ram_mb.round(1)}M | GC: #{snap.crystal_gc_active_mb.round(1)}M",
          min_val: 0.0
        )
      end

      if g_obj = @graph_objects
        g_obj.update(
          @samples_objects,
          "Obj: #{snap.object_count} | Node: #{snap.node_count}"
        )
      end

      if g_fps = @graph_fps
        g_fps.update(
          @samples_fps,
          "#{snap.fps.round(0).to_i} FPS",
          min_val: 0.0,
          max_val: 144.0
        )
      end

      # Crystal GC Memory Ballooning Detection
      # Check if GC active memory exhibits sustained upward creep (>5MB growth over history window)
      gc_ballooning = false
      gc_growth = 0.0
      if @samples_gc.size >= 30
        initial_avg = @samples_gc[0..9].sum / 10.0
        latest_avg = @samples_gc[-10..-1].sum / 10.0
        gc_growth = latest_avg - initial_avg
        if gc_growth > 5.0
          gc_ballooning = true
        end
      end

      # Warning alerts for orphans and GC ballooning
      if lbl_w = @lbl_warning
        if snap.orphan_count > 0 && gc_ballooning
          lbl_w.call("set_text", " ⚠️ #{snap.orphan_count} ORPHANS | GC BALLOON (+#{gc_growth.round(1)}M) ")
        elsif snap.orphan_count > 0
          lbl_w.call("set_text", " ⚠️ #{snap.orphan_count} ORPHAN NODES ")
        elsif gc_ballooning
          lbl_w.call("set_text", " ⚠️ CRYSTAL GC BALLOONING (+#{gc_growth.round(1)}M) ")
        else
          lbl_w.call("set_text", "")
        end
      end

      # Update Active Test Status & Duration
      if test = @active_test
        if lbl_s = @lbl_status
          lbl_s.call("set_text", test.is_paused ? "[PAUSED]" : (test.is_running ? "[RUNNING]" : "[FINISHED]"))
        end

        if lbl_d = @lbl_duration
          if test.is_infinite
            lbl_d.call("set_text", "Mode: [ ∞ Infinite ]  Elapsed: #{test.elapsed_time.round(1)}s (Cycles: #{test.completed_cycles})")
          else
            target_dur = test.finite_duration
            lbl_d.call("set_text", "Mode: [ Finite ]  #{test.elapsed_time.round(1)}s / #{target_dur.round(1)}s (Cycles: #{test.completed_cycles})")
          end
        end

        if pb = @progress_bar
          unless test.is_infinite
            pb.set_visible(!@hud_minimized)
            ratio = (test.elapsed_time / test.finite_duration).clamp(0.0, 1.0)
            pb.set_value(ratio * 100.0)
          else
            pb.set_visible(false)
          end
        end
      end
    end

    private def push_sample(arr : Array(Float64), val : Float64) : Void
      arr.shift if arr.size >= 80
      arr << val
    end
  end
end
