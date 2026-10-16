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

  test "Fast-path Image#update_buffer from raw bytes Slice(UInt8)" do
    img = Godot::Image.create(4_i64, 4_i64, false, Godot::Image::Format::FormatRgba8)
    assert_not_nil img

    # 4x4 RGBA8 = 16 pixels * 4 bytes = 64 bytes
    # Fill pixel (0,0) with red (255, 0, 0, 255) and pixel (1,0) with green (0, 255, 0, 255)
    raw = Bytes.new(64, 0_u8)
    raw[0] = 255_u8; raw[1] = 0_u8; raw[2] = 0_u8; raw[3] = 255_u8
    raw[4] = 0_u8; raw[5] = 255_u8; raw[6] = 0_u8; raw[7] = 255_u8

    img.update_buffer(4, 4, Godot::Image::Format::FormatRgba8, raw)

    p0 = img.get_pixel(0_i64, 0_i64)
    p1 = img.get_pixel(1_i64, 0_i64)
    assert_true (p0.r - 1.0_f32).abs < 0.01_f32
    assert_true (p1.g - 1.0_f32).abs < 0.01_f32

    # Verify read_buffer reads back identical bytes
    read_back = Bytes.new(64, 0_u8)
    copied = img.read_buffer(read_back)
    assert_eq copied, 64_i64
    assert_eq read_back[0], 255_u8
    assert_eq read_back[1], 0_u8
    assert_eq read_back[4], 0_u8
    assert_eq read_back[5], 255_u8
  end

  test "Image.create_from_buffer and to_slice round-trip" do
    raw = Bytes.new(32, 128_u8) # 2x4 RGBA8
    img = Godot::Image.create_from_buffer(2, 4, Godot::Image::Format::FormatRgba8, raw)
    assert_not_nil img
    assert_eq img.get_width, 2_i64
    assert_eq img.get_height, 4_i64

    slice = img.to_slice
    assert_eq slice.size, 32
    assert_eq slice[0], 128_u8
    assert_eq slice[31], 128_u8
  end
end
