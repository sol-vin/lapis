# =============================================================================
# LibGodot Test Suite: Control & GUI Nodes
# =============================================================================

include Lapis::Test

macro test_ui(name, &block)
  Registry.register("UI", {{name}}) do |node|
    root = node
    {{block.body}}
  end
end

test_ui "Label text, alignment, and formatting" do
  lbl = Godot.create(Godot::Label)
  assert_not_nil lbl

  lbl.call("set_text", "Hello LibGodot")
  assert_eq lbl.call_str("get_text"), "Hello LibGodot"

  lbl.set_horizontal_alignment(1_i64) # HORIZONTAL_ALIGNMENT_CENTER
  assert_eq lbl.get_horizontal_alignment, 1_i64

  lbl.set_uppercase(true)
  assert_true lbl.is_uppercase

  lbl.destroy
end

test_ui "Button and state toggles" do
  btn = Godot.create(Godot::Button)
  btn.call("set_text", "Click Action")
  assert_eq btn.call_str("get_text"), "Click Action"

  btn.set_flat(true)
  assert_true btn.is_flat

  btn.set_disabled(true)
  assert_true btn.is_disabled

  btn.destroy
end

test_ui "CheckBox and CheckButton boolean states" do
  cb = Godot.create(Godot::CheckBox)
  cb.call("set_text", "Enable Option")
  cb.set_pressed(true)
  assert_true cb.is_pressed

  cbtn = Godot.create(Godot::CheckButton)
  cbtn.set_pressed(false)
  assert_false cbtn.is_pressed

  cb.destroy
  cbtn.destroy
end

test_ui "LineEdit text entry, password masking, and constraints" do
  le = Godot.create(Godot::LineEdit)
  le.call("set_text", "SecretPassword123")
  assert_eq le.call_str("get_text"), "SecretPassword123"

  le.set_secret(true)
  assert_true le.is_secret

  le.set_max_length(32_i64)
  assert_eq le.get_max_length, 32_i64

  le.call("set_placeholder", "Enter password...")
  assert_eq le.call_str("get_placeholder"), "Enter password..."

  le.set_editable(false)
  assert_false le.is_editable

  le.destroy
end

test_ui "TextEdit and CodeEdit multi-line buffers" do
  te = Godot.create(Godot::TextEdit)
  te.call("set_text", "Line 1\nLine 2\nLine 3")
  assert_eq te.call_i64("get_line_count"), 3_i64

  ce = Godot.create(Godot::CodeEdit)
  ce.call("set_text", "fn main() {\n  return 0;\n}")
  assert_eq ce.call_i64("get_line_count"), 3_i64

  te.destroy
  ce.destroy
end

test_ui "RichTextLabel BBCode and auto-fitting" do
  rtl = Godot.create(Godot::RichTextLabel)
  rtl.set_use_bbcode(true)
  assert_true rtl.is_using_bbcode

  rtl.call("set_text", "[b]Bold Title[/b]")
  assert_eq rtl.call_str("get_text"), "[b]Bold Title[/b]"

  rtl.set_fit_content(true)
  assert_true rtl.is_fit_content_enabled

  rtl.destroy
end

test_ui "ProgressBar and Slider Range controls" do
  pb = Godot.create(Godot::ProgressBar)
  pb.set_min(0.0_f64)
  pb.set_max(200.0_f64)
  pb.set_value(150.0_f64)
  assert_approx_eq pb.get_value, 150.0
  assert_approx_eq pb.get_max, 200.0

  hslider = Godot.create(Godot::HSlider)
  hslider.set_min(10.0_f64)
  hslider.set_max(50.0_f64)
  hslider.set_value(35.0_f64)
  assert_approx_eq hslider.get_value, 35.0

  vslider = Godot.create(Godot::VSlider)
  vslider.set_step(5.0_f64)
  assert_approx_eq vslider.get_step, 5.0

  spin = Godot.create(Godot::SpinBox)
  spin.call("set_prefix", "Level: ")
  assert_eq spin.call_str("get_prefix"), "Level: "

  pb.destroy
  hslider.destroy
  vslider.destroy
  spin.destroy
end

test_ui "ColorRect, TextureRect, and NinePatchRect display elements" do
  cr = Godot.create(Godot::ColorRect)
  cr.set_color(Godot::Color.new(0.3, 0.6, 0.9, 1.0))
  assert_approx_eq cr.get_color.b, 0.9_f32

  tr = Godot.create(Godot::TextureRect)
  tr.set_expand_mode(1_i64) # EXPAND_KEEP_SIZE
  assert_eq tr.get_expand_mode, 1_i64

  np = Godot.create(Godot::NinePatchRect)
  np.set_patch_margin(Godot::Side::Left.to_i64, 12_i64)
  np.set_patch_margin(Godot::Side::Top.to_i64, 12_i64)
  assert_eq np.get_patch_margin(Godot::Side::Left.to_i64), 12_i64

  cr.destroy
  tr.destroy
  np.destroy
end

test_ui "Containers hierarchy management (HBox, VBox, Grid, Margin, Panel, Scroll)" do
  hbox = Godot.create(Godot::HBoxContainer)
  vbox = Godot.create(Godot::VBoxContainer)
  grid = Godot.create(Godot::GridContainer)
  grid.set_columns(4_i64)
  assert_eq grid.get_columns, 4_i64

  margin = Godot.create(Godot::MarginContainer)
  panel = Godot.create(Godot::PanelContainer)
  scroll = Godot.create(Godot::ScrollContainer)

  # Nest into hierarchy
  margin.add_child(panel)
  panel.add_child(scroll)
  scroll.add_child(vbox)
  vbox.add_child(hbox)
  vbox.add_child(grid)

  assert_eq vbox.get_child_count, 2_i64
  assert_eq margin.get_child_count, 1_i64

  margin.destroy
end

test_ui "ItemList items addition, indexing, and clearing" do
  il = Godot.create(Godot::ItemList)
  assert_eq il.get_item_count, 0_i64

  il.call("add_item", "First Item")
  il.call("add_item", "Second Item")
  il.call("add_item", "Third Item")

  assert_eq il.call_i64("get_item_count"), 3_i64
  assert_eq il.call_str("get_item_text", 0_i64), "First Item"
  assert_eq il.call_str("get_item_text", 2_i64), "Third Item"

  il.clear
  assert_eq il.get_item_count, 0_i64
  il.destroy
end
