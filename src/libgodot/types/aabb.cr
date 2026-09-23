module Godot
  # An axis-aligned bounding box in 3D space with 32-bit floating point precision.
  struct AABB
    property position : Vector3
    property size : Vector3

    def initialize(@position : Vector3 = Vector3.new, @size : Vector3 = Vector3.new)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @position = Vector3.new
        @size = Vector3.new
      else
        ptr = pointer.as(Float32*)
        @position = Vector3.new(ptr[0], ptr[1], ptr[2])
        @size = Vector3.new(ptr[3], ptr[4], ptr[5])
      end
    end

    def initialize(x : Number, y : Number, z : Number, width : Number, height : Number, depth : Number)
      @position = Vector3.new(x.to_f32, y.to_f32, z.to_f32)
      @size = Vector3.new(width.to_f32, height.to_f32, depth.to_f32)
    end

    def end : Vector3
      @position + @size
    end

    def end=(value : Vector3)
      @size = value - @position
    end

    def volume : Float32
      @size.x * @size.y * @size.z
    end

    def has_volume? : Bool
      @size.x > 0.0_f32 && @size.y > 0.0_f32 && @size.z > 0.0_f32
    end

    def has_surface? : Bool
      @size.x > 0.0_f32 || @size.y > 0.0_f32 || @size.z > 0.0_f32
    end

    def has_point(point : Vector3) : Bool
      point.x >= @position.x && point.x <= @position.x + @size.x &&
        point.y >= @position.y && point.y <= @position.y + @size.y &&
        point.z >= @position.z && point.z <= @position.z + @size.z
    end

    def has_point?(point : Vector3) : Bool
      has_point(point)
    end

    def intersects(other : AABB) : Bool
      !(@position.x >= other.position.x + other.size.x ||
        @position.x + @size.x <= other.position.x ||
        @position.y >= other.position.y + other.size.y ||
        @position.y + @size.y <= other.position.y ||
        @position.z >= other.position.z + other.size.z ||
        @position.z + @size.z <= other.position.z)
    end

    def intersects?(other : AABB) : Bool
      intersects(other)
    end

    def encloses(other : AABB) : Bool
      other.position.x >= @position.x && other.position.y >= @position.y && other.position.z >= @position.z &&
        other.position.x + other.size.x <= @position.x + @size.x &&
        other.position.y + other.size.y <= @position.y + @size.y &&
        other.position.z + other.size.z <= @position.z + @size.z
    end

    def encloses?(other : AABB) : Bool
      encloses(other)
    end

    def intersection(other : AABB) : AABB
      new_pos = Vector3.new(
        Math.max(@position.x, other.position.x),
        Math.max(@position.y, other.position.y),
        Math.max(@position.z, other.position.z)
      )
      new_end = Vector3.new(
        Math.min(@position.x + @size.x, other.position.x + other.size.x),
        Math.min(@position.y + @size.y, other.position.y + other.size.y),
        Math.min(@position.z + @size.z, other.position.z + other.size.z)
      )
      if new_end.x <= new_pos.x || new_end.y <= new_pos.y || new_end.z <= new_pos.z
        AABB.new
      else
        AABB.new(new_pos, new_end - new_pos)
      end
    end

    def merge(other : AABB) : AABB
      new_pos = Vector3.new(
        Math.min(@position.x, other.position.x),
        Math.min(@position.y, other.position.y),
        Math.min(@position.z, other.position.z)
      )
      new_end = Vector3.new(
        Math.max(@position.x + @size.x, other.position.x + other.size.x),
        Math.max(@position.y + @size.y, other.position.y + other.size.y),
        Math.max(@position.z + @size.z, other.position.z + other.size.z)
      )
      AABB.new(new_pos, new_end - new_pos)
    end

    def expand(to_point : Vector3) : AABB
      new_pos = Vector3.new(
        Math.min(@position.x, to_point.x),
        Math.min(@position.y, to_point.y),
        Math.min(@position.z, to_point.z)
      )
      new_end = Vector3.new(
        Math.max(@position.x + @size.x, to_point.x),
        Math.max(@position.y + @size.y, to_point.y),
        Math.max(@position.z + @size.z, to_point.z)
      )
      AABB.new(new_pos, new_end - new_pos)
    end

    def grow(by : Number) : AABB
      b = by.to_f32
      AABB.new(
        Vector3.new(@position.x - b, @position.y - b, @position.z - b),
        Vector3.new(@size.x + b * 2.0_f32, @size.y + b * 2.0_f32, @size.z + b * 2.0_f32)
      )
    end

    def abs : AABB
      pos = @position
      sz = @size
      if sz.x < 0.0_f32
        pos = Vector3.new(pos.x + sz.x, pos.y, pos.z)
        sz = Vector3.new(-sz.x, sz.y, sz.z)
      end
      if sz.y < 0.0_f32
        pos = Vector3.new(pos.x, pos.y + sz.y, pos.z)
        sz = Vector3.new(sz.x, -sz.y, sz.z)
      end
      if sz.z < 0.0_f32
        pos = Vector3.new(pos.x, pos.y, pos.z + sz.z)
        sz = Vector3.new(sz.x, sz.y, -sz.z)
      end
      AABB.new(pos, sz)
    end

    def is_equal_approx(other : AABB) : Bool
      @position.is_equal_approx(other.position) && @size.is_equal_approx(other.size)
    end

    def ==(other : AABB) : Bool
      @position == other.position && @size == other.size
    end

    def !=(other : AABB) : Bool
      @position != other.position || @size != other.size
    end

    def to_s(io : IO) : Void
      io << "[P: " << @position << ", S: " << @size << "]"
    end
  end
end
