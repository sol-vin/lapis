# =============================================================================
# Lapis - Advanced Color Conversion & Manipulation Library (require "lapis/color")
# =============================================================================

require "../lapis"

module Godot
  struct Color
    # =========================================================================
    # Constants & Conversion Tables
    # =========================================================================
    private XN         = 0.95047_f32
    private YN         = 1.00000_f32
    private ZN         = 1.08883_f32
    private DELTA      = 6.0_f32 / 29.0_f32
    private DELTA_CUBE = DELTA * DELTA * DELTA

    private def self._srgb_to_linear(c : Float32) : Float32
      c <= 0.04045_f32 ? c / 12.92_f32 : ((c + 0.055_f32) / 1.055_f32) ** 2.4_f32
    end

    private def self._linear_to_srgb(c : Float32) : Float32
      c <= 0.0031308_f32 ? c * 12.92_f32 : 1.055_f32 * (c ** (1.0_f32 / 2.4_f32)) - 0.055_f32
    end

    private def self._f_lab(t : Float32) : Float32
      t > DELTA_CUBE ? (t ** (1.0_f32 / 3.0_f32)) : (t / (3.0_f32 * DELTA * DELTA) + 4.0_f32 / 29.0_f32)
    end

    private def self._f_lab_inv(t : Float32) : Float32
      t > DELTA ? (t ** 3.0_f32) : 3.0_f32 * DELTA * DELTA * (t - 4.0_f32 / 29.0_f32)
    end

    # =========================================================================
    # Intermediary Color Space Structs
    # =========================================================================

    # Intermediary representation for Hue, Saturation, Lightness, and Alpha
    struct HSL
      property h : Float32
      property s : Float32
      property l : Float32
      property a : Float32

      def initialize(@h : Float32, @s : Float32, @l : Float32, @a : Float32 = 1.0_f32)
      end

      def initialize(h : Number, s : Number, l : Number, a : Number = 1.0)
        @h = h.to_f32
        @s = s.to_f32
        @l = l.to_f32
        @a = a.to_f32
      end

      def h=(val : Number) : Void
        @h = val.to_f32
      end

      def s=(val : Number) : Void
        @s = val.to_f32
      end

      def l=(val : Number) : Void
        @l = val.to_f32
      end

      def a=(val : Number) : Void
        @a = val.to_f32
      end

      def to_color : Godot::Color
        Godot::Color.from_hsl(@h, @s, @l, @a)
      end

      def to_rgb : Godot::Color
        to_color
      end

      def with_h(new_h : Number) : HSL
        HSL.new(new_h.to_f32, @s, @l, @a)
      end

      def with_s(new_s : Number) : HSL
        HSL.new(@h, new_s.to_f32, @l, @a)
      end

      def with_l(new_l : Number) : HSL
        HSL.new(@h, @s, new_l.to_f32, @a)
      end

      def with_a(new_a : Number) : HSL
        HSL.new(@h, @s, @l, new_a.to_f32)
      end

      def to_s(io : IO) : Void
        io << "HSL(" << @h << ", " << @s << ", " << @l << ", " << @a << ")"
      end
    end

    # Intermediary representation for Cyan, Magenta, Yellow, Key (Black), and Alpha
    struct CMYK
      property c : Float32
      property m : Float32
      property y : Float32
      property k : Float32
      property a : Float32

      def initialize(@c : Float32, @m : Float32, @y : Float32, @k : Float32, @a : Float32 = 1.0_f32)
      end

      def initialize(c : Number, m : Number, y : Number, k : Number, a : Number = 1.0)
        @c = c.to_f32
        @m = m.to_f32
        @y = y.to_f32
        @k = k.to_f32
        @a = a.to_f32
      end

      def c=(val : Number) : Void
        @c = val.to_f32
      end

      def m=(val : Number) : Void
        @m = val.to_f32
      end

      def y=(val : Number) : Void
        @y = val.to_f32
      end

      def k=(val : Number) : Void
        @k = val.to_f32
      end

      def a=(val : Number) : Void
        @a = val.to_f32
      end

      def to_color : Godot::Color
        Godot::Color.from_cmyk(@c, @m, @y, @k, @a)
      end

      def to_rgb : Godot::Color
        to_color
      end

      def with_c(val : Number) : CMYK
        CMYK.new(val.to_f32, @m, @y, @k, @a)
      end

      def with_m(val : Number) : CMYK
        CMYK.new(@c, val.to_f32, @y, @k, @a)
      end

      def with_y(val : Number) : CMYK
        CMYK.new(@c, @m, val.to_f32, @k, @a)
      end

      def with_k(val : Number) : CMYK
        CMYK.new(@c, @m, @y, val.to_f32, @a)
      end

      def with_a(val : Number) : CMYK
        CMYK.new(@c, @m, @y, @k, val.to_f32)
      end

      def to_s(io : IO) : Void
        io << "CMYK(" << @c << ", " << @m << ", " << @y << ", " << @k << ", " << @a << ")"
      end
    end

    # Intermediary representation for CIE 1931 XYZ (D65 standard illuminant)
    struct XYZ
      property x : Float32
      property y : Float32
      property z : Float32
      property a : Float32

      def initialize(@x : Float32, @y : Float32, @z : Float32, @a : Float32 = 1.0_f32)
      end

      def initialize(x : Number, y : Number, z : Number, a : Number = 1.0)
        @x = x.to_f32
        @y = y.to_f32
        @z = z.to_f32
        @a = a.to_f32
      end

      def x=(val : Number) : Void
        @x = val.to_f32
      end

      def y=(val : Number) : Void
        @y = val.to_f32
      end

      def z=(val : Number) : Void
        @z = val.to_f32
      end

      def a=(val : Number) : Void
        @a = val.to_f32
      end

      def to_color : Godot::Color
        Godot::Color.from_xyz(@x, @y, @z, @a)
      end

      def to_rgb : Godot::Color
        to_color
      end

      def to_s(io : IO) : Void
        io << "XYZ(" << @x << ", " << @y << ", " << @z << ", " << @a << ")"
      end
    end

    # Intermediary representation for CIE 1976 L*a*b* (CIELAB)
    struct Lab
      property l : Float32
      property a : Float32
      property b : Float32
      property alpha : Float32

      def initialize(@l : Float32, @a : Float32, @b : Float32, @alpha : Float32 = 1.0_f32)
      end

      def initialize(l : Number, a : Number, b : Number, alpha : Number = 1.0)
        @l = l.to_f32
        @a = a.to_f32
        @b = b.to_f32
        @alpha = alpha.to_f32
      end

      def l=(val : Number) : Void
        @l = val.to_f32
      end

      def a=(val : Number) : Void
        @a = val.to_f32
      end

      def b=(val : Number) : Void
        @b = val.to_f32
      end

      def alpha=(val : Number) : Void
        @alpha = val.to_f32
      end

      def to_color : Godot::Color
        Godot::Color.from_lab(@l, @a, @b, @alpha)
      end

      def to_rgb : Godot::Color
        to_color
      end

      # Computes perceptual color difference (CIE76 Delta-E)
      def delta_e(other : Lab) : Float32
        dl = @l - other.l
        da = @a - other.a
        db = @b - other.b
        Math.sqrt(dl * dl + da * da + db * db).to_f32
      end

      def to_s(io : IO) : Void
        io << "Lab(" << @l << ", " << @a << ", " << @b << ", " << @alpha << ")"
      end
    end

    # Intermediary representation for Oklab (Björn Ottosson, 2020)
    struct Oklab
      property l : Float32
      property a : Float32
      property b : Float32
      property alpha : Float32

      def initialize(@l : Float32, @a : Float32, @b : Float32, @alpha : Float32 = 1.0_f32)
      end

      def initialize(l : Number, a : Number, b : Number, alpha : Number = 1.0)
        @l = l.to_f32
        @a = a.to_f32
        @b = b.to_f32
        @alpha = alpha.to_f32
      end

      def l=(val : Number) : Void
        @l = val.to_f32
      end

      def a=(val : Number) : Void
        @a = val.to_f32
      end

      def b=(val : Number) : Void
        @b = val.to_f32
      end

      def alpha=(val : Number) : Void
        @alpha = val.to_f32
      end

      def to_color : Godot::Color
        Godot::Color.from_oklab(@l, @a, @b, @alpha)
      end

      def to_rgb : Godot::Color
        to_color
      end

      def to_oklch : Oklch
        c = Math.sqrt(@a * @a + @b * @b).to_f32
        h_rad = Math.atan2(@b, @a)
        h_deg = (h_rad * (180.0_f32 / Math::PI.to_f32) + 360.0_f32) % 360.0_f32
        Oklch.new(@l, c, h_deg, @alpha)
      end

      def to_s(io : IO) : Void
        io << "Oklab(" << @l << ", " << @a << ", " << @b << ", " << @alpha << ")"
      end
    end

    # Intermediary representation for Oklch (Cylindrical Oklab: Lightness, Chroma, Hue in degrees)
    struct Oklch
      property l : Float32
      property c : Float32
      property h : Float32
      property alpha : Float32

      def initialize(@l : Float32, @c : Float32, @h : Float32, @alpha : Float32 = 1.0_f32)
      end

      def initialize(l : Number, c : Number, h : Number, alpha : Number = 1.0)
        @l = l.to_f32
        @c = c.to_f32
        @h = h.to_f32
        @alpha = alpha.to_f32
      end

      def l=(val : Number) : Void
        @l = val.to_f32
      end

      def c=(val : Number) : Void
        @c = val.to_f32
      end

      def h=(val : Number) : Void
        @h = val.to_f32
      end

      def alpha=(val : Number) : Void
        @alpha = val.to_f32
      end

      def to_oklab : Oklab
        rad = @h * (Math::PI.to_f32 / 180.0_f32)
        a_val = @c * Math.cos(rad).to_f32
        b_val = @c * Math.sin(rad).to_f32
        Oklab.new(@l, a_val, b_val, @alpha)
      end

      def to_color : Godot::Color
        to_oklab.to_color
      end

      def to_rgb : Godot::Color
        to_color
      end

      def to_s(io : IO) : Void
        io << "Oklch(" << @l << ", " << @c << ", " << @h << ", " << @alpha << ")"
      end
    end

    # =========================================================================
    # Additional Godot::Color Constructors
    # =========================================================================

    def initialize(hsl : HSL)
      c = hsl.to_color
      @r = c.r; @g = c.g; @b = c.b; @a = c.a
    end

    def initialize(cmyk : CMYK)
      c = cmyk.to_color
      @r = c.r; @g = c.g; @b = c.b; @a = c.a
    end

    def initialize(xyz : XYZ)
      c = xyz.to_color
      @r = c.r; @g = c.g; @b = c.b; @a = c.a
    end

    def initialize(lab : Lab)
      c = lab.to_color
      @r = c.r; @g = c.g; @b = c.b; @a = c.a
    end

    def initialize(oklab : Oklab)
      c = oklab.to_color
      @r = c.r; @g = c.g; @b = c.b; @a = c.a
    end

    def initialize(oklch : Oklch)
      c = oklch.to_color
      @r = c.r; @g = c.g; @b = c.b; @a = c.a
    end

    # =========================================================================
    # HSL Conversions
    # =========================================================================

    def to_hsl : Tuple(Float32, Float32, Float32)
      min = Math.min(@r, Math.min(@g, @b))
      max = Math.max(@r, Math.max(@g, @b))
      delta = max - min
      l = (max + min) * 0.5_f32

      if delta == 0.0_f32
        {0.0_f32, 0.0_f32, l}
      else
        s = l > 0.5_f32 ? delta / (2.0_f32 - max - min) : delta / (max + min)
        if @r == max
          h = (@g - @b) / delta
        elsif @g == max
          h = 2.0_f32 + (@b - @r) / delta
        else
          h = 4.0_f32 + (@r - @g) / delta
        end
        h /= 6.0_f32
        h += 1.0_f32 if h < 0.0_f32
        {h, s, l}
      end
    end

    def to_hsla : Tuple(Float32, Float32, Float32, Float32)
      h, s, l = to_hsl
      {h, s, l, @a}
    end

    def hsl : HSL
      h, s, l = to_hsl
      HSL.new(h, s, l, @a)
    end

    def self.from_hsl(h : Number, s : Number, l : Number, a : Number = 1.0) : Color
      h_f = ((h.to_f32 % 1.0_f32) + 1.0_f32) % 1.0_f32
      s_f = s.to_f32.clamp(0.0_f32, 1.0_f32)
      l_f = l.to_f32.clamp(0.0_f32, 1.0_f32)
      a_f = a.to_f32.clamp(0.0_f32, 1.0_f32)

      if s_f == 0.0_f32
        return Color.new(l_f, l_f, l_f, a_f)
      end

      q = l_f < 0.5_f32 ? l_f * (1.0_f32 + s_f) : (l_f + s_f) - (l_f * s_f)
      p = 2.0_f32 * l_f - q

      r = _hue_to_rgb(p, q, h_f + 1.0_f32 / 3.0_f32)
      g = _hue_to_rgb(p, q, h_f)
      b = _hue_to_rgb(p, q, h_f - 1.0_f32 / 3.0_f32)
      Color.new(r, g, b, a_f)
    end

    def self.hsl(h : Number, s : Number, l : Number, a : Number = 1.0) : Color
      from_hsl(h, s, l, a)
    end

    def self.from_hsl(hsl : HSL) : Color
      hsl.to_color
    end

    def self.hsl(hsl : HSL) : Color
      hsl.to_color
    end

    private def self._hue_to_rgb(p : Float32, q : Float32, t : Float32) : Float32
      tc = t
      tc += 1.0_f32 if tc < 0.0_f32
      tc -= 1.0_f32 if tc > 1.0_f32
      if tc < 1.0_f32 / 6.0_f32
        p + (q - p) * 6.0_f32 * tc
      elsif tc < 1.0_f32 / 2.0_f32
        q
      elsif tc < 2.0_f32 / 3.0_f32
        p + (q - p) * (2.0_f32 / 3.0_f32 - tc) * 6.0_f32
      else
        p
      end
    end

    def with_hsl(*, h : Number? = nil, s : Number? = nil, l : Number? = nil, a : Number? = nil) : Color
      cur_h, cur_s, cur_l, cur_a = to_hsla
      Color.from_hsl(
        h ? h.not_nil! : cur_h,
        s ? s.not_nil! : cur_s,
        l ? l.not_nil! : cur_l,
        a ? a.not_nil! : cur_a
      )
    end

    # =========================================================================
    # CMYK Conversions
    # =========================================================================

    def to_cmyk : Tuple(Float32, Float32, Float32, Float32)
      k = 1.0_f32 - Math.max(@r, Math.max(@g, @b))
      if k >= 0.99999_f32
        {0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32}
      else
        inv = 1.0_f32 - k
        c = ((1.0_f32 - @r - k) / inv).clamp(0.0_f32, 1.0_f32)
        m = ((1.0_f32 - @g - k) / inv).clamp(0.0_f32, 1.0_f32)
        y = ((1.0_f32 - @b - k) / inv).clamp(0.0_f32, 1.0_f32)
        {c, m, y, k.clamp(0.0_f32, 1.0_f32)}
      end
    end

    def cmyk : CMYK
      c, m, y, k = to_cmyk
      CMYK.new(c, m, y, k, @a)
    end

    def self.from_cmyk(c : Number, m : Number, y : Number, k : Number, a : Number = 1.0) : Color
      k_f = k.to_f32.clamp(0.0_f32, 1.0_f32)
      inv = 1.0_f32 - k_f
      r = ((1.0_f32 - c.to_f32.clamp(0.0_f32, 1.0_f32)) * inv).clamp(0.0_f32, 1.0_f32)
      g = ((1.0_f32 - m.to_f32.clamp(0.0_f32, 1.0_f32)) * inv).clamp(0.0_f32, 1.0_f32)
      b = ((1.0_f32 - y.to_f32.clamp(0.0_f32, 1.0_f32)) * inv).clamp(0.0_f32, 1.0_f32)
      Color.new(r, g, b, a.to_f32)
    end

    def self.cmyk(c : Number, m : Number, y : Number, k : Number, a : Number = 1.0) : Color
      from_cmyk(c, m, y, k, a)
    end

    def self.from_cmyk(cmyk : CMYK) : Color
      cmyk.to_color
    end

    def self.cmyk(cmyk : CMYK) : Color
      cmyk.to_color
    end

    # =========================================================================
    # CIE-XYZ (D65) Conversions
    # =========================================================================

    def to_xyz : Tuple(Float32, Float32, Float32)
      lr = _srgb_to_linear(@r)
      lg = _srgb_to_linear(@g)
      lb = _srgb_to_linear(@b)

      x = lr * 0.4124564_f32 + lg * 0.3575761_f32 + lb * 0.1804375_f32
      y = lr * 0.2126729_f32 + lg * 0.7151522_f32 + lb * 0.0721750_f32
      z = lr * 0.0193339_f32 + lg * 0.1191920_f32 + lb * 0.9503041_f32
      {x, y, z}
    end

    def xyz : XYZ
      x, y, z = to_xyz
      XYZ.new(x, y, z, @a)
    end

    def self.from_xyz(x : Number, y : Number, z : Number, a : Number = 1.0) : Color
      xf = x.to_f32
      yf = y.to_f32
      zf = z.to_f32

      lr = xf * 3.2404542_f32 + yf * -1.5371385_f32 + zf * -0.4985314_f32
      lg = xf * -0.9692660_f32 + yf * 1.8760108_f32 + zf * 0.0415560_f32
      lb = xf * 0.0556434_f32 + yf * -0.2040259_f32 + zf * 1.0572252_f32

      r = _linear_to_srgb(lr).clamp(0.0_f32, 1.0_f32)
      g = _linear_to_srgb(lg).clamp(0.0_f32, 1.0_f32)
      b = _linear_to_srgb(lb).clamp(0.0_f32, 1.0_f32)
      Color.new(r, g, b, a.to_f32)
    end

    def self.xyz(x : Number, y : Number, z : Number, a : Number = 1.0) : Color
      from_xyz(x, y, z, a)
    end

    # =========================================================================
    # CIE-L*a*b* Conversions
    # =========================================================================

    def to_lab : Tuple(Float32, Float32, Float32)
      x, y, z = to_xyz
      fx = _f_lab(x / XN)
      fy = _f_lab(y / YN)
      fz = _f_lab(z / ZN)

      l = 116.0_f32 * fy - 16.0_f32
      a_val = 500.0_f32 * (fx - fy)
      b_val = 200.0_f32 * (fy - fz)
      {l, a_val, b_val}
    end

    def lab : Lab
      l, a_val, b_val = to_lab
      Lab.new(l, a_val, b_val, @a)
    end

    def self.from_lab(l : Number, a : Number, b : Number, alpha : Number = 1.0) : Color
      lf = l.to_f32
      af = a.to_f32
      bf = b.to_f32

      fy = (lf + 16.0_f32) / 116.0_f32
      fx = fy + af / 500.0_f32
      fz = fy - bf / 200.0_f32

      x = _f_lab_inv(fx) * XN
      y = _f_lab_inv(fy) * YN
      z = _f_lab_inv(fz) * ZN
      from_xyz(x, y, z, alpha)
    end

    def self.lab(l : Number, a : Number, b : Number, alpha : Number = 1.0) : Color
      from_lab(l, a, b, alpha)
    end

    def delta_e(other : Color) : Float32
      lab.delta_e(other.lab)
    end

    # =========================================================================
    # Oklab & Oklch Conversions
    # =========================================================================

    def to_oklab : Tuple(Float32, Float32, Float32)
      lr = _srgb_to_linear(@r)
      lg = _srgb_to_linear(@g)
      lb = _srgb_to_linear(@b)

      l_ = (0.4122214708_f32 * lr + 0.5363325363_f32 * lg + 0.0514459929_f32 * lb) ** (1.0_f32 / 3.0_f32)
      m_ = (0.2119034982_f32 * lr + 0.6806995451_f32 * lg + 0.1073969566_f32 * lb) ** (1.0_f32 / 3.0_f32)
      s_ = (0.0883024619_f32 * lr + 0.2817188376_f32 * lg + 0.6299787005_f32 * lb) ** (1.0_f32 / 3.0_f32)

      l = 0.2104542553_f32 * l_ + 0.7936177850_f32 * m_ - 0.0040720468_f32 * s_
      a_val = 1.9779984951_f32 * l_ - 2.4285922050_f32 * m_ + 0.4505937099_f32 * s_
      b_val = 0.0259040371_f32 * l_ + 0.7827717662_f32 * m_ - 0.8086757660_f32 * s_
      {l, a_val, b_val}
    end

    def oklab : Oklab
      l, a_val, b_val = to_oklab
      Oklab.new(l, a_val, b_val, @a)
    end

    def to_oklch : Tuple(Float32, Float32, Float32)
      l, a_val, b_val = to_oklab
      c = Math.sqrt(a_val * a_val + b_val * b_val).to_f32
      h_rad = Math.atan2(b_val, a_val)
      h_deg = (h_rad * (180.0_f32 / Math::PI.to_f32) + 360.0_f32) % 360.0_f32
      {l, c, h_deg}
    end

    def oklch : Oklch
      l, c, h = to_oklch
      Oklch.new(l, c, h, @a)
    end

    def self.from_oklab(l : Number, a : Number, b : Number, alpha : Number = 1.0) : Color
      lf = l.to_f32
      af = a.to_f32
      bf = b.to_f32

      l_ = (lf + 0.3963377774_f32 * af + 0.2158037573_f32 * bf) ** 3.0_f32
      m_ = (lf - 0.1055613458_f32 * af - 0.0638541728_f32 * bf) ** 3.0_f32
      s_ = (lf - 0.0894841775_f32 * af - 1.2914855480_f32 * bf) ** 3.0_f32

      lr = +4.0767416621_f32 * l_ - 3.3077115913_f32 * m_ + 0.2309699292_f32 * s_
      lg = -1.2684380046_f32 * l_ + 2.6097574011_f32 * m_ - 0.3413193965_f32 * s_
      lb = -0.0041960863_f32 * l_ - 0.7034186147_f32 * m_ + 1.7076147010_f32 * s_

      r = _linear_to_srgb(lr).clamp(0.0_f32, 1.0_f32)
      g = _linear_to_srgb(lg).clamp(0.0_f32, 1.0_f32)
      b = _linear_to_srgb(lb).clamp(0.0_f32, 1.0_f32)
      Color.new(r, g, b, alpha.to_f32)
    end

    def self.oklab(l : Number, a : Number, b : Number, alpha : Number = 1.0) : Color
      from_oklab(l, a, b, alpha)
    end

    def self.from_oklch(l : Number, c : Number, h : Number, alpha : Number = 1.0) : Color
      rad = h.to_f32 * (Math::PI.to_f32 / 180.0_f32)
      a_val = c.to_f32 * Math.cos(rad).to_f32
      b_val = c.to_f32 * Math.sin(rad).to_f32
      from_oklab(l, a_val, b_val, alpha)
    end

    def self.oklch(l : Number, c : Number, h : Number, alpha : Number = 1.0) : Color
      from_oklch(l, c, h, alpha)
    end

    # =========================================================================
    # Correlated Color Temperature (Kelvin: 1000K – 40000K)
    # =========================================================================

    # Constructs a Color corresponding to the blackbody radiation temperature in Kelvin.
    def self.from_temperature(kelvin : Number, alpha : Number = 1.0) : Color
      temp = (kelvin.to_f32 / 100.0_f32).clamp(10.0_f32, 400.0_f32)

      # Red
      r = if temp <= 66.0_f32
            1.0_f32
          else
            val = temp - 60.0_f32
            (329.698727446_f32 * (val ** -0.1332047592_f32)) / 255.0_f32
          end

      # Green
      g = if temp <= 66.0_f32
            val = temp
            (99.4708025861_f32 * Math.log(val) - 161.1195681661_f32) / 255.0_f32
          else
            val = temp - 60.0_f32
            (288.1221695283_f32 * (val ** -0.0755148492_f32)) / 255.0_f32
          end

      # Blue
      b = if temp >= 66.0_f32
            1.0_f32
          elsif temp <= 19.0_f32
            0.0_f32
          else
            val = temp - 10.0_f32
            (138.5177312231_f32 * Math.log(val) - 305.0447927307_f32) / 255.0_f32
          end

      Color.new(r.clamp(0.0_f32, 1.0_f32), g.clamp(0.0_f32, 1.0_f32), b.clamp(0.0_f32, 1.0_f32), alpha.to_f32)
    end

    def self.temperature(kelvin : Number, alpha : Number = 1.0) : Color
      from_temperature(kelvin, alpha)
    end

    # =========================================================================
    # Harmonies, Palettes & Adjustments
    # =========================================================================

    # Returns the complementary color (opposite hue on color wheel, +180°)
    def complementary : Color
      with_h((h + 0.5_f32) % 1.0_f32)
    end

    # Returns a 3-color triadic harmony (+120°, +240°)
    def triadic : Tuple(Color, Color, Color)
      cur_h, cur_s, cur_v = to_hsv
      {
        self,
        Color.from_hsv((cur_h + 1.0_f32 / 3.0_f32) % 1.0_f32, cur_s, cur_v, @a),
        Color.from_hsv((cur_h + 2.0_f32 / 3.0_f32) % 1.0_f32, cur_s, cur_v, @a),
      }
    end

    # Returns a 4-color tetradic harmony (+90°, +180°, +270°)
    def tetradic : Tuple(Color, Color, Color, Color)
      cur_h, cur_s, cur_v = to_hsv
      {
        self,
        Color.from_hsv((cur_h + 0.25_f32) % 1.0_f32, cur_s, cur_v, @a),
        Color.from_hsv((cur_h + 0.50_f32) % 1.0_f32, cur_s, cur_v, @a),
        Color.from_hsv((cur_h + 0.75_f32) % 1.0_f32, cur_s, cur_v, @a),
      }
    end

    # Returns a 3-color analogous palette
    def analogous(angle : Float32 = 30.0_f32) : Tuple(Color, Color, Color)
      cur_h, cur_s, cur_v = to_hsv
      offset = angle / 360.0_f32
      {
        Color.from_hsv((cur_h - offset + 1.0_f32) % 1.0_f32, cur_s, cur_v, @a),
        self,
        Color.from_hsv((cur_h + offset) % 1.0_f32, cur_s, cur_v, @a),
      }
    end

    # Returns a 3-color split-complementary palette
    def split_complementary(angle : Float32 = 30.0_f32) : Tuple(Color, Color, Color)
      cur_h, cur_s, cur_v = to_hsv
      offset = angle / 360.0_f32
      comp_h = (cur_h + 0.5_f32) % 1.0_f32
      {
        self,
        Color.from_hsv((comp_h - offset + 1.0_f32) % 1.0_f32, cur_s, cur_v, @a),
        Color.from_hsv((comp_h + offset) % 1.0_f32, cur_s, cur_v, @a),
      }
    end

    # Adjusts hue, saturation, and value by relative offsets
    def adjust_hsv(delta_h : Number = 0.0, delta_s : Number = 0.0, delta_v : Number = 0.0) : Color
      cur_h, cur_s, cur_v = to_hsv
      new_h = ((cur_h + delta_h.to_f32) % 1.0_f32 + 1.0_f32) % 1.0_f32
      new_s = (cur_s + delta_s.to_f32).clamp(0.0_f32, 1.0_f32)
      new_v = (cur_v + delta_v.to_f32).clamp(0.0_f32, 1.0_f32)
      Color.from_hsv(new_h, new_s, new_v, @a)
    end

    # Blends colors smoothly in cylindrical HSV space
    def blend_hsv(other : Color, weight : Number = 0.5) : Color
      w = weight.to_f32.clamp(0.0_f32, 1.0_f32)
      inv_w = 1.0_f32 - w
      h1, s1, v1 = to_hsv
      h2, s2, v2 = other.to_hsv

      # Shortest path along circular hue
      diff = (h2 - h1) % 1.0_f32
      diff += 1.0_f32 if diff < -0.5_f32
      diff -= 1.0_f32 if diff > 0.5_f32
      blend_h = (h1 + diff * w + 1.0_f32) % 1.0_f32
      blend_s = s1 * inv_w + s2 * w
      blend_v = v1 * inv_w + v2 * w
      blend_a = @a * inv_w + other.a * w
      Color.from_hsv(blend_h, blend_s, blend_v, blend_a)
    end

    # Perceptually blends colors in CIE-L*a*b* space
    def blend_lab(other : Color, weight : Number = 0.5) : Color
      w = weight.to_f32.clamp(0.0_f32, 1.0_f32)
      inv_w = 1.0_f32 - w
      l1, a1, b1 = to_lab
      l2, a2, b2 = other.to_lab

      blend_l = l1 * inv_w + l2 * w
      blend_a = a1 * inv_w + a2 * w
      blend_b = b1 * inv_w + b2 * w
      blend_alpha = @a * inv_w + other.a * w
      Color.from_lab(blend_l, blend_a, blend_b, blend_alpha)
    end

    # Perceptually blends colors in Oklab space
    def blend_oklab(other : Color, weight : Number = 0.5) : Color
      w = weight.to_f32.clamp(0.0_f32, 1.0_f32)
      inv_w = 1.0_f32 - w
      l1, a1, b1 = to_oklab
      l2, a2, b2 = other.to_oklab

      blend_l = l1 * inv_w + l2 * w
      blend_a = a1 * inv_w + a2 * w
      blend_b = b1 * inv_w + b2 * w
      blend_alpha = @a * inv_w + other.a * w
      Color.from_oklab(blend_l, blend_a, blend_b, blend_alpha)
    end
  end
end

