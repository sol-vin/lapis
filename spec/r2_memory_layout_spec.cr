require "spec"
require "../src/libgodot/debugger/r2_godot_types"

describe "Godot Radare2 Memory Layouts & Decoders" do
  describe Lapis::Debugger::VariantType do
    it "matches official Godot 4.x GDExtensionVariantType enum values" do
      Lapis::Debugger::VariantType::Nil.value.should eq(0_u8)
      Lapis::Debugger::VariantType::Bool.value.should eq(1_u8)
      Lapis::Debugger::VariantType::Int.value.should eq(2_u8)
      Lapis::Debugger::VariantType::Float.value.should eq(3_u8)
      Lapis::Debugger::VariantType::String.value.should eq(4_u8)
      Lapis::Debugger::VariantType::Vector2.value.should eq(5_u8)
      Lapis::Debugger::VariantType::Vector3.value.should eq(9_u8)
      Lapis::Debugger::VariantType::Transform3D.value.should eq(18_u8)
      Lapis::Debugger::VariantType::Color.value.should eq(20_u8)
      Lapis::Debugger::VariantType::StringName.value.should eq(21_u8)
      Lapis::Debugger::VariantType::Object.value.should eq(24_u8)
      Lapis::Debugger::VariantType::Dictionary.value.should eq(27_u8)
      Lapis::Debugger::VariantType::Array.value.should eq(28_u8)
    end
  end

  describe Lapis::Debugger::GodotObjectHeader do
    it "decodes object header from little-endian memory bytes" do
      buf = IO::Memory.new
      # VTable (0x140010000)
      IO::ByteFormat::LittleEndian.encode(0x140010000_u64, buf)
      # Monotonic ObjectID (1482)
      IO::ByteFormat::LittleEndian.encode(1482_u64, buf)
      # UserData pointer (0x21b3759c2f0)
      IO::ByteFormat::LittleEndian.encode(0x21b3759c2f0_u64, buf)
      # UserDataType (1)
      IO::ByteFormat::LittleEndian.encode(1_u64, buf)

      bytes = buf.to_slice
      header = Lapis::Debugger::GodotObjectHeader.from_bytes(bytes, is_alive: true, class_name: "Player")

      header.vtable.should eq(0x140010000_u64)
      header.instance_id.should eq(1482_u64)
      header.user_data.should eq(0x21b3759c2f0_u64)
      header.user_data_type.should eq(1_u64)
      header.is_alive.should be_true
      header.class_name.should eq("Player")
    end

    it "flags zero instance ID as dead pointer" do
      bytes = Bytes.new(32, 0_u8)
      header = Lapis::Debugger::GodotObjectHeader.from_bytes(bytes)
      header.is_alive.should be_false
      header.instance_id.should eq(0_u64)
    end
  end

  describe Lapis::Debugger::VariantDecoder do
    it "decodes Nil Variant" do
      bytes = Bytes[0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8]
      res = Lapis::Debugger::VariantDecoder.decode(bytes)
      res.type.should eq(Lapis::Debugger::VariantType::Nil)
      res.value.should eq("nil")
    end

    it "decodes Bool Variant (true and false)" do
      # Bool true (type tag 1, payload offset 8 = 1)
      buf_true = Bytes.new(16, 0_u8)
      buf_true[0] = 1_u8 # type tag Bool
      buf_true[8] = 1_u8 # true
      res_true = Lapis::Debugger::VariantDecoder.decode(buf_true)
      res_true.type.should eq(Lapis::Debugger::VariantType::Bool)
      res_true.value.should eq("true")

      # Bool false (type tag 1, payload offset 8 = 0)
      buf_false = Bytes.new(16, 0_u8)
      buf_false[0] = 1_u8
      buf_false[8] = 0_u8
      res_false = Lapis::Debugger::VariantDecoder.decode(buf_false)
      res_false.type.should eq(Lapis::Debugger::VariantType::Bool)
      res_false.value.should eq("false")
    end

    it "decodes 64-bit Int Variant" do
      buf = IO::Memory.new
      buf.write_byte(2_u8) # type Int
      7.times { buf.write_byte(0_u8) } # padding to 8 bytes
      IO::ByteFormat::LittleEndian.encode(42_424_242_i64, buf)

      res = Lapis::Debugger::VariantDecoder.decode(buf.to_slice)
      res.type.should eq(Lapis::Debugger::VariantType::Int)
      res.value.should eq("42424242")
    end

    it "decodes 64-bit Float Variant" do
      buf = IO::Memory.new
      buf.write_byte(3_u8) # type Float
      7.times { buf.write_byte(0_u8) }
      IO::ByteFormat::LittleEndian.encode(3.141592653589793_f64, buf)

      res = Lapis::Debugger::VariantDecoder.decode(buf.to_slice)
      res.type.should eq(Lapis::Debugger::VariantType::Float)
      res.value.starts_with?("3.14159").should be_true
    end

    it "decodes Vector3 Variant" do
      buf = IO::Memory.new
      buf.write_byte(9_u8) # type Vector3
      7.times { buf.write_byte(0_u8) }
      IO::ByteFormat::LittleEndian.encode(10.5_f32, buf)
      IO::ByteFormat::LittleEndian.encode(20.25_f32, buf)
      IO::ByteFormat::LittleEndian.encode(-5.0_f32, buf)

      res = Lapis::Debugger::VariantDecoder.decode(buf.to_slice)
      res.type.should eq(Lapis::Debugger::VariantType::Vector3)
      res.value.should contain("10.5")
      res.value.should contain("20.25")
      res.value.should contain("-5")
    end

    it "decodes Color Variant" do
      buf = IO::Memory.new
      buf.write_byte(20_u8) # type Color
      7.times { buf.write_byte(0_u8) }
      IO::ByteFormat::LittleEndian.encode(1.0_f32, buf) # r
      IO::ByteFormat::LittleEndian.encode(0.5_f32, buf) # g
      IO::ByteFormat::LittleEndian.encode(0.0_f32, buf) # b
      IO::ByteFormat::LittleEndian.encode(1.0_f32, buf) # a

      res = Lapis::Debugger::VariantDecoder.decode(buf.to_slice)
      res.type.should eq(Lapis::Debugger::VariantType::Color)
      res.value.should contain("1.0")
      res.value.should contain("0.5")
    end
  end
end
