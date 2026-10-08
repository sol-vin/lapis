# =============================================================================
# LibGodot Test Suite: Control Node Coverage & Multi-Frame Layout / UI Piping
# =============================================================================

include Lapis::Test

node UiSignalReceiver < Godot::Node do
  property button_clicks : Int32 = 0
  property toggled_states : Array(Bool) = Array(Bool).new
  property text_updates : Array(String) = Array(String).new
  property slider_values : Array(Float64) = Array(Float64).new

  def on_button_click : Void
    @button_clicks += 1
  end

  def on_option_toggled(state : Bool) : Void
    @toggled_states << state
  end

  def on_text_changed(text : String) : Void
    @text_updates << text
  end

  def on_slider_changed(val : Float64) : Void
    @slider_values << val
  end
end

test_suite "ControlMultiFrame" do
  test "VBoxContainer positions and stacks children vertically across layout frames" do
    assert_no_leak(max_delta_objects: 5, name: "VBoxContainer Layout Solve") do
      vbox = Godot.create(Godot::VBoxContainer)
      vbox.set_size(Godot::Vector2.new(300.0, 400.0))

      btn1 = Godot.create(Godot::Button)
      btn1.set_custom_minimum_size(Godot::Vector2.new(100.0, 40.0))
      btn1.call("set_text", "First")
      vbox.add_child(btn1)

      btn2 = Godot.create(Godot::Button)
      btn2.set_custom_minimum_size(Godot::Vector2.new(100.0, 50.0))
      btn2.call("set_text", "Second")
      vbox.add_child(btn2)

      btn3 = Godot.create(Godot::Button)
      btn3.set_custom_minimum_size(Godot::Vector2.new(100.0, 30.0))
      btn3.call("set_text", "Third")
      vbox.add_child(btn3)

      root.add_child(vbox)
      vbox.notification(50_i64)
      vbox.notification(51_i64)
      skip_frames(1)

      pos1 = btn1.get_position
      pos2 = btn2.get_position
      pos3 = btn3.get_position

      assert_lt pos1.y, pos2.y, "btn1 must be above btn2 in VBox"
      assert_lt pos2.y, pos3.y, "btn2 must be above btn3 in VBox"
      assert_gt btn2.get_size.y, 45.0_f32, "btn2 must respect minimum height"

      root.remove_child(vbox)
      btn1.destroy
      btn2.destroy
      btn3.destroy
      vbox.destroy
    end
  end

  test "HBoxContainer aligns children horizontally across layout frames" do
    assert_no_leak(max_delta_objects: 5, name: "HBoxContainer Layout Solve") do
      hbox = Godot.create(Godot::HBoxContainer)
      hbox.set_size(Godot::Vector2.new(600.0, 100.0))

      lbl1 = Godot.create(Godot::Label)
      lbl1.set_custom_minimum_size(Godot::Vector2.new(80.0, 30.0))
      lbl1.call("set_text", "Col 1")
      hbox.add_child(lbl1)

      lbl2 = Godot.create(Godot::Label)
      lbl2.set_custom_minimum_size(Godot::Vector2.new(120.0, 30.0))
      lbl2.call("set_text", "Col 2")
      hbox.add_child(lbl2)

      lbl3 = Godot.create(Godot::Label)
      lbl3.set_custom_minimum_size(Godot::Vector2.new(90.0, 30.0))
      lbl3.call("set_text", "Col 3")
      hbox.add_child(lbl3)

      root.add_child(hbox)
      hbox.notification(50_i64)
      hbox.notification(51_i64)
      skip_frames(1)

      p1 = lbl1.get_position
      p2 = lbl2.get_position
      p3 = lbl3.get_position

      assert_lt p1.x, p2.x, "lbl1 must precede lbl2 horizontally"
      assert_lt p2.x, p3.x, "lbl2 must precede lbl3 horizontally"

      root.remove_child(hbox)
      lbl1.destroy
      lbl2.destroy
      lbl3.destroy
      hbox.destroy
    end
  end

  test "GridContainer arranges 4 items in a 2x2 matrix over layout stepping" do
    assert_no_leak(max_delta_objects: 5, name: "GridContainer 2x2 Matrix") do
      grid = Godot.create(Godot::GridContainer)
      grid.set_columns(2_i64)
      grid.set_size(Godot::Vector2.new(400.0, 400.0))

      items = Array(Godot::Control).new
      4.times do |i|
        ctrl = Godot.create(Godot::Control)
        ctrl.set_custom_minimum_size(Godot::Vector2.new(80.0, 60.0))
        grid.add_child(ctrl)
        items << ctrl
      end

      root.add_child(grid)
      grid.notification(50_i64)
      grid.notification(51_i64)
      skip_frames(1)

      # Row 0: items 0 and 1
      assert_approx_eq items[0].get_position.y, items[1].get_position.y, epsilon: 1.0_f64
      assert_lt items[0].get_position.x, items[1].get_position.x

      # Row 1: items 2 and 3
      assert_approx_eq items[2].get_position.y, items[3].get_position.y, epsilon: 1.0_f64
      assert_lt items[2].get_position.x, items[3].get_position.x

      # Row 1 must be below Row 0
      assert_gt items[2].get_position.y, items[0].get_position.y

      root.remove_child(grid)
      items.each(&.destroy)
      grid.destroy
    end
  end

  test "UI widget signals piped to class methods via >> operator" do
    assert_no_leak(max_delta_objects: 5, name: "UI Signals >> Class Methods") do
      receiver = Godot.create(UiSignalReceiver)
      root.add_child(receiver)

      # 1. Button#pressed >> ->receiver.on_button_click
      btn = Godot.create(Godot::Button)
      sub_btn = (btn.pressed >> ->receiver.on_button_click)
      assert_true sub_btn.connected?
      btn.emit_signal("pressed")
      assert_eq receiver.button_clicks, 1

      # 2. CheckBox#toggled >> ->receiver.on_option_toggled(Bool)
      cb = Godot.create(Godot::CheckBox)
      sub_cb = (cb.toggled >> ->receiver.on_option_toggled(Bool))
      assert_true sub_cb.connected?
      cb.emit_signal("toggled", true)
      cb.emit_signal("toggled", false)
      assert_eq receiver.toggled_states, [true, false]

      # 3. LineEdit#text_changed >> ->receiver.on_text_changed(String)
      le = Godot.create(Godot::LineEdit)
      sub_le = (le.text_changed >> ->receiver.on_text_changed(String))
      assert_true sub_le.connected?
      le.emit_signal("text_changed", "Hello Lapis")
      assert_eq receiver.text_updates, ["Hello Lapis"]

      # 4. HSlider#value_changed >> ->receiver.on_slider_changed(Float64)
      slider = Godot.create(Godot::HSlider)
      sub_slider = (slider.value_changed >> ->receiver.on_slider_changed(Float64))
      assert_true sub_slider.connected?
      slider.emit_signal("value_changed", 75.5_f64)
      assert_eq receiver.slider_values, [75.5]

      sub_btn.unsubscribe
      sub_cb.unsubscribe
      sub_le.unsubscribe
      sub_slider.unsubscribe

      btn.destroy
      cb.destroy
      le.destroy
      slider.destroy
      root.remove_child(receiver)
      receiver.destroy
    end
  end
end
