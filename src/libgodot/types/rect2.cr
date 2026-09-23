module Godot
  # 2D axis-aligned bounding box defined by a position and size with 32-bit floating point precision.
  struct Rect2
    property position : Vector2
    property size : Vector2

    def initialize(@position : Vector2 = Vector2.new, @size : Vector2 = Vector2.new)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @position = Vector2.new
        @size = Vector2.new
      else
        ptr = pointer.as(Float32*)
        @position = Vector2.new(ptr[0], ptr[1])
        @size = Vector2.new(ptr[2], ptr[3])
      end
    end

    def initialize(x : Number, y : Number, width : Number, height : Number)
      @position = Vector2.new(x.to_f32, y.to_f32)
      @size = Vector2.new(width.to_f32, height.to_f32)
    end

    # Returns the ending point (position + size).
    def end : Vector2
      @position + @size
    end

    def end=(value : Vector2)
      @size = value - @position
    end

    # Returns the surface area of this Rect2.
    def area : Float32
      @size.x * @size.y
    end

    # Returns true if this Rect2 has a positive area.
    def has_area? : Bool
      @size.x > 0.0_f32 && @size.y > 0.0_f32
    end

    # Returns true if the point is inside the rectangle.
    def has_point(point : Vector2) : Bool
      point.x >= @position.x && point.x < @position.x + @size.x &&
        point.y >= @position.y && point.y < @position.y + @size.y
    end

    def has_point?(point : Vector2) : Bool
      has_point(point)
    end

    # Returns true if this Rect2 intersects with another.
    def intersects(b : Rect2, include_borders : Bool = false) : Bool
      if include_borders
        !(@position.x > b.position.x + b.size.x ||
          @position.x + @size.x < b.position.x ||
          @position.y > b.position.y + b.size.y ||
          @position.y + @size.y < b.position.y)
      else
        !(@position.x >= b.position.x + b.size.x ||
          @position.x + @size.x <= b.position.x ||
          @position.y >= b.position.y + b.size.y ||
          @position.y + @size.y <= b.position.y)
      end
    end

    def intersects?(b : Rect2) : Bool
      intersects(b)
    end

    # Returns true if this Rect2 completely encloses another.
    def encloses(b : Rect2) : Bool
      b.position.x >= @position.x && b.position.y >= @position.y &&
        b.position.x + b.size.x <= @position.x + @size.x &&
        b.position.y + b.size.y <= @position.y + @size.y
    end

    def encloses?(b : Rect2) : Bool
      encloses(b)
    end

    # Returns the intersection of this Rect2 and another.
    def intersection(b : Rect2) : Rect2
      new_pos = Vector2.new(Math.max(@position.x, b.position.x), Math.max(@position.y, b.position.y))
      new_end = Vector2.new(Math.min(@position.x + @size.x, b.position.x + b.size.x), Math.min(@position.y + @size.y, b.position.y + b.size.y))
      if new_end.x <= new_pos.x || new_end.y <= new_pos.y
        Rect2.new
      else
        Rect2.new(new_pos, new_end - new_pos)
      end
    end

    # Returns a larger Rect2 that encloses both this and another Rect2.
    def merge(b : Rect2) : Rect2
      new_pos = Vector2.new(Math.min(@position.x, b.position.x), Math.min(@position.y, b.position.y))
      new_end = Vector2.new(Math.max(@position.x + @size.x, b.position.x + b.size.x), Math.max(@position.y + @size.y, b.position.y + b.size.y))
      Rect2.new(new_pos, new_end - new_pos)
    end

    # Returns a larger Rect2 that includes the given point.
    def expand(to : Vector2) : Rect2
      new_pos = Vector2.new(Math.min(@position.x, to.x), Math.min(@position.y, to.y))
      new_end = Vector2.new(Math.max(@position.x + @size.x, to.x), Math.max(@position.y + @size.y, to.y))
      Rect2.new(new_pos, new_end - new_pos)
    end

    # Returns a copy of this Rect2 grown by the given amount on all sides.
    def grow(by : Number) : Rect2
      b = by.to_f32
      Rect2.new(
        Vector2.new(@position.x - b, @position.y - b),
        Vector2.new(@size.x + b * 2.0_f32, @size.y + b * 2.0_f32)
      )
    end

    # Returns a copy of this Rect2 grown individually on each side.
    def grow_individual(left : Number, top : Number, right : Number, bottom : Number) : Rect2
      l = left.to_f32; t = top.to_f32; r = right.to_f32; b = bottom.to_f32
      Rect2.new(
        Vector2.new(@position.x - l, @position.y - t),
        Vector2.new(@size.x + l + r, @size.y + t + b)
      )
    end

    # Returns a Rect2 with non-negative width and height.
    def abs : Rect2
      pos = @position
      sz = @size
      if sz.x < 0.0_f32
        pos = Vector2.new(pos.x + sz.x, pos.y)
        sz = Vector2.new(-sz.x, sz.y)
      end
      if sz.y < 0.0_f32
        pos = Vector2.new(pos.x, pos.y + sz.y)
        sz = Vector2.new(sz.x, -sz.y)
      end
      Rect2.new(pos, sz)
    end

    def is_equal_approx(other : Rect2) : Bool
      @position.is_equal_approx(other.position) && @size.is_equal_approx(other.size)
    end

    def ==(other : Rect2) : Bool
      @position == other.position && @size == other.size
    end

    def !=(other : Rect2) : Bool
      @position != other.position || @size != other.size
    end

    def to_i : Rect2i
      Rect2i.new(@position.to_i, @size.to_i)
    end

    def to_s(io : IO) : Void
      io << "[P: " << @position << ", S: " << @size << "]"
    end
  end

  # 2D axis-aligned bounding box using integer coordinates.
  struct Rect2i
    property position : Vector2i
    property size : Vector2i

    def initialize(@position : Vector2i = Vector2i.new, @size : Vector2i = Vector2i.new)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @position = Vector2i.new
        @size = Vector2i.new
      else
        ptr = pointer.as(Int32*)
        @position = Vector2i.new(ptr[0], ptr[1])
        @size = Vector2i.new(ptr[2], ptr[3])
      end
    end

    def initialize(x : Number, y : Number, width : Number, height : Number)
      @position = Vector2i.new(x.to_i32, y.to_i32)
      @size = Vector2i.new(width.to_i32, height.to_i32)
    end

    def end : Vector2i
      @position + @size
    end

    def end=(value : Vector2i)
      @size = value - @position
    end

    def area : Int32
      @size.x * @size.y
    end

    def has_area? : Bool
      @size.x > 0 && @size.y > 0
    end

    def has_point(point : Vector2i) : Bool
      point.x >= @position.x && point.x < @position.x + @size.x &&
        point.y >= @position.y && point.y < @position.y + @size.y
    end

    def has_point?(point : Vector2i) : Bool
      has_point(point)
    end

    def intersects(b : Rect2i) : Bool
      !(@position.x >= b.position.x + b.size.x ||
        @position.x + @size.x <= b.position.x ||
        @position.y >= b.position.y + b.size.y ||
        @position.y + @size.y <= b.position.y)
    end

    def intersects?(b : Rect2i) : Bool
      intersects(b)
    end

    def encloses(b : Rect2i) : Bool
      b.position.x >= @position.x && b.position.y >= @position.y &&
        b.position.x + b.size.x <= @position.x + @size.x &&
        b.position.y + b.size.y <= @position.y + @size.y
    end

    def encloses?(b : Rect2i) : Bool
      encloses(b)
    end

    def intersection(b : Rect2i) : Rect2i
      new_pos = Vector2i.new(Math.max(@position.x, b.position.x), Math.max(@position.y, b.position.y))
      new_end = Vector2i.new(Math.min(@position.x + @size.x, b.position.x + b.size.x), Math.min(@position.y + @size.y, b.position.y + b.size.y))
      if new_end.x <= new_pos.x || new_end.y <= new_pos.y
        Rect2i.new
      else
        Rect2i.new(new_pos, new_end - new_pos)
      end
    end

    def merge(b : Rect2i) : Rect2i
      new_pos = Vector2i.new(Math.min(@position.x, b.position.x), Math.min(@position.y, b.position.y))
      new_end = Vector2i.new(Math.max(@position.x + @size.x, b.position.x + b.size.x), Math.max(@position.y + @size.y, b.position.y + b.size.y))
      Rect2i.new(new_pos, new_end - new_pos)
    end

    def expand(to : Vector2i) : Rect2i
      new_pos = Vector2i.new(Math.min(@position.x, to.x), Math.min(@position.y, to.y))
      new_end = Vector2i.new(Math.max(@position.x + @size.x, to.x), Math.max(@position.y + @size.y, to.y))
      Rect2i.new(new_pos, new_end - new_pos)
    end

    def grow(by : Int) : Rect2i
      b = by.to_i32
      Rect2i.new(
        Vector2i.new(@position.x - b, @position.y - b),
        Vector2i.new(@size.x + b * 2, @size.y + b * 2)
      )
    end

    def abs : Rect2i
      pos = @position
      sz = @size
      if sz.x < 0
        pos = Vector2i.new(pos.x + sz.x, pos.y)
        sz = Vector2i.new(-sz.x, sz.y)
      end
      if sz.y < 0
        pos = Vector2i.new(pos.x, pos.y + sz.y)
        sz = Vector2i.new(sz.x, -sz.y)
      end
      Rect2i.new(pos, sz)
    end

    def ==(other : Rect2i) : Bool
      @position == other.position && @size == other.size
    end

    def !=(other : Rect2i) : Bool
      @position != other.position || @size != other.size
    end

    def to_r2 : Rect2
      Rect2.new(@position.to_v2, @size.to_v2)
    end

    def to_s(io : IO) : Void
      io << "[P: " << @position << ", S: " << @size << "]"
    end
  end
end
