# =============================================================================
# LibGodot Test Suite: Image & Pixel Buffer Manipulation
# =============================================================================

include Lapis::Test

test_suite "ImageBuffer" do
  test "Image creation, dimensions, format inspection and fill" do
    img = Godot::Image.create(32_i64, 32_i64, false, Godot::Image::Format::FormatRgba8)
    assert_not_nil img
    assert_false img.pointer.null?
    assert_eq img.get_width, 32_i64
    assert_eq img.get_height, 32_i64
    assert_false img.is_empty?

    # Fill image with blue
    blue = Godot::Color.new(0.0_f32, 0.0_f32, 1.0_f32, 1.0_f32)
    img.fill(blue)

    center_pixel = img.get_pixel(16_i64, 16_i64)
    assert_true (center_pixel.b - 1.0_f32).abs < 0.01_f32
    assert_true center_pixel.r < 0.01_f32
  end

  test "Image per-pixel mutation and color reading" do
    img = Godot::Image.create(16_i64, 16_i64, false, Godot::Image::Format::FormatRgba8)

    red = Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
    green = Godot::Color.new(0.0_f32, 1.0_f32, 0.0_f32, 1.0_f32)

    img.set_pixel(0_i64, 0_i64, red)
    img.set_pixel(15_i64, 15_i64, green)

    p0 = img.get_pixel(0_i64, 0_i64)
    p1 = img.get_pixel(15_i64, 15_i64)

    assert_true (p0.r - 1.0_f32).abs < 0.01_f32
    assert_true (p1.g - 1.0_f32).abs < 0.01_f32
  end
end
