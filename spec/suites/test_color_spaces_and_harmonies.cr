# =============================================================================
# LibGodot Test Suite: Advanced Color Spaces, Harmonies & WCAG Accessibility
# =============================================================================

include Lapis::Test

test_suite "ColorSpaces" do
  test "Pillar 1: HSV intermediary struct, conversions and with-builders" do
    # 1. Construction and properties
    hsv = Godot::Color::HSV.new(0.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
    assert_eq hsv.h, 0.0_f32
    assert_eq hsv.s, 1.0_f32
    assert_eq hsv.v, 1.0_f32
    assert_eq hsv.a, 1.0_f32

    # 2. Conversion to Color and to_rgb
    c = hsv.to_color
    assert_eq c.r, 1.0_f32
    assert_eq c.g, 0.0_f32
    assert_eq c.b, 0.0_f32
    assert_eq hsv.to_rgb, c

    # 3. Color.new(HSV) constructor
    c2 = Godot::Color.new(hsv)
    assert_eq c2.r, 1.0_f32
    assert_eq c2.g, 0.0_f32

    # 4. With-helpers
    hsv2 = hsv.with_h(0.5_f32).with_s(0.8_f32).with_v(0.9_f32).with_a(0.7_f32)
    assert_eq hsv2.h, 0.5_f32
    assert_eq hsv2.s, 0.8_f32
    assert_eq hsv2.v, 0.9_f32
    assert_eq hsv2.a, 0.7_f32

    # Original remains unmodified
    assert_eq hsv.h, 0.0_f32
    assert_eq hsv.s, 1.0_f32

    # 5. Mutating setters
    hsv.h = 0.25_f32
    hsv.s = 0.5_f32
    hsv.v = 0.75_f32
    hsv.a = 0.5_f32
    assert_eq hsv.h, 0.25_f32
    assert_eq hsv.s, 0.5_f32
    assert_eq hsv.v, 0.75_f32
    assert_eq hsv.a, 0.5_f32
  end

  test "Pillar 2: Color HSV accessors, mutating setters and non-mutating helpers" do
    red = Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)

    # 1. to_hsv, to_hsva, and hsv accessors
    h, s, v = red.to_hsv
    assert_eq h, 0.0_f32
    assert_eq s, 1.0_f32
    assert_eq v, 1.0_f32

    h2, s2, v2, a2 = red.to_hsva
    assert_eq a2, 1.0_f32

    hsv_obj = red.hsv
    assert_eq hsv_obj.h, 0.0_f32
    assert_eq hsv_obj.s, 1.0_f32

    # 2. Mutating property setters
    mutable_c = red
    mutable_c.h = 0.3333_f32
    assert_true (mutable_c.h - 0.3333_f32).abs < 0.01_f32
    assert_true mutable_c.g > 0.5_f32

    # 3. Fluent non-mutating with_* helpers
    blue = red.with_h(0.6667_f32)
    assert_true blue.b > 0.5_f32
    assert_true (blue.h - 0.6667_f32).abs < 0.01_f32

    desat = red.with_s(0.3_f32)
    assert_true (desat.s - 0.3_f32).abs < 0.02_f32

    dim = red.with_v(0.4_f32)
    assert_true (dim.v - 0.4_f32).abs < 0.02_f32

    faded = red.with_alpha(0.6_f32)
    assert_eq faded.a, 0.6_f32

    # 4. ITU-R BT.709 relative luminance
    assert_true (red.luminance - 0.2126_f32).abs < 0.001_f32
    assert_eq Godot::Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32).luminance, 0.0_f32
    assert_true (Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32).luminance - 1.0_f32).abs < 0.001_f32
  end

  test "Pillar 3: Intermediary color spaces (HSL, CMYK, XYZ, Lab, Oklab, Oklch)" do
    # 1. HSL
    green = Godot::Color.new(0.0_f32, 1.0_f32, 0.0_f32, 1.0_f32)
    hsl = green.hsl
    assert_true (hsl.h - 1.0_f32 / 3.0_f32).abs < 0.01_f32
    assert_eq hsl.s, 1.0_f32
    assert_eq hsl.l, 0.5_f32

    from_hsl = hsl.to_color
    assert_true (from_hsl.g - 1.0_f32).abs < 0.001_f32
    assert_true from_hsl.r.abs < 0.001_f32
    assert_true from_hsl.b.abs < 0.001_f32

    # 2. CMYK
    cyan = Godot::Color.new(0.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
    cmyk = cyan.cmyk
    assert_eq cmyk.c, 1.0_f32
    assert_eq cmyk.m, 0.0_f32
    assert_eq cmyk.y, 0.0_f32
    assert_eq cmyk.k, 0.0_f32
    assert_eq cmyk.to_color, cyan

    # 3. CIE-XYZ (D65)
    white = Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
    xyz = white.xyz
    assert_true (xyz.x - 0.95047_f32).abs < 0.05_f32
    assert_true (xyz.y - 1.0_f32).abs < 0.05_f32
    assert_true (xyz.z - 1.08883_f32).abs < 0.05_f32

    # 4. CIE-Lab & Delta-E
    lab = white.lab
    assert_true (lab.l - 100.0_f32).abs < 0.5_f32
    assert_eq white.delta_e(white), 0.0_f32
    black = Godot::Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
    assert_true (white.delta_e(black) - 100.0_f32).abs < 1.0_f32

    # 5. Oklab & Oklch
    oklab = white.oklab
    assert_true (oklab.l - 1.0_f32).abs < 0.01_f32
    oklch = oklab.to_oklch
    assert_true (oklch.l - 1.0_f32).abs < 0.01_f32
    assert_true oklch.c.abs < 0.01_f32

    # 6. Correlated Color Temperature
    warm = Godot::Color.from_temperature(3000)
    assert_true warm.r > warm.b
    cool = Godot::Color.from_temperature(9000)
    assert_true cool.b > cool.g
  end

  test "Pillar 4: Color harmonies (complementary, triadic, tetradic, analogous, split-complementary)" do
    red = Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)

    # 1. Complementary (+180° / 0.5)
    comp = red.complementary
    assert_true (comp.h - 0.5_f32).abs < 0.02_f32

    # 2. Triadic (+120°, +240°)
    t1, t2, t3 = red.triadic
    assert_true (t1.h - 0.0_f32).abs < 0.02_f32
    assert_true (t2.h - 0.3333_f32).abs < 0.02_f32
    assert_true (t3.h - 0.6667_f32).abs < 0.02_f32

    # 3. Tetradic (+90°, +180°, +270°)
    q1, q2, q3, q4 = red.tetradic
    assert_true (q1.h - 0.0_f32).abs < 0.02_f32
    assert_true (q2.h - 0.25_f32).abs < 0.02_f32
    assert_true (q3.h - 0.50_f32).abs < 0.02_f32
    assert_true (q4.h - 0.75_f32).abs < 0.02_f32

    # 4. Analogous
    a1, a2, a3 = red.analogous(30.0_f32)
    assert_eq a2, red

    # 5. Split-complementary
    s1, s2, s3 = red.split_complementary(30.0_f32)
    assert_eq s1, red
  end

  test "Pillar 5: Relative HSV adjustments and smooth color blending" do
    red = Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
    blue = Godot::Color.new(0.0_f32, 0.0_f32, 1.0_f32, 1.0_f32)

    # 1. adjust_hsv
    adj = red.adjust_hsv(delta_h: 0.15, delta_s: -0.1, delta_v: -0.2)
    assert_true (adj.h - 0.15_f32).abs < 0.02_f32
    assert_true (adj.s - 0.9_f32).abs < 0.02_f32
    assert_true (adj.v - 0.8_f32).abs < 0.02_f32

    # 2. blend_hsv
    hsv_mid = red.blend_hsv(blue, 0.5)
    assert_eq hsv_mid.a, 1.0_f32

    # 3. blend_lab
    lab_mid = red.blend_lab(blue, 0.5)
    assert_eq lab_mid.a, 1.0_f32

    # 4. blend_oklab
    oklab_mid = red.blend_oklab(blue, 0.5)
    assert_eq oklab_mid.a, 1.0_f32
  end

  test "Pillar 6: WCAG 2.1 contrast calculations and accessible text color" do
    white = Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
    black = Godot::Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)

    # 1. Contrast ratio bounds
    ratio = white.contrast_ratio(black)
    assert_true (ratio - 21.0_f32).abs < 0.05_f32
    assert_true (black.contrast_ratio(white) - 21.0_f32).abs < 0.05_f32
    assert_true (white.contrast_ratio(white) - 1.0_f32).abs < 0.01_f32

    # 2. WCAG AA & AAA thresholds
    assert_true white.meets_wcag_aa?(black)
    assert_true white.meets_wcag_aaa?(black)
    assert_false white.meets_wcag_aa?(white)

    # 3. Accessible text color selection
    assert_eq white.accessible_text_color, black
    assert_eq black.accessible_text_color, white

    dark_bg = Godot::Color.new(0.1_f32, 0.1_f32, 0.1_f32, 1.0_f32)
    assert_eq dark_bg.accessible_text_color, white
  end

  test "Pillar 7: Mathematical zero memory leak verification" do
    assert_no_leak do
      50.times do
        c = Godot::Color.new(0.4_f32, 0.7_f32, 0.2_f32, 1.0_f32)
        _ = c.to_hsv
        _ = c.to_hsl
        _ = c.to_cmyk
        _ = c.to_xyz
        _ = c.to_lab
        _ = c.to_oklab
        _ = c.to_oklch
        _ = c.complementary
        _ = c.triadic
        _ = c.tetradic
        _ = c.luminance
        _ = c.contrast_ratio(Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32))
        _ = c.accessible_text_color
      end
    end
  end
end
