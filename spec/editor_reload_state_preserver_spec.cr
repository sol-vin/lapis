require "./spec_helper"
require "../src/libgodot/editor/state_preserver"

describe Lapis::Editor::StatePreserver do
  describe "Category A: Primitive Types & Scalars" do
    it "serializes and deserializes standard integers cleanly" do
      v1 = Godot::Variant.new(42_i64)
      json = Lapis::Editor::StatePreserver.serialize_variant_value(v1)
      res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Int64")
      res.should_not be_nil
      res.not_nil!.as_i64.should eq(42_i64)
    end

    it "serializes and deserializes boundary integer values" do
      [-128_i64, 0_i64, 127_i64, -32768_i64, 32767_i64, 2147483647_i64].each do |num|
        v = Godot::Variant.new(num)
        json = Lapis::Editor::StatePreserver.serialize_variant_value(v)
        res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Int64")
        res.should_not be_nil
        res.not_nil!.as_i64.should eq(num)
      end
    end

    it "serializes and deserializes floating-point scalars" do
      [0.0, 3.14159, -99.5, 100000.25].each do |flt|
        v = Godot::Variant.new(flt)
        json = Lapis::Editor::StatePreserver.serialize_variant_value(v)
        res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Float64")
        res.should_not be_nil
        (res.not_nil!.as_f64 - flt).abs.should be < 0.0001
      end
    end

    it "serializes and deserializes booleans accurately" do
      [true, false].each do |b|
        v = Godot::Variant.new(b)
        json = Lapis::Editor::StatePreserver.serialize_variant_value(v)
        res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Bool")
        res.should_not be_nil
        res.not_nil!.as_bool.should eq(b)
      end
    end

    it "serializes and deserializes strings with Unicode and special characters" do
      ["Player1", "Hello 🌍 World", "Quotes: \"test\" & \nnewlines", "100KB: " + ("a" * 1000)].each do |str|
        v = Godot::Variant.new(str)
        json = Lapis::Editor::StatePreserver.serialize_variant_value(v)
        res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "String")
        res.should_not be_nil
        res.not_nil!.to_s.should eq(str)
      end
    end
  end

  describe "Category B: Engine Math & Vectors" do
    it "preserves Vector2 coordinates" do
      vec = Godot::Vector2.new(120.5_f32, -45.0_f32)
      v = Godot::Variant.new(vec)
      json = Lapis::Editor::StatePreserver.serialize_variant_value(v)
      res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Vector2")
      res.should_not be_nil
      r_vec = res.not_nil!.as_vector2
      r_vec.x.should eq(120.5_f32)
      r_vec.y.should eq(-45.0_f32)
    end

    it "preserves Vector3 spatial coordinates" do
      vec = Godot::Vector3.new(1.0_f32, 2.5_f32, -10.0_f32)
      v = Godot::Variant.new(vec)
      json = Lapis::Editor::StatePreserver.serialize_variant_value(v)
      res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Vector3")
      res.should_not be_nil
      r_vec = res.not_nil!.as_vector3
      r_vec.x.should eq(1.0_f32)
      r_vec.y.should eq(2.5_f32)
      r_vec.z.should eq(-10.0_f32)
    end

    it "preserves Color RGBA channels" do
      color = Godot::Color.new(0.8_f32, 0.2_f32, 0.5_f32, 1.0_f32)
      v = Godot::Variant.new(color)
      json = Lapis::Editor::StatePreserver.serialize_variant_value(v)
      res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Color")
      res.should_not be_nil
      r_c = res.not_nil!.as_color
      (r_c.r - 0.8_f32).abs.should be < 0.01
      (r_c.g - 0.2_f32).abs.should be < 0.01
      (r_c.b - 0.5_f32).abs.should be < 0.01
      r_c.a.should eq(1.0_f32)
    end
  end

  describe "Category D: Node References & Dead-Pointer Traps" do
    it "sanitizes dead or nil node references cleanly" do
      v_nil = Godot::Variant.new
      json = Lapis::Editor::StatePreserver.serialize_variant_value(v_nil)
      res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Node")
      res.should_not be_nil
      res.not_nil!.is_nil?.should be_true
    end
  end

  describe "Category F: Schema Drift Reconciliation" do
    it "coerces integer to float on numeric widening" do
      json = "100"
      res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Float32")
      res.should_not be_nil
      res.not_nil!.as_f64.should eq(100.0)
    end

    it "coerces float to integer safely" do
      json = "42.8"
      res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Int32")
      res.should_not be_nil
      res.not_nil!.as_i64.should eq(42_i64)
    end

    it "discards incompatible type drift gracefully" do
      json = "not_a_vector"
      res = Lapis::Editor::StatePreserver.deserialize_variant_value(json, "Vector3")
      res.should be_nil
    end
  end

  describe "Category G & H: Transactional Lifecycle and Stress" do
    it "handles empty scene or non-editor environment without error" do
      # Running outside editor returns 0 cleanly
      Lapis::Editor::StatePreserver.snapshot_edited_scene.should eq(0)
      Lapis::Editor::StatePreserver.restore_edited_scene.should eq(0)
    end
  end
end
