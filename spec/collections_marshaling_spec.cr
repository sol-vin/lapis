require "./spec_helper"

describe "Issue #10 Collection, TypedArray, Variant & Projection Marshaling" do
  describe "Godot::Projection" do
    it "has 64-byte layout and supports identity and matrix-vector multiplication" do
      sizeof(Godot::Projection).should eq(64)
      p = Godot::Projection.identity
      v = Godot::Vector4.new(2.0_f32, 3.0_f32, 4.0_f32, 1.0_f32)
      (p * v).should eq(v)
      (p * Godot::Projection.identity).should eq(p)
    end
  end

  describe "Variant & VariantPackArena recursive containers" do
    it "boxes and unboxes GodotArray(Variant), ::Array, ::Hash, RID, NodePath, and Projection" do
      v_arr = Godot::Variant.new([10, 20, 30])
      v_arr.array?.should be_true
      typed_ints = v_arr.as_t(Godot::GodotArray(Int64))
      typed_ints.should eq([10_i64, 20_i64, 30_i64])

      v_hash = Godot::Variant.new({"hp" => 100, "tags" => ["fire", "boss"]})
      v_hash.dict?.should be_true
      d = v_hash.as_dict
      d["hp"].as_i64.should eq(100_i64)
      nested_tags = d["tags"].as_array_of(String)
      nested_tags.should eq(["fire", "boss"])

      rid = Godot::RID.new(987654321_u64)
      v_rid = Godot::Variant.new(rid)
      v_rid.as_t(Godot::RID).id.should eq(987654321_u64)

      proj = Godot::Projection.identity
      v_proj = Godot::Variant.new(proj)
      v_proj.as_t(Godot::Projection).should eq(proj)
    end

    it "roundtrips nested Dictionary + GodotArray + PackedStringArray through VariantArg without clobbering" do
      arena = Godot::VariantPackArena.new
      psa = Godot::PackedStringArray.new(["alpha", "beta", "gamma"])
      inner_dict = Godot::Dictionary.from({"names" => psa, "origin" => Godot::Vector2i.new(-42, 999999)})
      outer = Godot::GodotArray(Godot::Variant).new([
        Godot::Variant.new(inner_dict),
        Godot::Variant.new(Godot::Transform3D.identity.translated(Godot::Vector3.new(1, 2, 3))),
      ])

      root_arg = Godot::Variant.value_to_arg(outer, arena)
      root_arg.type.should eq(28)

      unpacked = Godot::Variant.from_arg(root_arg)
      arr = unpacked.as_a
      arr.size.should eq(2_i64)

      u_dict = arr[0].as_dict
      u_dict["names"].as_packed_string_array.should eq(["alpha", "beta", "gamma"])
      u_dict["origin"].as_v2i.should eq(Godot::Vector2i.new(-42, 999999))
      arr[1].as_transform3d.origin.should eq(Godot::Vector3.new(1.0_f32, 2.0_f32, 3.0_f32))
    end

    it "supports Variant.default_for across all collection and TypedArray types for TypedSignal" do
      Godot::Variant.default_for(Godot::Dictionary).size.should eq(0_i64)
      Godot::Variant.default_for(Godot::GodotArray(Godot::Font)).size.should eq(0_i64)
      Godot::Variant.default_for(Godot::GodotArray(Godot::Variant)).size.should eq(0_i64)
      Godot::Variant.default_for(Godot::PackedByteArray).size.should eq(0_i64)
      Godot::Variant.default_for(Godot::PackedStringArray).size.should eq(0_i64)
      Godot::Variant.default_for(Godot::PackedVector2Array).size.should eq(0_i64)
      Godot::Variant.default_for(Godot::PackedVector4Array).size.should eq(0_i64)
      Godot::Variant.default_for(Godot::Projection).should eq(Godot::Projection.identity)
      Godot::Variant.default_for(Godot::RID).id.should eq(0_u64)
    end
  end

  describe "PackedByteArray Bytes interop and generated binding types" do
    it "converts cleanly between Crystal Bytes and Godot::PackedByteArray" do
      src = Bytes[1_u8, 2_u8, 3_u8, 254_u8]
      pba = Godot::PackedByteArray.from(src)
      pba.size.should eq(4_i64)
      pba.to_slice.should eq(src)
      pba.should eq([1_u8, 2_u8, 3_u8, 254_u8])
    end

    it "exposes typed return and covariant input signatures on AStarGrid2D and Font" do
      grid = Godot::AStarGrid2D.new
      typeof(grid.get_id_path(Godot::Vector2i.new, Godot::Vector2i.new)).should eq(Godot::GodotArray(Godot::Vector2i))
      typeof(grid.get_point_path(Godot::Vector2i.new, Godot::Vector2i.new)).should eq(Godot::PackedVector2Array)

      font = Godot::Font.new
      sub_font = Godot::FontFile.new
      typeof(font.get_fallbacks).should eq(Godot::GodotArray(Godot::Font))
      typeof(font.set_fallbacks([sub_font])).should eq(Nil)
      typeof(font.call("get_fallbacks")).should eq(Godot::Variant)
    end
  end
end
