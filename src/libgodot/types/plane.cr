module Godot
  # A 3D plane represented in normal-distance form (ax + by + cz = d).
  struct Plane
    property normal : Vector3
    property d : Float32

    def initialize(@normal : Vector3 = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32), @d : Float32 = 0.0_f32)
    end

    def initialize(pointer : Void*)
      if pointer.null?
        @normal = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
        @d = 0.0_f32
      else
        ptr = pointer.as(Float32*)
        @normal = Vector3.new(ptr[0], ptr[1], ptr[2])
        @d = ptr[3]
      end
    end

    def initialize(a : Number, b : Number, c : Number, d : Number)
      @normal = Vector3.new(a.to_f32, b.to_f32, c.to_f32)
      @d = d.to_f32
    end

    def initialize(point1 : Vector3, point2 : Vector3, point3 : Vector3)
      @normal = (point1 - point3).cross(point1 - point2).normalized
      @d = @normal.dot(point1)
    end

    def distance_to(point : Vector3) : Float32
      @normal.dot(point) - @d
    end

    def has_point(point : Vector3, tolerance : Number = 0.00001_f32) : Bool
      dist = distance_to(point)
      dist.abs <= tolerance.to_f32
    end

    def has_point?(point : Vector3, tolerance : Number = 0.00001_f32) : Bool
      has_point(point, tolerance)
    end

    def project(point : Vector3) : Vector3
      point - @normal * distance_to(point)
    end

    def normalized : Plane
      len = @normal.length
      if len == 0.0_f32
        Plane.new
      else
        Plane.new(@normal / len, @d / len)
      end
    end

    def is_equal_approx(other : Plane) : Bool
      @normal.is_equal_approx(other.normal) && (@d - other.d).abs < 0.00001_f32
    end

    def is_finite? : Bool
      @normal.is_finite? && @d.finite?
    end

    def ==(other : Plane) : Bool
      @normal == other.normal && @d == other.d
    end

    def !=(other : Plane) : Bool
      @normal != other.normal || @d != other.d
    end

    def to_s(io : IO) : Void
      io << "[N: " << @normal << ", D: " << @d << "]"
    end

    PLANE_YZ = Plane.new(Vector3.new(1.0_f32, 0.0_f32, 0.0_f32), 0.0_f32)
    PLANE_XZ = Plane.new(Vector3.new(0.0_f32, 1.0_f32, 0.0_f32), 0.0_f32)
    PLANE_XY = Plane.new(Vector3.new(0.0_f32, 0.0_f32, 1.0_f32), 0.0_f32)
  end
end
