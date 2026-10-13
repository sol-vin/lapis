module Celestine
  module Core
    # Lightweight, stack-allocated 3D vector for pure kinematic calculations.
    # Zero-allocation guarantee on 64-bit systems.
    struct Vec3
      property x : Float32
      property y : Float32
      property z : Float32

      def initialize(@x : Float32 = 0.0_f32, @y : Float32 = 0.0_f32, @z : Float32 = 0.0_f32)
      end

      def initialize(x : Number, y : Number, z : Number)
        @x = x.to_f32
        @y = y.to_f32
        @z = z.to_f32
      end

      def self.zero : Vec3
        Vec3.new(0.0_f32, 0.0_f32, 0.0_f32)
      end

      def self.up : Vec3
        Vec3.new(0.0_f32, 1.0_f32, 0.0_f32)
      end

      def +(other : Vec3) : Vec3
        Vec3.new(@x + other.x, @y + other.y, @z + other.z)
      end

      def -(other : Vec3) : Vec3
        Vec3.new(@x - other.x, @y - other.y, @z - other.z)
      end

      def *(scalar : Float32) : Vec3
        Vec3.new(@x * scalar, @y * scalar, @z * scalar)
      end

      def /(scalar : Float32) : Vec3
        return Vec3.zero if scalar.abs < 1e-6_f32
        Vec3.new(@x / scalar, @y / scalar, @z / scalar)
      end

      def dot(other : Vec3) : Float32
        (@x * other.x) + (@y * other.y) + (@z * other.z)
      end

      def length_squared : Float32
        dot(self)
      end

      def length : Float32
        Math.sqrt(length_squared).to_f32
      end

      def normalized : Vec3
        len = length
        return Vec3.zero if len < 1e-6_f32
        self / len
      end

      def horizontal : Vec3
        Vec3.new(@x, 0.0_f32, @z)
      end

      def horizontal_length : Float32
        horizontal.length
      end

      def ==(other : Vec3) : Bool
        (@x - other.x).abs < 1e-5_f32 &&
        (@y - other.y).abs < 1e-5_f32 &&
        (@z - other.z).abs < 1e-5_f32
      end
    end
  end
end
