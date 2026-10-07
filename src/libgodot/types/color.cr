module Godot
  # A color represented in RGBA format with 32-bit floating point precision per channel.
  struct Color
    property r : Float32
    property g : Float32
    property b : Float32
    property a : Float32

    def initialize(@r : Float32 = 1.0_f32, @g : Float32 = 1.0_f32, @b : Float32 = 1.0_f32, @a : Float32 = 1.0_f32)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @r = 1.0_f32; @g = 1.0_f32; @b = 1.0_f32; @a = 1.0_f32
      else
        ptr = pointer.as(Float32*)
        @r = ptr[0]; @g = ptr[1]; @b = ptr[2]; @a = ptr[3]
      end
    end

    def initialize(r : Number, g : Number, b : Number, a : Number = 1.0)
      @r = r.to_f32
      @g = g.to_f32
      @b = b.to_f32
      @a = a.to_f32
    end

    def initialize(rgba32 : UInt32)
      @a = ((rgba32 & 0x000000ff_u32)).to_f32 / 255.0_f32
      @b = ((rgba32 >> 8) & 0x000000ff_u32).to_f32 / 255.0_f32
      @g = ((rgba32 >> 16) & 0x000000ff_u32).to_f32 / 255.0_f32
      @r = ((rgba32 >> 24) & 0x000000ff_u32).to_f32 / 255.0_f32
    end

    # Intermediary representation for Hue, Saturation, Value, and Alpha
    struct HSV
      property h : Float32
      property s : Float32
      property v : Float32
      property a : Float32

      def initialize(@h : Float32, @s : Float32, @v : Float32, @a : Float32 = 1.0_f32)
      end

      def initialize(h : Number, s : Number, v : Number, a : Number = 1.0)
        @h = h.to_f32
        @s = s.to_f32
        @v = v.to_f32
        @a = a.to_f32
      end

      def h=(val : Number) : Void
        @h = val.to_f32
      end

      def s=(val : Number) : Void
        @s = val.to_f32
      end

      def v=(val : Number) : Void
        @v = val.to_f32
      end

      def a=(val : Number) : Void
        @a = val.to_f32
      end

      # Converts this HSV value back into a standard Godot::Color
      def to_color : Godot::Color
        Godot::Color.from_hsv(@h, @s, @v, @a)
      end

      # Shorthand alias to to_color
      def to_rgb : Godot::Color
        to_color
      end

      def with_h(new_h : Number) : HSV
        HSV.new(new_h.to_f32, @s, @v, @a)
      end

      def with_s(new_s : Number) : HSV
        HSV.new(@h, new_s.to_f32, @v, @a)
      end

      def with_v(new_v : Number) : HSV
        HSV.new(@h, @s, new_v.to_f32, @a)
      end

      def with_a(new_a : Number) : HSV
        HSV.new(@h, @s, @v, new_a.to_f32)
      end

      def to_s(io : IO) : Void
        io << "HSV(" << @h << ", " << @s << ", " << @v << ", " << @a << ")"
      end
    end

    def initialize(hsv : HSV)
      c = hsv.to_color
      @r = c.r
      @g = c.g
      @b = c.b
      @a = c.a
    end

    def +(other : Color) : Color
      Color.new(@r + other.r, @g + other.g, @b + other.b, @a + other.a)
    end

    def -(other : Color) : Color
      Color.new(@r - other.r, @g - other.g, @b - other.b, @a - other.a)
    end

    def *(other : Color) : Color
      Color.new(@r * other.r, @g * other.g, @b * other.b, @a * other.a)
    end

    def *(scalar : Number) : Color
      s = scalar.to_f32
      Color.new(@r * s, @g * s, @b * s, @a * s)
    end

    def /(scalar : Number) : Color
      s = scalar.to_f32
      Color.new(@r / s, @g / s, @b / s, @a / s)
    end

    def ==(other : Color) : Bool
      @r == other.r && @g == other.g && @b == other.b && @a == other.a
    end

    def !=(other : Color) : Bool
      @r != other.r || @g != other.g || @b != other.b || @a != other.a
    end

    def is_equal_approx(other : Color) : Bool
      (@r - other.r).abs < 0.00001_f32 &&
        (@g - other.g).abs < 0.00001_f32 &&
        (@b - other.b).abs < 0.00001_f32 &&
        (@a - other.a).abs < 0.00001_f32
    end

    def to_rgba32 : UInt32
      ir = (@r.clamp(0.0_f32, 1.0_f32) * 255.0_f32 + 0.5_f32).to_u32
      ig = (@g.clamp(0.0_f32, 1.0_f32) * 255.0_f32 + 0.5_f32).to_u32
      ib = (@b.clamp(0.0_f32, 1.0_f32) * 255.0_f32 + 0.5_f32).to_u32
      ia = (@a.clamp(0.0_f32, 1.0_f32) * 255.0_f32 + 0.5_f32).to_u32
      (ir << 24) | (ig << 16) | (ib << 8) | ia
    end

    def to_argb32 : UInt32
      ir = (@r.clamp(0.0_f32, 1.0_f32) * 255.0_f32 + 0.5_f32).to_u32
      ig = (@g.clamp(0.0_f32, 1.0_f32) * 255.0_f32 + 0.5_f32).to_u32
      ib = (@b.clamp(0.0_f32, 1.0_f32) * 255.0_f32 + 0.5_f32).to_u32
      ia = (@a.clamp(0.0_f32, 1.0_f32) * 255.0_f32 + 0.5_f32).to_u32
      (ia << 24) | (ir << 16) | (ig << 8) | ib
    end

    def to_html(include_alpha : Bool = true) : String
      ir = (@r.clamp(0.0_f32, 1.0_f32) * 255.0_f32).to_u8
      ig = (@g.clamp(0.0_f32, 1.0_f32) * 255.0_f32).to_u8
      ib = (@b.clamp(0.0_f32, 1.0_f32) * 255.0_f32).to_u8
      if include_alpha
        ia = (@a.clamp(0.0_f32, 1.0_f32) * 255.0_f32).to_u8
        sprintf("%02x%02x%02x%02x", ir, ig, ib, ia)
      else
        sprintf("%02x%02x%02x", ir, ig, ib)
      end
    end

    def self.from_html(hex : String) : Color
      clean = hex.lchop("#")
      case clean.size
      when 6
        r = clean[0..1].to_u32(16).to_f32 / 255.0_f32
        g = clean[2..3].to_u32(16).to_f32 / 255.0_f32
        b = clean[4..5].to_u32(16).to_f32 / 255.0_f32
        Color.new(r, g, b, 1.0_f32)
      when 8
        r = clean[0..1].to_u32(16).to_f32 / 255.0_f32
        g = clean[2..3].to_u32(16).to_f32 / 255.0_f32
        b = clean[4..5].to_u32(16).to_f32 / 255.0_f32
        a = clean[6..7].to_u32(16).to_f32 / 255.0_f32
        Color.new(r, g, b, a)
      else
        WHITE
      end
    end

    # Creates a Color from a hex string (e.g. "#ff0000" or "ff0000")
    def self.hex(hex_str : String) : Color
      from_html(hex_str)
    end

    # Generates a random RGB Color with alpha = 1.0 (or random alpha if include_alpha: true)
    def self.random(include_alpha : Bool = false) : Color
      r = ::Random.rand.to_f32
      g = ::Random.rand.to_f32
      b = ::Random.rand.to_f32
      a = include_alpha ? ::Random.rand.to_f32 : 1.0_f32
      Color.new(r, g, b, a)
    end

    # Computes and returns the Hue, Saturation, and Value components in range [0.0, 1.0]
    def to_hsv : Tuple(Float32, Float32, Float32)
      min = Math.min(@r, Math.min(@g, @b))
      max = Math.max(@r, Math.max(@g, @b))
      delta = max - min
      val = max
      sat = max == 0.0_f32 ? 0.0_f32 : delta / max
      hue = 0.0_f32
      if delta != 0.0_f32
        if @r == max
          hue = (@g - @b) / delta
        elsif @g == max
          hue = 2.0_f32 + (@b - @r) / delta
        else
          hue = 4.0_f32 + (@r - @g) / delta
        end
        hue /= 6.0_f32
        hue += 1.0_f32 if hue < 0.0_f32
      end
      {hue, sat, val}
    end

    # Computes and returns the Hue, Saturation, Value, and Alpha components in range [0.0, 1.0]
    def to_hsva : Tuple(Float32, Float32, Float32, Float32)
      h, s, v = to_hsv
      {h, s, v, @a}
    end

    # Returns an intermediary mutable Godot::Color::HSV value struct
    def to_hsv_struct : HSV
      h, s, v, a = to_hsva
      HSV.new(h, s, v, a)
    end

    # Shorthand for extracting the intermediary Godot::Color::HSV value struct
    def hsv : HSV
      to_hsv_struct
    end

    # Hue component in range [0.0, 1.0]
    def h : Float32
      to_hsv[0]
    end

    def h=(val : Number) : Void
      _, cur_s, cur_v = to_hsv
      new_color = Color.from_hsv(val, cur_s, cur_v, @a)
      @r = new_color.r
      @g = new_color.g
      @b = new_color.b
    end

    # Saturation component in range [0.0, 1.0]
    def s : Float32
      to_hsv[1]
    end

    def s=(val : Number) : Void
      cur_h, _, cur_v = to_hsv
      new_color = Color.from_hsv(cur_h, val, cur_v, @a)
      @r = new_color.r
      @g = new_color.g
      @b = new_color.b
    end

    # Value component in range [0.0, 1.0]
    def v : Float32
      to_hsv[2]
    end

    def v=(val : Number) : Void
      cur_h, cur_s, _ = to_hsv
      new_color = Color.from_hsv(cur_h, cur_s, val, @a)
      @r = new_color.r
      @g = new_color.g
      @b = new_color.b
    end

    # Returns a new Color with modified hue
    def with_h(val : Number) : Color
      _, cur_s, cur_v = to_hsv
      Color.from_hsv(val, cur_s, cur_v, @a)
    end

    # Returns a new Color with modified saturation
    def with_s(val : Number) : Color
      cur_h, _, cur_v = to_hsv
      Color.from_hsv(cur_h, val, cur_v, @a)
    end

    # Returns a new Color with modified value
    def with_v(val : Number) : Color
      cur_h, cur_s, _ = to_hsv
      Color.from_hsv(cur_h, cur_s, val, @a)
    end

    # Returns a new Color with multiple HSV/A components altered
    def with_hsv(*, h : Number? = nil, s : Number? = nil, v : Number? = nil, a : Number? = nil) : Color
      cur_h, cur_s, cur_v, cur_a = to_hsva
      Color.from_hsv(
        h ? h.not_nil! : cur_h,
        s ? s.not_nil! : cur_s,
        v ? v.not_nil! : cur_v,
        a ? a.not_nil! : cur_a
      )
    end

    # Returns a new Color with modified alpha
    def with_alpha(val : Number) : Color
      Color.new(@r, @g, @b, val.to_f32)
    end

    # Perceptual relative luminance according to ITU-R BT.709
    def luminance : Float32
      0.2126_f32 * @r + 0.7152_f32 * @g + 0.0722_f32 * @b
    end

    # Constructs a Color from an intermediary HSV struct
    def self.from_hsv(hsv : HSV) : Color
      hsv.to_color
    end

    def self.from_hsv(h : Number, s : Number, v : Number, a : Number = 1.0) : Color
      h_norm = ((h.to_f32 % 1.0_f32) + 1.0_f32) % 1.0_f32
      hue = (h_norm * 6.0_f32) % 6.0_f32
      sat = s.to_f32.clamp(0.0_f32, 1.0_f32)
      val = v.to_f32.clamp(0.0_f32, 1.0_f32)
      i = hue.floor.to_i32
      f = hue - i.to_f32
      p = val * (1.0_f32 - sat)
      q = val * (1.0_f32 - sat * f)
      t = val * (1.0_f32 - sat * (1.0_f32 - f))
      case i
      when 0 then Color.new(val, t, p, a.to_f32)
      when 1 then Color.new(q, val, p, a.to_f32)
      when 2 then Color.new(p, val, t, a.to_f32)
      when 3 then Color.new(p, q, val, a.to_f32)
      when 4 then Color.new(t, p, val, a.to_f32)
      else        Color.new(val, p, q, a.to_f32)
      end
    end

    # Shorthand alias to from_hsv
    def self.hsv(h : Number, s : Number, v : Number, a : Number = 1.0) : Color
      from_hsv(h, s, v, a)
    end

    # Shorthand alias to from_hsv(hsv)
    def self.hsv(hsv : HSV) : Color
      hsv.to_color
    end

    def inverted : Color
      Color.new(1.0_f32 - @r, 1.0_f32 - @g, 1.0_f32 - @b, @a)
    end

    def contrasted : Color
      Color.new(
        (@r + 0.5_f32) % 1.0_f32,
        (@g + 0.5_f32) % 1.0_f32,
        (@b + 0.5_f32) % 1.0_f32,
        @a
      )
    end

    def lightened(amount : Number) : Color
      amt = amount.to_f32
      Color.new(
        @r + (1.0_f32 - @r) * amt,
        @g + (1.0_f32 - @g) * amt,
        @b + (1.0_f32 - @b) * amt,
        @a
      )
    end

    def darkened(amount : Number) : Color
      amt = amount.to_f32
      Color.new(
        @r * (1.0_f32 - amt),
        @g * (1.0_f32 - amt),
        @b * (1.0_f32 - amt),
        @a
      )
    end

    def lerp(to : Color, weight : Number) : Color
      w = weight.to_f32
      Color.new(
        @r + (to.r - @r) * w,
        @g + (to.g - @g) * w,
        @b + (to.b - @b) * w,
        @a + (to.a - @a) * w
      )
    end

    def to_s(io : IO) : Void
      io << "(" << @r << ", " << @g << ", " << @b << ", " << @a << ")"
    end

    WHITE       = Color.new(1.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
    BLACK       = Color.new(0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
    RED         = Color.new(1.0_f32, 0.0_f32, 0.0_f32, 1.0_f32)
    GREEN       = Color.new(0.0_f32, 1.0_f32, 0.0_f32, 1.0_f32)
    BLUE        = Color.new(0.0_f32, 0.0_f32, 1.0_f32, 1.0_f32)
    YELLOW      = Color.new(1.0_f32, 1.0_f32, 0.0_f32, 1.0_f32)
    CYAN        = Color.new(0.0_f32, 1.0_f32, 1.0_f32, 1.0_f32)
    MAGENTA     = Color.new(1.0_f32, 0.0_f32, 1.0_f32, 1.0_f32)
    ORANGE      = Color.new(1.0_f32, 0.65_f32, 0.0_f32, 1.0_f32)
    GRAY        = Color.new(0.5_f32, 0.5_f32, 0.5_f32, 1.0_f32)
    TRANSPARENT = Color.new(0.0_f32, 0.0_f32, 0.0_f32, 0.0_f32)
  end
end
