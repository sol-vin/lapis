require "./types"

module Godot
  class Object
  end

  class Dictionary
  end

  class GodotArray(T)
  end

  class PackedByteArray; end
  class PackedInt32Array; end
  class PackedInt64Array; end
  class PackedFloat32Array; end
  class PackedFloat64Array; end
  class PackedStringArray; end
  class PackedVector2Array; end
  class PackedVector3Array; end
  class PackedColorArray; end
  class PackedVector4Array; end

  # Scoped GC-rooted arena keeping temporary serialized POD buffers, C-string tables,
  # and nested VariantArg slices alive across FFI boundary calls without clobbering.
  class VariantPackArena
    getter strings = ::Array(String).new
    getter byte_slices = ::Array(Bytes).new
    getter cstr_arrays = ::Array(::Array(Pointer(UInt8))).new
    getter arg_arrays = ::Array(::Array(LibBridge::VariantArg)).new

    def clear : Void
      @strings.clear
      @byte_slices.clear
      @cstr_arrays.clear
      @arg_arrays.clear
    end

    def store_str(s : String) : Void*
      @strings << s
      s.to_unsafe.as(Void*)
    end

    def store_pod(val : T) : Void* forall T
      bytes = Bytes.new(sizeof(T))
      bytes.to_unsafe.as(Pointer(T)).value = val
      @byte_slices << bytes
      bytes.to_unsafe.as(Void*)
    end

    def store_cstrs(strs : Enumerable(String), count : Int32) : Void*
      return Pointer(Void).null if count <= 0
      arr = ::Array(Pointer(UInt8)).new(count)
      strs.each do |s|
        @strings << s
        arr << s.to_unsafe
      end
      @cstr_arrays << arr
      arr.to_unsafe.as(Void*)
    end

    def store_args(args : ::Array(LibBridge::VariantArg)) : Void*
      return Pointer(Void).null if args.empty?
      @arg_arrays << args
      args.to_unsafe.as(Void*)
    end
  end

  alias VariantValue = Nil | Bool | Int64 | Float64 | String | Vector2 | Vector2i | Rect2 | Rect2i | Vector3 | Vector3i | Vector4 | Vector4i | Color | Transform2D | Transform3D | Basis | Quaternion | Plane | AABB | Projection | RID | Godot::Object | Godot::Dictionary | Godot::GodotArray(Variant) | PackedByteArray | PackedInt32Array | PackedInt64Array | PackedFloat32Array | PackedFloat64Array | PackedStringArray | PackedVector2Array | PackedVector3Array | PackedColorArray | PackedVector4Array

  # Represents a dynamically typed Godot Variant value in Crystal with zero-allocation
  # unboxing for primitive and engine math types.
  struct Variant
    getter raw : VariantValue

    def initialize(@raw : VariantValue = nil)
    end

    def initialize(val : Variant)
      @raw = val.raw
    end

    def initialize(val : Int32)
      @raw = val.to_i64
    end

    def initialize(val : UInt32)
      @raw = val.to_i64
    end

    def initialize(val : UInt64)
      @raw = val.to_i64
    end

    def initialize(val : Float32)
      @raw = val.to_f64
    end

    def initialize(val : Symbol)
      @raw = val.to_s
    end

    def initialize(val : Enum)
      @raw = val.value.to_i64
    end

    def initialize(val : NodePath)
      @raw = val.to_s
    end

    def initialize(val : GodotArray(T)) forall T
      {% if T == Variant %}
        @raw = val
      {% else %}
        arr = GodotArray(Variant).new
        val.each { |item| arr << Variant.new(item) }
        @raw = arr
      {% end %}
    end

    def initialize(val : ::Array(T)) forall T
      arr = GodotArray(Variant).new
      val.each { |item| arr << Variant.new(item) }
      @raw = arr
    end

    def initialize(val : ::Hash(K, V)) forall K, V
      @raw = Godot::Dictionary.from(val)
    end

    def self.from_any?(val) : Variant?
      if val.is_a?(Variant)
        val
      elsif val.is_a?(VariantValue)
        new(val)
      elsif val.is_a?(Int32 | UInt32 | UInt64 | Float32 | Symbol | NodePath)
        new(val)
      elsif val.is_a?(Enum)
        new(val)
      elsif val.is_a?(GodotArray) || val.is_a?(::Array) || val.is_a?(::Hash)
        new(val)
      else
        nil
      end
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

    def as_bool(default : Bool = false) : Bool
      case v = @raw
      when Bool    then v
      when Int64   then v != 0
      when Float64 then v != 0.0
      when String
        s = v.strip.downcase
        return true if s == "true" || s == "1" || s == "yes" || s == "on"
        return false if s == "false" || s == "0" || s == "no" || s == "off" || s.empty?
        default
      when Nil
        default
      else
        !is_nil?
      end
    end

    def as_bool? : Bool?
      return nil if @raw.nil?
      as_bool
    end

    def as_i32(default : Int32 = 0_i32) : Int32
      as_i64(default.to_i64).to_i32
    end

    def as_i(default : Int32 = 0_i32) : Int32
      as_i32(default)
    end

    def as_i64(default : Int64 = 0_i64) : Int64
      case v = @raw
      when Int64   then v
      when Float64 then v.to_i64
      when Bool    then v ? 1_i64 : 0_i64
      when String  then v.strip.to_i64? || v.strip.to_f64?.try(&.to_i64) || default
      else              default
      end
    end

    def as_u32(default : UInt32 = 0_u32) : UInt32
      as_i64(default.to_i64).to_u32
    end

    def as_u64(default : UInt64 = 0_u64) : UInt64
      as_i64(default.to_i64).to_u64
    end

    def as_f32(default : Float32 = 0.0_f32) : Float32
      as_f64(default.to_f64).to_f32
    end

    def as_f(default : Float32 = 0.0_f32) : Float32
      as_f32(default)
    end

    def as_f64(default : Float64 = 0.0_f64) : Float64
      case v = @raw
      when Float64 then v
      when Int64   then v.to_f64
      when Bool    then v ? 1.0 : 0.0
      when String  then v.strip.to_f64? || default
      else              default
      end
    end

    def as_s(default : String = "") : String
      @raw.nil? ? default : to_s
    end

    def as_s? : String?
      @raw.nil? ? nil : to_s
    end

    def as_str(default : String = "") : String
      as_s(default)
    end

    def empty? : Bool
      to_s.empty?
    end

    def as_v2(default : Vector2 = Vector2.new) : Vector2
      case v = @raw
      when Vector2  then v
      when Vector2i then Vector2.new(v.x.to_f32, v.y.to_f32)
      when String
        parts = v.strip.tr(",()", "   ").split(/\s+/, remove_empty: true)
        if parts.size >= 2
          x = parts[0].to_f32?
          y = parts[1].to_f32?
          return Vector2.new(x, y) if x && y
        end
        default
      else
        default
      end
    end

    def as_v2_coerce(default : Vector2 = Vector2.new) : Vector2
      as_v2(default)
    end

    def as_vector2(default : Vector2 = Vector2.new) : Vector2
      as_v2(default)
    end

    def as_v2i : Vector2i
      case v = @raw
      when Vector2i then v
      when Vector2  then Vector2i.new(v.x.to_i32, v.y.to_i32)
      else               Vector2i.new
      end
    end

    def as_vector2i : Vector2i
      as_v2i
    end

    def as_rect2 : Rect2
      @raw.as?(Rect2) || Rect2.new
    end

    def as_rect2i : Rect2i
      @raw.as?(Rect2i) || Rect2i.new
    end

    def as_v3(default : Vector3 = Vector3.new) : Vector3
      case v = @raw
      when Vector3  then v
      when Vector3i then Vector3.new(v.x.to_f32, v.y.to_f32, v.z.to_f32)
      when String
        parts = v.strip.tr(",()", "   ").split(/\s+/, remove_empty: true)
        if parts.size >= 3
          x = parts[0].to_f32?
          y = parts[1].to_f32?
          z = parts[2].to_f32?
          return Vector3.new(x, y, z) if x && y && z
        end
        default
      else
        default
      end
    end

    def as_v3_coerce(default : Vector3 = Vector3.new) : Vector3
      as_v3(default)
    end

    def as_vector3(default : Vector3 = Vector3.new) : Vector3
      as_v3(default)
    end

    def as_v3i : Vector3i
      case v = @raw
      when Vector3i then v
      when Vector3  then Vector3i.new(v.x.to_i32, v.y.to_i32, v.z.to_i32)
      else               Vector3i.new
      end
    end

    def as_vector3i : Vector3i
      as_v3i
    end

    def as_v4 : Vector4
      @raw.as?(Vector4) || Vector4.new
    end

    def as_v4i : Vector4i
      @raw.as?(Vector4i) || Vector4i.new
    end

    def as_color(default : Color = Color.new) : Color
      case v = @raw
      when Color   then v
      when Vector3 then Color.new(v.x, v.y, v.z, 1.0_f32)
      when Vector4 then Color.new(v.x, v.y, v.z, v.w)
      when String
        s = v.strip
        if s.starts_with?("#")
          return Color.from_html(s) rescue default
        end
        parts = s.tr(",()", "   ").split(/\s+/, remove_empty: true)
        if parts.size >= 3
          r = parts[0].to_f32?
          g = parts[1].to_f32?
          b = parts[2].to_f32?
          a = parts.size >= 4 ? (parts[3].to_f32? || 1.0_f32) : 1.0_f32
          if r && g && b
            if r > 1.0_f32 || g > 1.0_f32 || b > 1.0_f32
              return Color.new(r / 255.0_f32, g / 255.0_f32, b / 255.0_f32, a > 1.0_f32 ? a / 255.0_f32 : a)
            else
              return Color.new(r, g, b, a)
            end
          end
        end
        default
      else
        default
      end
    end

    def as_color_coerce(default : Color = Color.new) : Color
      as_color(default)
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

    def array? : Bool
      @raw.is_a?(GodotArray(Variant))
    end

    def dict? : Bool
      @raw.is_a?(Godot::Dictionary)
    end

    def dictionary? : Bool
      dict?
    end

    def as_dict : Godot::Dictionary
      @raw.as?(Godot::Dictionary) || Godot::Dictionary.new
    end

    def as_dictionary : Godot::Dictionary
      as_dict
    end

    def as_a : GodotArray(Variant)
      case v = @raw
      when GodotArray(Variant)
        v
      when PackedByteArray
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x.to_i64) }
        arr
      when PackedInt32Array
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x.to_i64) }
        arr
      when PackedInt64Array
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x) }
        arr
      when PackedFloat32Array
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x.to_f64) }
        arr
      when PackedFloat64Array
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x) }
        arr
      when PackedStringArray
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x) }
        arr
      when PackedVector2Array
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x) }
        arr
      when PackedVector3Array
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x) }
        arr
      when PackedColorArray
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x) }
        arr
      when PackedVector4Array
        arr = GodotArray(Variant).new
        v.each { |x| arr << Variant.new(x) }
        arr
      else
        GodotArray(Variant).new
      end
    end

    def as_array : GodotArray(Variant)
      as_a
    end

    def as_array_of(type : T.class) : GodotArray(T) forall T
      GodotArray(T)._from_variant(self)
    end

    def as_rid : RID
      case v = @raw
      when RID   then v
      when Int64 then RID.new(v)
      else            RID.new
      end
    end

    def as_projection : Projection
      @raw.as?(Projection) || Projection.new
    end

    def as_packed_byte_array : PackedByteArray
      @raw.as?(PackedByteArray) || PackedByteArray.new
    end

    def as_packed_int32_array : PackedInt32Array
      @raw.as?(PackedInt32Array) || PackedInt32Array.new
    end

    def as_packed_int64_array : PackedInt64Array
      @raw.as?(PackedInt64Array) || PackedInt64Array.new
    end

    def as_packed_float32_array : PackedFloat32Array
      @raw.as?(PackedFloat32Array) || PackedFloat32Array.new
    end

    def as_packed_float64_array : PackedFloat64Array
      @raw.as?(PackedFloat64Array) || PackedFloat64Array.new
    end

    def as_packed_string_array : PackedStringArray
      @raw.as?(PackedStringArray) || PackedStringArray.new
    end

    def as_packed_vector2_array : PackedVector2Array
      @raw.as?(PackedVector2Array) || PackedVector2Array.new
    end

    def as_packed_vector3_array : PackedVector3Array
      @raw.as?(PackedVector3Array) || PackedVector3Array.new
    end

    def as_packed_color_array : PackedColorArray
      @raw.as?(PackedColorArray) || PackedColorArray.new
    end

    def as_packed_vector4_array : PackedVector4Array
      @raw.as?(PackedVector4Array) || PackedVector4Array.new
    end

    # Unboxes the Variant to target type T at compile time.
    def as_t(type : T.class) : T forall T
      {% if T == Godot::Variant %}
        self
      {% elsif T == Int32 %}
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
      {% elsif T == Godot::NodePath %}
        Godot::NodePath.new(as_s)
      {% elsif T == Godot::RID %}
        as_rid
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
      {% elsif T == Godot::Projection %}
        as_projection
      {% elsif T == Godot::Dictionary %}
        as_dict
      {% elsif T == Godot::PackedByteArray %}
        as_packed_byte_array
      {% elsif T == Godot::PackedInt32Array %}
        as_packed_int32_array
      {% elsif T == Godot::PackedInt64Array %}
        as_packed_int64_array
      {% elsif T == Godot::PackedFloat32Array %}
        as_packed_float32_array
      {% elsif T == Godot::PackedFloat64Array %}
        as_packed_float64_array
      {% elsif T == Godot::PackedStringArray %}
        as_packed_string_array
      {% elsif T == Godot::PackedVector2Array %}
        as_packed_vector2_array
      {% elsif T == Godot::PackedVector3Array %}
        as_packed_vector3_array
      {% elsif T == Godot::PackedColorArray %}
        as_packed_color_array
      {% elsif T == Godot::PackedVector4Array %}
        as_packed_vector4_array
      {% elsif T.name.starts_with?("Godot::GodotArray(") %}
        T._from_variant(self)
      {% elsif T <= Godot::Object %}
        if obj = as_obj
          if casted = obj.as_a?(T)
            casted
          else
            raise TypeCastError.new("Cannot cast #{obj.class.name} to #{T}")
          end
        else
          raise TypeCastError.new("Cannot cast nil Variant to #{T}")
        end
      {% elsif T < Enum %}
        T.from_value?(as_i64) || T.from_value?(0) || T.values.first
      {% elsif T == Pointer(Void) %}
        to_arg.ptr_val
      {% else %}
        @raw.as(T)
      {% end %}
    end

    # Returns safe default value for target type T
    def self.default_for(type : T.class) : T forall T
      {% if T == Godot::Variant %}
        Godot::Variant.new(nil)
      {% elsif T == Int32 || T == Int64 || T == UInt32 || T == UInt64 %}
        T.new(0)
      {% elsif T == Float32 || T == Float64 %}
        T.new(0.0)
      {% elsif T == Bool %}
        false
      {% elsif T == String %}
        ""
      {% elsif T == Godot::NodePath %}
        Godot::NodePath.new("")
      {% elsif T == Godot::RID %}
        Godot::RID.new
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
      {% elsif T == Godot::Projection %}
        Godot::Projection.new
      {% elsif T == Godot::Dictionary || T == Godot::PackedByteArray || T == Godot::PackedInt32Array || T == Godot::PackedInt64Array || T == Godot::PackedFloat32Array || T == Godot::PackedFloat64Array || T == Godot::PackedStringArray || T == Godot::PackedVector2Array || T == Godot::PackedVector3Array || T == Godot::PackedColorArray || T == Godot::PackedVector4Array %}
        T.new
      {% elsif T.name.starts_with?("Godot::GodotArray(") %}
        T.new
      {% elsif T <= Godot::Object %}
        T.new
      {% elsif T < Enum %}
        T.from_value?(0) || T.values.first
      {% elsif T == Pointer(Void) %}
        Pointer(Void).null
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
        if !arg.ptr_val.null?
          p = arg.ptr_val.as(Int32*)
          new(Vector2i.new(p[0], p[1]))
        elsif arg.int_val != 0 || arg.instance_id != 0
          new(Vector2i.new(arg.int_val.to_i32, (arg.instance_id & 0xFFFFFFFF_u64).to_u32.to_i32!))
        else
          new(Vector2i.new(arg.vec_val[0].to_i32, arg.vec_val[1].to_i32))
        end
      when 7 # Rect2
        new(Rect2.new(arg.vec_val[0], arg.vec_val[1], arg.vec_val[2], arg.vec_val[3]))
      when 8 # Rect2i
        new(arg.ptr_val.null? ? Rect2i.new : arg.ptr_val.as(Rect2i*).value)
      when 9 # Vector3
        new(Vector3.new(arg.vec_val[0], arg.vec_val[1], arg.vec_val[2]))
      when 10 # Vector3i
        if !arg.ptr_val.null?
          p = arg.ptr_val.as(Int32*)
          new(Vector3i.new(p[0], p[1], p[2]))
        else
          new(Vector3i.new(arg.vec_val[0].to_i32, arg.vec_val[1].to_i32, arg.vec_val[2].to_i32))
        end
      when 11 # Transform2D
        new(arg.ptr_val.null? ? Transform2D.new : arg.ptr_val.as(Transform2D*).value)
      when 12 # Vector4
        new(arg.ptr_val.null? ? Vector4.new(arg.vec_val[0], arg.vec_val[1], arg.vec_val[2], arg.vec_val[3]) : arg.ptr_val.as(Vector4*).value)
      when 13 # Vector4i
        new(arg.ptr_val.null? ? Vector4i.new : arg.ptr_val.as(Vector4i*).value)
      when 14 # Plane
        new(arg.ptr_val.null? ? Plane.new(arg.vec_val[0], arg.vec_val[1], arg.vec_val[2], arg.vec_val[3]) : arg.ptr_val.as(Plane*).value)
      when 15 # Quaternion
        new(arg.ptr_val.null? ? Quaternion.new(arg.vec_val[0], arg.vec_val[1], arg.vec_val[2], arg.vec_val[3]) : arg.ptr_val.as(Quaternion*).value)
      when 16 # AABB
        new(arg.ptr_val.null? ? AABB.new : arg.ptr_val.as(AABB*).value)
      when 17 # Basis
        new(arg.ptr_val.null? ? Basis.new : arg.ptr_val.as(Basis*).value)
      when 18 # Transform3D
        new(arg.ptr_val.null? ? Transform3D.new : arg.ptr_val.as(Transform3D*).value)
      when 19 # Projection
        new(arg.ptr_val.null? ? Projection.new : arg.ptr_val.as(Projection*).value)
      when 20 # Color
        new(Color.new(arg.vec_val[0], arg.vec_val[1], arg.vec_val[2], arg.vec_val[3]))
      when 23 # RID
        rid_id = arg.instance_id != 0 ? arg.instance_id : arg.int_val.to_u64!
        new(RID.new(rid_id))
      when 24 # Object
        ptr = arg.ptr_val
        if ptr.null?
          new(nil)
        elsif inst = Bridge.find_alive_instance(ptr)
          if inst.is_a?(Godot::RefCounted)
            inst._ensure_extension_borrowed_ref!
          end
          new(inst)
        elsif arg.extra_flags != 0
          new(Godot::RefCounted.new(ptr))
        else
          new(Godot::Object.new(ptr))
        end
      when 27 # Dictionary
        payload = Tuple(Void*, Int64).new(arg.ptr_val, arg.int_val)
        new(Godot::Dictionary.from_bridge_payload(pointerof(payload).as(Void*)))
      when 28 # Array
        payload = Tuple(Void*, Int64).new(arg.ptr_val, arg.int_val)
        new(Godot::GodotArray(Variant).from_bridge_payload(pointerof(payload).as(Void*)))
      when 29
        new(PackedByteArray.from_raw(arg.ptr_val, arg.int_val))
      when 30
        new(PackedInt32Array.from_raw(arg.ptr_val, arg.int_val))
      when 31
        new(PackedInt64Array.from_raw(arg.ptr_val, arg.int_val))
      when 32
        new(PackedFloat32Array.from_raw(arg.ptr_val, arg.int_val))
      when 33
        new(PackedFloat64Array.from_raw(arg.ptr_val, arg.int_val))
      when 34
        new(PackedStringArray.from_raw(arg.ptr_val, arg.int_val))
      when 35
        new(PackedVector2Array.from_raw(arg.ptr_val, arg.int_val))
      when 36
        new(PackedVector3Array.from_raw(arg.ptr_val, arg.int_val))
      when 37
        new(PackedColorArray.from_raw(arg.ptr_val, arg.int_val))
      when 38
        new(PackedVector4Array.from_raw(arg.ptr_val, arg.int_val))
      else
        str = arg.ptr_val.null? ? "" : String.new(arg.ptr_val.as(LibC::Char*))
        new(str)
      end
    end

    def to_arg(arena : VariantPackArena? = nil, elem_vtype_override : Int32 = 0) : LibBridge::VariantArg
      Variant.value_to_arg(@raw, arena, elem_vtype_override)
    end

    def self.value_to_arg(val, arena : VariantPackArena? = nil, elem_vtype_override : Int32 = 0) : LibBridge::VariantArg
      case val
      when Variant
        val.to_arg(arena, elem_vtype_override)
      when Nil
        LibBridge::VariantArg.new(type: 0)
      when Bool
        LibBridge::VariantArg.new(type: 1, int_val: val ? 1_i64 : 0_i64, float_val: val ? 1.0 : 0.0)
      when Int
        if elem_vtype_override == 23
          LibBridge::VariantArg.new(type: 23, int_val: val.to_i64, instance_id: val.to_u64!)
        else
          LibBridge::VariantArg.new(type: 2, int_val: val.to_i64, float_val: val.to_f64)
        end
      when Enum
        LibBridge::VariantArg.new(type: 2, int_val: val.value.to_i64, float_val: val.value.to_f64)
      when Float
        LibBridge::VariantArg.new(type: 3, float_val: val.to_f64, int_val: val.to_i64)
      when String
        vtype = (elem_vtype_override == 21 || elem_vtype_override == 22) ? elem_vtype_override : 4
        ptr = arena ? arena.store_str(val) : val.to_unsafe.as(Void*)
        LibBridge::VariantArg.new(type: vtype, ptr_val: ptr)
      when Symbol
        s = val.to_s
        vtype = elem_vtype_override == 4 ? 4 : 21
        ptr = arena ? arena.store_str(s) : s.to_unsafe.as(Void*)
        LibBridge::VariantArg.new(type: vtype, ptr_val: ptr)
      when NodePath
        s = val.to_s
        ptr = arena ? arena.store_str(s) : s.to_unsafe.as(Void*)
        LibBridge::VariantArg.new(type: 22, ptr_val: ptr)
      when Vector2
        arg = LibBridge::VariantArg.new(type: 5)
        arg.vec_val[0] = val.x
        arg.vec_val[1] = val.y
        arg
      when Vector2i
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        arg = LibBridge::VariantArg.new(type: 6, int_val: val.x.to_i64, instance_id: val.y.to_u32!.to_u64, ptr_val: ptr)
        arg.vec_val[0] = val.x.to_f32
        arg.vec_val[1] = val.y.to_f32
        arg
      when Rect2
        arg = LibBridge::VariantArg.new(type: 7)
        arg.vec_val[0] = val.position.x
        arg.vec_val[1] = val.position.y
        arg.vec_val[2] = val.size.x
        arg.vec_val[3] = val.size.y
        arg
      when Rect2i
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        LibBridge::VariantArg.new(type: 8, ptr_val: ptr, int_val: sizeof(Rect2i).to_i64)
      when Vector3
        arg = LibBridge::VariantArg.new(type: 9)
        arg.vec_val[0] = val.x
        arg.vec_val[1] = val.y
        arg.vec_val[2] = val.z
        arg
      when Vector3i
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        arg = LibBridge::VariantArg.new(type: 10, ptr_val: ptr, int_val: sizeof(Vector3i).to_i64)
        arg.vec_val[0] = val.x.to_f32
        arg.vec_val[1] = val.y.to_f32
        arg.vec_val[2] = val.z.to_f32
        arg
      when Transform2D
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        LibBridge::VariantArg.new(type: 11, ptr_val: ptr, int_val: sizeof(Transform2D).to_i64)
      when Vector4
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        arg = LibBridge::VariantArg.new(type: 12, ptr_val: ptr, int_val: sizeof(Vector4).to_i64)
        arg.vec_val[0] = val.x
        arg.vec_val[1] = val.y
        arg.vec_val[2] = val.z
        arg.vec_val[3] = val.w
        arg
      when Vector4i
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        LibBridge::VariantArg.new(type: 13, ptr_val: ptr, int_val: sizeof(Vector4i).to_i64)
      when Plane
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        arg = LibBridge::VariantArg.new(type: 14, ptr_val: ptr, int_val: sizeof(Plane).to_i64)
        arg.vec_val[0] = val.normal.x
        arg.vec_val[1] = val.normal.y
        arg.vec_val[2] = val.normal.z
        arg.vec_val[3] = val.d
        arg
      when Quaternion
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        arg = LibBridge::VariantArg.new(type: 15, ptr_val: ptr, int_val: sizeof(Quaternion).to_i64)
        arg.vec_val[0] = val.x
        arg.vec_val[1] = val.y
        arg.vec_val[2] = val.z
        arg.vec_val[3] = val.w
        arg
      when AABB
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        LibBridge::VariantArg.new(type: 16, ptr_val: ptr, int_val: sizeof(AABB).to_i64)
      when Basis
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        LibBridge::VariantArg.new(type: 17, ptr_val: ptr, int_val: sizeof(Basis).to_i64)
      when Transform3D
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        LibBridge::VariantArg.new(type: 18, ptr_val: ptr, int_val: sizeof(Transform3D).to_i64)
      when Projection
        ptr = arena ? arena.store_pod(val) : Pointer(Void).null
        LibBridge::VariantArg.new(type: 19, ptr_val: ptr, int_val: sizeof(Projection).to_i64)
      when Color
        arg = LibBridge::VariantArg.new(type: 20)
        arg.vec_val[0] = val.r
        arg.vec_val[1] = val.g
        arg.vec_val[2] = val.b
        arg.vec_val[3] = val.a
        arg
      when Godot::Object
        LibBridge::VariantArg.new(type: 24, ptr_val: val.pointer, instance_id: val.instance_id)
      when RID
        LibBridge::VariantArg.new(type: 23, int_val: val.to_i64, instance_id: val.id)
      when Godot::Dictionary
        eff_arena = arena || VariantPackArena.new
        kv_args = ::Array(LibBridge::VariantArg).new(val.size.to_i32 * 2)
        val.each do |k, v|
          kv_args << Variant.value_to_arg(k, eff_arena)
          kv_args << Variant.value_to_arg(v, eff_arena)
        end
        LibBridge::VariantArg.new(type: 27, ptr_val: eff_arena.store_args(kv_args), int_val: val.size)
      when ::Hash
        eff_arena = arena || VariantPackArena.new
        kv_args = ::Array(LibBridge::VariantArg).new(val.size * 2)
        val.each do |k, v|
          kv_args << Variant.value_to_arg(k, eff_arena)
          kv_args << Variant.value_to_arg(v, eff_arena)
        end
        LibBridge::VariantArg.new(type: 27, ptr_val: eff_arena.store_args(kv_args), int_val: val.size.to_i64)
      when GodotArray
        eff_arena = arena || VariantPackArena.new
        elem_args = ::Array(LibBridge::VariantArg).new(val.size.to_i32)
        val.each do |item|
          elem_args << Variant.value_to_arg(item, eff_arena)
        end
        LibBridge::VariantArg.new(type: 28, ptr_val: eff_arena.store_args(elem_args), int_val: val.size)
      when ::Array
        eff_arena = arena || VariantPackArena.new
        elem_args = ::Array(LibBridge::VariantArg).new(val.size)
        val.each do |item|
          elem_args << Variant.value_to_arg(item, eff_arena)
        end
        LibBridge::VariantArg.new(type: 28, ptr_val: eff_arena.store_args(elem_args), int_val: val.size.to_i64)
      when PackedByteArray
        LibBridge::VariantArg.new(type: 29, ptr_val: val.to_unsafe.as(Void*), int_val: val.size)
      when PackedInt32Array
        LibBridge::VariantArg.new(type: 30, ptr_val: val.to_unsafe.as(Void*), int_val: val.size)
      when PackedInt64Array
        LibBridge::VariantArg.new(type: 31, ptr_val: val.to_unsafe.as(Void*), int_val: val.size)
      when PackedFloat32Array
        LibBridge::VariantArg.new(type: 32, ptr_val: val.to_unsafe.as(Void*), int_val: val.size)
      when PackedFloat64Array
        LibBridge::VariantArg.new(type: 33, ptr_val: val.to_unsafe.as(Void*), int_val: val.size)
      when PackedStringArray
        ptr = arena ? arena.store_cstrs(val, val.size.to_i32) : val.cstr_array_ptr.as(Void*)
        LibBridge::VariantArg.new(type: 34, ptr_val: ptr, int_val: val.size)
      when PackedVector2Array
        LibBridge::VariantArg.new(type: 35, ptr_val: val.to_unsafe.as(Void*), int_val: val.size)
      when PackedVector3Array
        LibBridge::VariantArg.new(type: 36, ptr_val: val.to_unsafe.as(Void*), int_val: val.size)
      when PackedColorArray
        LibBridge::VariantArg.new(type: 37, ptr_val: val.to_unsafe.as(Void*), int_val: val.size)
      when PackedVector4Array
        LibBridge::VariantArg.new(type: 38, ptr_val: val.to_unsafe.as(Void*), int_val: val.size)
      else
        LibBridge::VariantArg.new(type: 0)
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
