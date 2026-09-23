require "./types"

module Godot
  class Object
  end

  alias VariantValue = Nil | Bool | Int64 | Float64 | String | Vector2 | Vector2i | Rect2 | Rect2i | Vector3 | Vector3i | Vector4 | Vector4i | Color | Transform2D | Transform3D | Basis | Quaternion | Plane | AABB | Godot::Object

  # Represents a dynamically typed Godot Variant value in Crystal with zero-allocation
  # unboxing for primitive and engine math types.
  struct Variant
    getter raw : VariantValue

    def initialize(@raw : VariantValue = nil)
    end

    def self.new(val : Int32)
      new(val.to_i64)
    end

    def self.new(val : UInt32)
      new(val.to_i64)
    end

    def self.new(val : UInt64)
      new(val.to_i64)
    end

    def self.new(val : Float32)
      new(val.to_f64)
    end

    def self.new(val : Symbol)
      new(val.to_s)
    end

    def is_nil? : Bool
      @raw.nil?
    end

    def bool? : Bool
      @raw.is_a?(Bool)
    end

    def int? : Bool
      @raw.is_a?(Int64)
    end

    def float? : Bool
      @raw.is_a?(Float64)
    end

    def string? : Bool
      @raw.is_a?(String)
    end

    def object? : Bool
      @raw.is_a?(Godot::Object)
    end

    def as_bool : Bool
      case v = @raw
      when Bool   then v
      when Int64  then v != 0
      when String then v == "true" || v == "1"
      else             !is_nil?
      end
    end

    def as_i32 : Int32
      as_i64.to_i32
    end

    def as_i : Int32
      as_i32
    end

    def as_i64 : Int64
      case v = @raw
      when Int64   then v
      when Float64 then v.to_i64
      when Bool    then v ? 1_i64 : 0_i64
      when String  then v.to_i64? || 0_i64
      else              0_i64
      end
    end

    def as_u32 : UInt32
      as_i64.to_u32
    end

    def as_u64 : UInt64
      as_i64.to_u64
    end

    def as_f32 : Float32
      as_f64.to_f32
    end

    def as_f : Float32
      as_f32
    end

    def as_f64 : Float64
      case v = @raw
      when Float64 then v
      when Int64   then v.to_f64
      when Bool    then v ? 1.0 : 0.0
      when String  then v.to_f64? || 0.0
      else              0.0
      end
    end

    def as_s : String
      to_s
    end

    def as_str : String
      to_s
    end

    def empty? : Bool
      to_s.empty?
    end

    def as_v2 : Vector2
      case v = @raw
      when Vector2  then v
      when Vector2i then Vector2.new(v.x.to_f32, v.y.to_f32)
      else               Vector2.new
      end
    end

    def as_v2i : Vector2i
      case v = @raw
      when Vector2i then v
      when Vector2  then Vector2i.new(v.x.to_i32, v.y.to_i32)
      else               Vector2i.new
      end
    end

    def as_rect2 : Rect2
      @raw.as?(Rect2) || Rect2.new
    end

    def as_rect2i : Rect2i
      @raw.as?(Rect2i) || Rect2i.new
    end

    def as_v3 : Vector3
      case v = @raw
      when Vector3  then v
      when Vector3i then Vector3.new(v.x.to_f32, v.y.to_f32, v.z.to_f32)
      else               Vector3.new
      end
    end

    def as_v3i : Vector3i
      case v = @raw
      when Vector3i then v
      when Vector3  then Vector3i.new(v.x.to_i32, v.y.to_i32, v.z.to_i32)
      else               Vector3i.new
      end
    end

    def as_v4 : Vector4
      @raw.as?(Vector4) || Vector4.new
    end

    def as_v4i : Vector4i
      @raw.as?(Vector4i) || Vector4i.new
    end

    def as_color : Color
      @raw.as?(Color) || Color.new
    end

    def as_transform2d : Transform2D
      @raw.as?(Transform2D) || Transform2D.new
    end

    def as_transform3d : Transform3D
      @raw.as?(Transform3D) || Transform3D.new
    end

    def as_basis : Basis
      @raw.as?(Basis) || Basis.new
    end

    def as_quat : Quaternion
      @raw.as?(Quaternion) || Quaternion.new
    end

    def as_plane : Plane
      @raw.as?(Plane) || Plane.new
    end

    def as_aabb : AABB
      @raw.as?(AABB) || AABB.new
    end

    def as_obj : Godot::Object?
      @raw.as?(Godot::Object)
    end

    def as_node : Godot::Node?
      @raw.as?(Godot::Node)
    end

    # Unboxes the Variant to target type T at compile time.
    def as_t(type : T.class) : T forall T
      {% if T == Int32 %}
        as_i32
      {% elsif T == Int64 %}
        as_i64
      {% elsif T == UInt32 %}
        as_u32
      {% elsif T == UInt64 %}
        as_u64
      {% elsif T == Float32 %}
        as_f32
      {% elsif T == Float64 %}
        as_f64
      {% elsif T == Bool %}
        as_bool
      {% elsif T == String %}
        as_s
      {% elsif T == Godot::Vector2 %}
        as_v2
      {% elsif T == Godot::Vector2i %}
        as_v2i
      {% elsif T == Godot::Rect2 %}
        as_rect2
      {% elsif T == Godot::Rect2i %}
        as_rect2i
      {% elsif T == Godot::Vector3 %}
        as_v3
      {% elsif T == Godot::Vector3i %}
        as_v3i
      {% elsif T == Godot::Vector4 %}
        as_v4
      {% elsif T == Godot::Vector4i %}
        as_v4i
      {% elsif T == Godot::Color %}
        as_color
      {% elsif T == Godot::Transform2D %}
        as_transform2d
      {% elsif T == Godot::Transform3D %}
        as_transform3d
      {% elsif T == Godot::Basis %}
        as_basis
      {% elsif T == Godot::Quaternion %}
        as_quat
      {% elsif T == Godot::Plane %}
        as_plane
      {% elsif T == Godot::AABB %}
        as_aabb
      {% elsif T <= Godot::Object %}
        if obj = as_obj
          obj.as(T)
        else
          raise TypeCastError.new("Cannot cast nil Variant to #{T}")
        end
      {% else %}
        @raw.as(T)
      {% end %}
    end

    # Returns safe default value for target type T
    def self.default_for(type : T.class) : T forall T
      {% if T == Int32 || T == Int64 || T == UInt32 || T == UInt64 %}
        T.new(0)
      {% elsif T == Float32 || T == Float64 %}
        T.new(0.0)
      {% elsif T == Bool %}
        false
      {% elsif T == String %}
        ""
      {% elsif T == Godot::Vector2 %}
        Godot::Vector2.new
      {% elsif T == Godot::Vector2i %}
        Godot::Vector2i.new
      {% elsif T == Godot::Rect2 %}
        Godot::Rect2.new
      {% elsif T == Godot::Rect2i %}
        Godot::Rect2i.new
      {% elsif T == Godot::Vector3 %}
        Godot::Vector3.new
      {% elsif T == Godot::Vector3i %}
        Godot::Vector3i.new
      {% elsif T == Godot::Vector4 %}
        Godot::Vector4.new
      {% elsif T == Godot::Vector4i %}
        Godot::Vector4i.new
      {% elsif T == Godot::Color %}
        Godot::Color.new
      {% elsif T == Godot::Transform2D %}
        Godot::Transform2D.new
      {% elsif T == Godot::Transform3D %}
        Godot::Transform3D.new
      {% elsif T == Godot::Basis %}
        Godot::Basis.new
      {% elsif T == Godot::Quaternion %}
        Godot::Quaternion.new
      {% elsif T == Godot::Plane %}
        Godot::Plane.new
      {% elsif T == Godot::AABB %}
        Godot::AABB.new
      {% elsif T <= Godot::Object %}
        T.new
      {% else %}
        raise "No default constructor for #{T}"
      {% end %}
    end

    # Constructs a Variant directly from a native C-bridge VariantArg.
    def self.from_arg(arg : LibBridge::VariantArg) : Variant
      case arg.type
      when 0 # Nil
        new(nil)
      when 1 # Bool
        new(arg.int_val != 0)
      when 2 # Int
        new(arg.int_val)
      when 3 # Float
        new(arg.float_val)
      when 4, 21, 22 # String, StringName, NodePath
        str = arg.ptr_val.null? ? "" : String.new(arg.ptr_val.as(LibC::Char*))
        new(str)
      when 5 # Vector2
        new(Vector2.new(arg.vec_val[0], arg.vec_val[1]))
      when 6 # Vector2i
        new(Vector2i.new(arg.vec_val[0].to_i32, arg.vec_val[1].to_i32))
      when 7 # Rect2
        new(Rect2.new(arg.vec_val[0], arg.vec_val[1], arg.vec_val[2], arg.vec_val[3]))
      when 9 # Vector3
        new(Vector3.new(arg.vec_val[0], arg.vec_val[1], arg.vec_val[2]))
      when 10 # Vector3i
        new(Vector3i.new(arg.vec_val[0].to_i32, arg.vec_val[1].to_i32, arg.vec_val[2].to_i32))
      when 20 # Color
        new(Color.new(arg.vec_val[0], arg.vec_val[1], arg.vec_val[2], arg.vec_val[3]))
      when 24 # Object
        ptr = arg.ptr_val
        if ptr.null?
          new(nil)
        else
          if inst = Bridge.find_alive_instance(ptr)
            new(inst)
          else
            new(Godot::Object.new(ptr))
          end
        end
      else
        str = arg.ptr_val.null? ? "" : String.new(arg.ptr_val.as(LibC::Char*))
        new(str)
      end
    end

    def to_s(io : IO) : Void
      case v = @raw
      when Nil           then io << "nil"
      when Godot::Object then v.to_s(io)
      else                    io << v
      end
    end

    def ==(other : Variant) : Bool
      @raw == other.@raw
    end

    def ==(other : String) : Bool
      to_s == other
    end

    def ==(other : Number) : Bool
      case v = @raw
      when Int64   then v == other
      when Float64 then v == other.to_f64
      else              to_s == other.to_s
      end
    end

    def ==(other : Bool) : Bool
      as_bool == other
    end

    def ==(other : Godot::Object) : Bool
      as_obj == other
    end
  end
end
