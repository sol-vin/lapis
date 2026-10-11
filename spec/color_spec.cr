require "./spec_helper"

describe "Godot::Color Color Space Extensions & Lapis Color Library" do
  describe "Godot::Color::HSV Struct & Color HSV Extensions" do
    it "constructs HSV representation and converts to/from Color" do
      # Pure Red: H=0, S=1, V=1
      red_hsv = Godot::Color::HSV.new(0.0_f32, 1.0_f32, 1.0_f32)
      red_hsv.h.should eq(0.0_f32)
      red_hsv.s.should eq(1.0_f32)
      red_hsv.v.should eq(1.0_f32)
      red_hsv.a.should eq(1.0_f32)

      red_color = red_hsv.to_color
      red_color.r.should eq(1.0_f32)
      red_color.g.should eq(0.0_f32)
      red_color.b.should eq(0.0_f32)

      # to_rgb alias
      red_hsv.to_rgb.should eq(red_color)

      # Color.new(hsv) constructor
      from_struct = Godot::Color.new(red_hsv)
      from_struct.r.should eq(1.0_f32)
      from_struct.g.should eq(0.0_f32)
      from_struct.b.should eq(0.0_f32)

      # Round trip via Color#to_hsv
      h, s, v = red_color.to_hsv
      h.should eq(0.0_f32)
      s.should eq(1.0_f32)
      v.should eq(1.0_f32)

      # Color#to_hsva
      h2, s2, v2, a2 = red_color.to_hsva
      h2.should eq(0.0_f32)
      s2.should eq(1.0_f32)
      v2.should eq(1.0_f32)
      a2.should eq(1.0_f32)

      # Color#hsv accessor
      extracted_hsv = red_color.hsv
      extracted_hsv.h.should eq(0.0_f32)
      extracted_hsv.s.should eq(1.0_f32)
      extracted_hsv.v.should eq(1.0_f32)
    end

    it "supports immutable with-builders on HSV" do
      hsv = Godot::Color::HSV.new(0.1_f32, 0.5_f32, 0.8_f32, 1.0_f32)
      hsv.with_h(0.5_f32).h.should eq(0.5_f32)
      hsv.with_s(0.9_f32).s.should eq(0.9_f32)
      hsv.with_v(1.0_f32).v.should eq(1.0_f32)
      hsv.with_a(0.4_f32).a.should eq(0.4_f32)

      # Original unchanged
      hsv.h.should eq(0.1_f32)
      hsv.s.should eq(0.5_f32)
      hsv.v.should eq(0.8_f32)
      hsv.a.should eq(1.0_f32)

      # String representation
      hsv.to_s.should contain("HSV(0.1, 0.5, 0.8, 1.0)")
    end

    it "supports mutable HSV property setters and Color non-mutating helpers" do
      c = Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
      c.h.should eq(0.0_f32)
      c.s.should eq(1.0_f32)
      c.v.should eq(1.0_f32)

      # Mutable property setters on Color
      c.h = 0.3333_f32 # Shift toward green
      (c.h - 0.3333_f32).abs.should be < 0.01_f32
      c.g.should be > 0.5_f32

      # Non-mutating with_* helpers
      c_blue = c.with_h(0.6667_f32)
      c_blue.b.should be > 0.5_f32
      c_desat = c.with_s(0.2_f32)
      c_desat.s.should be_close(0.2_f32, 0.02_f32)
      c_dim = c.with_v(0.4_f32)
      c_dim.v.should be_close(0.4_f32, 0.02_f32)
      c_translucent = c.with_alpha(0.5_f32)
      c_translucent.a.should eq(0.5_f32)

      # with_hsv keyword arguments
      c_custom = c.with_hsv(h: 0.5_f32, s: 0.8_f32, v: 0.9_f32, a: 0.75_f32)
      c_custom.a.should eq(0.75_f32)
    end

    it "calculates ITU-R BT.709 relative luminance" do
      white = Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
      black = Godot::Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
      red = Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
      green = Godot::Color.new(0.0_f32, 1.0_f32, 0.0_f32, 1.0_f32)
      blue = Godot::Color.new(0.0_f32, 0.0_f32, 1.0_f32, 1.0_f32)

      white.luminance.should be_close(1.0_f32, 0.001_f32)
      black.luminance.should eq(0.0_f32)
      red.luminance.should be_close(0.2126_f32, 0.001_f32)
      green.luminance.should be_close(0.7152_f32, 0.001_f32)
      blue.luminance.should be_close(0.0722_f32, 0.001_f32)
    end
  end

  describe "Intermediary Color Spaces (HSL, CMYK, XYZ, Lab, Oklab, Oklch)" do
    it "converts between Color and HSL" do
      pure_green = Godot::Color.new(0.0_f32, 1.0_f32, 0.0_f32, 1.0_f32)
      hsl = pure_green.hsl
      hsl.h.should be_close(1.0_f32 / 3.0_f32, 0.01_f32)
      hsl.s.should eq(1.0_f32)
      hsl.l.should eq(0.5_f32)

      # Round trip
      rebuilt = hsl.to_color
      rebuilt.g.should be_close(1.0_f32, 0.001_f32)
      rebuilt.r.should be_close(0.0_f32, 0.001_f32)
      rebuilt.b.should be_close(0.0_f32, 0.001_f32)

      # HSL with-builder
      hsl2 = hsl.with_h(0.0_f32).with_s(0.5_f32).with_l(0.7_f32).with_a(0.8_f32)
      hsl2.h.should eq(0.0_f32)
      hsl2.s.should eq(0.5_f32)
      hsl2.l.should eq(0.7_f32)
      hsl2.a.should eq(0.8_f32)

      # with_hsl helper
      adjusted = pure_green.with_hsl(l: 0.8_f32)
      adjusted.hsl.l.should be_close(0.8_f32, 0.02_f32)
    end

    it "converts between Color and CMYK" do
      pure_cyan = Godot::Color.new(0.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
      cmyk = pure_cyan.cmyk
      cmyk.c.should eq(1.0_f32)
      cmyk.m.should eq(0.0_f32)
      cmyk.y.should eq(0.0_f32)
      cmyk.k.should eq(0.0_f32)

      # Round trip
      from_cmyk = cmyk.to_color
      from_cmyk.r.should eq(0.0_f32)
      from_cmyk.g.should eq(1.0_f32)
      from_cmyk.b.should eq(1.0_f32)

      # CMYK with-builder
      cmyk2 = cmyk.with_c(0.2_f32).with_m(0.4_f32).with_y(0.6_f32).with_k(0.1_f32).with_a(0.9_f32)
      cmyk2.c.should eq(0.2_f32)
      cmyk2.m.should eq(0.4_f32)
      cmyk2.y.should eq(0.6_f32)
      cmyk2.k.should eq(0.1_f32)
      cmyk2.a.should eq(0.9_f32)
    end

    it "converts between Color and CIE-XYZ" do
      white = Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
      xyz = white.xyz
      # D65 standard white point: X=0.95047, Y=1.0, Z=1.08883
      xyz.x.should be_close(0.95047_f32, 0.05_f32)
      xyz.y.should be_close(1.0_f32, 0.05_f32)
      xyz.z.should be_close(1.08883_f32, 0.05_f32)

      # Round trip
      from_xyz = xyz.to_color
      from_xyz.r.should be_close(1.0_f32, 0.01_f32)
      from_xyz.g.should be_close(1.0_f32, 0.01_f32)
      from_xyz.b.should be_close(1.0_f32, 0.01_f32)
    end

    it "converts between Color and CIE-Lab and computes Delta-E" do
      white = Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
      lab = white.lab
      lab.l.should be_close(100.0_f32, 0.5_f32)
      lab.a.should be_close(0.0_f32, 0.5_f32)
      lab.b.should be_close(0.0_f32, 0.5_f32)

      # Delta-E between identical colors is 0
      lab.delta_e(lab).should eq(0.0_f32)
      white.delta_e(white).should eq(0.0_f32)

      # Delta-E between white and black is ~100
      black = Godot::Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
      white.delta_e(black).should be_close(100.0_f32, 1.0_f32)
    end

    it "converts between Color and Oklab / Oklch" do
      white = Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
      oklab = white.oklab
      oklab.l.should be_close(1.0_f32, 0.01_f32)
      oklab.a.should be_close(0.0_f32, 0.01_f32)
      oklab.b.should be_close(0.0_f32, 0.01_f32)

      # Round trip to Oklch
      oklch = oklab.to_oklch
      oklch.l.should be_close(1.0_f32, 0.01_f32)
      oklch.c.should be_close(0.0_f32, 0.01_f32)

      # Round trip back to Color
      from_oklch = oklch.to_color
      from_oklch.r.should be_close(1.0_f32, 0.02_f32)
      from_oklch.g.should be_close(1.0_f32, 0.02_f32)
      from_oklch.b.should be_close(1.0_f32, 0.02_f32)
    end

    it "constructs colors from correlated color temperature (Kelvin)" do
      warm = Godot::Color.from_temperature(2700) # Household warm incandescent
      warm.r.should be > warm.b                  # Red dominant

      cool = Godot::Color.from_temperature(10000) # Deep blue sky
      cool.b.should be > cool.g                   # Blue dominant
    end
  end

  describe "Color Harmonies & Palette Adjustments" do
    it "computes complementary, triadic, and tetradic harmonies" do
      red = Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32) # H=0

      # Complementary is cyan (H=0.5)
      comp = red.complementary
      comp.h.should be_close(0.5_f32, 0.02_f32)

      # Triadic (+120°, +240°)
      t1, t2, t3 = red.triadic
      t1.h.should be_close(0.0_f32, 0.02_f32)
      t2.h.should be_close(0.3333_f32, 0.02_f32)
      t3.h.should be_close(0.6667_f32, 0.02_f32)

      # Tetradic (+90°, +180°, +270°)
      q1, q2, q3, q4 = red.tetradic
      q1.h.should be_close(0.0_f32, 0.02_f32)
      q2.h.should be_close(0.25_f32, 0.02_f32)
      q3.h.should be_close(0.50_f32, 0.02_f32)
      q4.h.should be_close(0.75_f32, 0.02_f32)
    end

    it "computes analogous and split-complementary harmonies" do
      red = Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)

      # Analogous (30° offset by default)
      a1, a2, a3 = red.analogous(30.0_f32)
      a2.should eq(red)

      # Split-complementary (150° and 210° from base)
      s1, s2, s3 = red.split_complementary(30.0_f32)
      s1.should eq(red)
    end

    it "adjusts and blends colors in HSV, Lab, and Oklab spaces" do
      red = Godot::Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
      blue = Godot::Color.new(0.0_f32, 0.0_f32, 1.0_f32, 1.0_f32)

      # Relative HSV adjustment
      shifted = red.adjust_hsv(delta_h: 0.1, delta_s: -0.2, delta_v: -0.1)
      shifted.h.should be_close(0.1_f32, 0.02_f32)
      shifted.s.should be_close(0.8_f32, 0.02_f32)
      shifted.v.should be_close(0.9_f32, 0.02_f32)

      # HSV blend
      hsv_mid = red.blend_hsv(blue, 0.5)
      hsv_mid.a.should eq(1.0_f32)

      # Lab blend
      lab_mid = red.blend_lab(blue, 0.5)
      lab_mid.a.should eq(1.0_f32)

      # Oklab blend
      oklab_mid = red.blend_oklab(blue, 0.5)
      oklab_mid.a.should eq(1.0_f32)
    end
  end

  describe "WCAG 2.1 Contrast Calculations" do
    it "computes standard contrast ratios and threshold compliance" do
      white = Godot::Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
      black = Godot::Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)

      # White vs Black is 21.0 : 1
      ratio = white.contrast_ratio(black)
      ratio.should be_close(21.0_f32, 0.05_f32)

      # Symmetric: black.contrast_ratio(white) == white.contrast_ratio(black)
      black.contrast_ratio(white).should be_close(21.0_f32, 0.05_f32)

      # Self-contrast is 1.0 : 1
      white.contrast_ratio(white).should be_close(1.0_f32, 0.01_f32)

      # WCAG AA and AAA thresholds
      white.meets_wcag_aa?(black).should be_true
      white.meets_wcag_aaa?(black).should be_true

      # Accessible text color selection
      white.accessible_text_color.should eq(black)
      black.accessible_text_color.should eq(white)

      # Mid grey background (0.2, 0.2, 0.2) against black and white
      dark_gray = Godot::Color.new(0.15_f32, 0.15_f32, 0.15_f32, 1.0_f32)
      dark_gray.accessible_text_color.should eq(white)
    end
  end
end
