# =============================================================================
# LibGodot - Radare2 Godot Type Maps & Variant Binary Decoders
# =============================================================================
# Implements binary layouts and decoders for Godot 4.x Objects, Variant payloads,
# and radare2 print formats (`pf.godot_*`).

require "cradare2"
require "json"

module Lapis
  module Debugger
    # Godot 4.x Variant types matching GDExtensionVariantType enum.
    enum VariantType : UInt8
      Nil                 =  0_u8
      Bool                =  1_u8
      Int                 =  2_u8
      Float               =  3_u8
      String              =  4_u8
      Vector2             =  5_u8
      Vector2i            =  6_u8
      Rect2               =  7_u8
      Rect2i              =  8_u8
      Vector3             =  9_u8
      Vector3i            = 10_u8
      Transform2D         = 11_u8
      Vector4             = 12_u8
      Vector4i            = 13_u8
      Plane               = 14_u8
      Quaternion          = 15_u8
      AABB                = 16_u8
      Basis               = 17_u8
      Transform3D         = 18_u8
      Projection          = 19_u8
      Color               = 20_u8
      StringName          = 21_u8
      NodePath            = 22_u8
      RID                 = 23_u8
      Object              = 24_u8
      Callable            = 25_u8
      Signal              = 26_u8
      Dictionary          = 27_u8
      Array               = 28_u8
      PackedByteArray     = 29_u8
      PackedInt32Array    = 30_u8
      PackedInt64Array    = 31_u8
      PackedFloat32Array  = 32_u8
      PackedFloat64Array  = 33_u8
      PackedStringArray   = 34_u8
      PackedVector2Array  = 35_u8
      PackedVector3Array  = 36_u8
      PackedColorArray    = 37_u8
      PackedVector4Array  = 38_u8
    end

    # Represents the binary header of a Godot Object in memory.
    # Standard GDExtension layout on 64-bit architectures:
    #   Offset 0x00: VTable pointer (8 bytes)
    #   Offset 0x08: 64-bit monotonic ObjectID (8 bytes)
    #   Offset 0x10: user_data pointer (Crystal wrapper / Extension instance) (8 bytes)
    #   Offset 0x18: user_data_type (8 bytes)
    struct GodotObjectHeader
      include JSON::Serializable

      getter vtable : UInt64
      getter instance_id : UInt64
      getter user_data : UInt64
      getter user_data_type : UInt64
      getter is_alive : Bool
      getter class_name : String?

      def initialize(
        @vtable : UInt64,
        @instance_id : UInt64,
        @user_data : UInt64 = 0_u64,
        @user_data_type : UInt64 = 0_u64,
        @is_alive : Bool = true,
        @class_name : String? = nil,
      )
      end

      # Reads an object header from a 32-byte memory slice.
      def self.from_bytes(bytes : Bytes, is_alive : Bool = true, class_name : String? = nil) : GodotObjectHeader
        return new(0_u64, 0_u64, is_alive: false) if bytes.size < 16

        vtable = IO::ByteFormat::LittleEndian.decode(UInt64, bytes[0, 8])
        id = IO::ByteFormat::LittleEndian.decode(UInt64, bytes[8, 8])
        ud = bytes.size >= 24 ? IO::ByteFormat::LittleEndian.decode(UInt64, bytes[16, 8]) : 0_u64
        udt = bytes.size >= 32 ? IO::ByteFormat::LittleEndian.decode(UInt64, bytes[24, 8]) : 0_u64

        new(vtable, id, ud, udt, is_alive: is_alive && id > 0, class_name: class_name)
      end
    end

    # Decoded Godot Variant value representation.
    class DecodedVariant
      include JSON::Serializable

      getter type : VariantType
      getter value : String
      getter summary : String
      getter address : UInt64?

      def initialize(@type : VariantType, @value : String, @summary : String, @address : UInt64? = nil)
      end
    end

    # Binary decoder for Godot Variant instances in process memory.
    class VariantDecoder
      # Decodes a Variant from raw bytes (typically 24 to 32 bytes).
      def self.decode(bytes : Bytes, address : UInt64? = nil, client : Cradare2::Client? = nil) : DecodedVariant
        return DecodedVariant.new(VariantType::Nil, "nil", "Nil", address) if bytes.size < 8

        # First byte or first 4 bytes contain the type tag
        raw_type = bytes[0]
        type = VariantType.from_value?(raw_type) || VariantType::Nil

        # Offset to payload data (usually at byte 8 to align 64-bit primitives)
        payload_offset = bytes.size >= 16 ? 8 : 4
        payload = bytes[payload_offset..] rescue bytes

        val_str = ""
        summary_str = "#{type}"

        case type
        when VariantType::Nil
          val_str = "nil"
          summary_str = "Nil"
        when VariantType::Bool
          b_val = payload.size >= 1 ? (payload[0] != 0_u8) : false
          val_str = b_val.to_s
          summary_str = "Bool(#{b_val})"
        when VariantType::Int
          if payload.size >= 8
            i_val = IO::ByteFormat::LittleEndian.decode(Int64, payload[0, 8])
            val_str = i_val.to_s
            summary_str = "Int(#{i_val})"
          else
            val_str = "0"
          end
        when VariantType::Float
          if payload.size >= 8
            f_val = IO::ByteFormat::LittleEndian.decode(Float64, payload[0, 8])
            val_str = f_val.to_s
            summary_str = "Float(#{f_val})"
          elsif payload.size >= 4
            f_val = IO::ByteFormat::LittleEndian.decode(Float32, payload[0, 4])
            val_str = f_val.to_s
            summary_str = "Float(#{f_val})"
          end
        when VariantType::String, VariantType::StringName
          if payload.size >= 8
            str_ptr = IO::ByteFormat::LittleEndian.decode(UInt64, payload[0, 8])
            if client && str_ptr > 0
              val_str = client.memory.read_cstring(str_ptr, 128)
            else
              val_str = "0x#{str_ptr.to_s(16)}"
            end
            summary_str = "#{type}(\"#{val_str}\")"
          end
        when VariantType::Vector2
          if payload.size >= 8
            x = IO::ByteFormat::LittleEndian.decode(Float32, payload[0, 4])
            y = IO::ByteFormat::LittleEndian.decode(Float32, payload[4, 4])
            val_str = "(#{x}, #{y})"
            summary_str = "Vector2(#{x}, #{y})"
          end
        when VariantType::Vector2i
          if payload.size >= 8
            x = IO::ByteFormat::LittleEndian.decode(Int32, payload[0, 4])
            y = IO::ByteFormat::LittleEndian.decode(Int32, payload[4, 4])
            val_str = "(#{x}, #{y})"
            summary_str = "Vector2i(#{x}, #{y})"
          end
        when VariantType::Vector3
          if payload.size >= 12
            x = IO::ByteFormat::LittleEndian.decode(Float32, payload[0, 4])
            y = IO::ByteFormat::LittleEndian.decode(Float32, payload[4, 4])
            z = IO::ByteFormat::LittleEndian.decode(Float32, payload[8, 4])
            val_str = "(#{x}, #{y}, #{z})"
            summary_str = "Vector3(#{x}, #{y}, #{z})"
          end
        when VariantType::Vector3i
          if payload.size >= 12
            x = IO::ByteFormat::LittleEndian.decode(Int32, payload[0, 4])
            y = IO::ByteFormat::LittleEndian.decode(Int32, payload[4, 4])
            z = IO::ByteFormat::LittleEndian.decode(Int32, payload[8, 4])
            val_str = "(#{x}, #{y}, #{z})"
            summary_str = "Vector3i(#{x}, #{y}, #{z})"
          end
        when VariantType::Color
          if payload.size >= 16
            r = IO::ByteFormat::LittleEndian.decode(Float32, payload[0, 4])
            g = IO::ByteFormat::LittleEndian.decode(Float32, payload[4, 4])
            b = IO::ByteFormat::LittleEndian.decode(Float32, payload[8, 4])
            a = IO::ByteFormat::LittleEndian.decode(Float32, payload[12, 4])
            val_str = "(#{r}, #{g}, #{b}, #{a})"
            summary_str = "Color(#{r}, #{g}, #{b}, #{a})"
          end
        when VariantType::Object
          if payload.size >= 8
            obj_ptr = IO::ByteFormat::LittleEndian.decode(UInt64, payload[0, 8])
            val_str = "0x#{obj_ptr.to_s(16)}"
            summary_str = "Object(#{val_str})"
          end
        else
          val_str = payload.hexstring
          summary_str = "#{type}[#{val_str}]"
        end

        DecodedVariant.new(type, val_str, summary_str, address)
      end

      # Reads and decodes a Variant at a specified virtual memory address.
      def self.decode_at(client : Cradare2::Client, address : Cradare2::Address) : DecodedVariant
        bytes = client.memory.read_bytes(address, 32)
        addr_u64 = address.is_a?(UInt64) ? address : address.to_u64?(16) || 0_u64
        decode(bytes, addr_u64, client)
      end
    end

    # Registers radare2 print format types (`pf`) for Godot data structures.
    class TypeMapRegistrar
      # Registers all standard Godot print formats into the radare2 session.
      def self.register_all(client : Cradare2::Client) : Nil
        # Godot Object Header (vtable, instance_id, user_data, user_data_type)
        client.types.define_format("godot_object", "qqqq vtable instance_id user_data user_data_type")

        # Godot 4 Variant Header
        client.types.define_format("godot_variant", "b...q type _pad payload")

        # Math types
        client.types.define_format("godot_vector2", "ff x y")
        client.types.define_format("godot_vector2i", "ii x y")
        client.types.define_format("godot_vector3", "fff x y z")
        client.types.define_format("godot_vector3i", "iii x y z")
        client.types.define_format("godot_vector4", "ffff x y z w")
        client.types.define_format("godot_color", "ffff r g b a")
        client.types.define_format("godot_transform3d", "ffffffffffff xx xy xz yx yy yz zx zy zz ox oy oz")
      end
    end
  end
end
