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

    def self.from_hsv(h : Number, s : Number, v : Number, a : Number = 1.0) : Color
      hue = (h.to_f32 * 6.0_f32) % 6.0_f32
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
