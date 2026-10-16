require "./spec_helper"

class EdgeSpecProbeNode < Godot::Node
  property value : Int32 = 0
  property tag : String = "edge"

  def ping! : Void
    @value += 1
  end
end

describe "DSL Edge Cases & New Features" do
  describe "Expression Pattern Matching (match)" do
    it "narrows target variable implicitly across basic and math types" do
      val_i = Godot::Variant.new(100_i64)
      res_i = match val_i do
        is Int64  do "Integer: #{val_i * 2}" end
        is String do "String: #{val_i}" end
        default   do "other" end
      end
      res_i.should eq("Integer: 200")

      val_s = Godot::Variant.new("crystal")
      res_s = match val_s do
        is Int64  do "Integer: #{val_s}" end
        is String do "String: #{val_s.upcase}" end
        default   do "other" end
      end
      res_s.should eq("String: CRYSTAL")

      val_v = Godot::Variant.new(Godot::Vector2.new(5.0_f32, 10.0_f32))
      res_v = match val_v do
        is Godot::Vector2 do "Vector: (#{val_v.x.to_i}, #{val_v.y.to_i})" end
        default           do "other" end
      end
      res_v.should eq("Vector: (5, 10)")
    end

    it "handles boolean guard conditions" do
      val = Godot::Variant.new(250_i64)
      res = match val do
        is Int64, if: val > 200 do "high" end
        is Int64                do "low" end
        default                 do "none" end
      end
      res.should eq("high")

      val_small = Godot::Variant.new(50_i64)
      res_small = match val_small do
        is Int64, if: val_small > 200 do "high" end
        is Int64                      do "low" end
        default                       do "none" end
      end
      res_small.should eq("low")
    end

    it "supports explicit block parameter names" do
      val = Godot::Variant.new(99_i64)
      res = match val do
        is Int64 do |score| "Score: #{score + 1}" end
        default  do "unknown" end
      end
      res.should eq("Score: 100")
    end

    it "supports receiver scoping without block parameter" do
      probe = EdgeSpecProbeNode.new
      matched_called = false
      res = match probe do
        is EdgeSpecProbeNode do
          ping!
          matched_called = true
          "pinged_#{value}"
        end
        default do "other" end
      end
      matched_called.should be_true
      res.should eq("pinged_1")
      probe.value.should eq(1)
    end

    it "supports receiver scoping with expression target" do
      container = NamedTuple.new(entity: EdgeSpecProbeNode.new)
      res = match container[:entity] do
        is EdgeSpecProbeNode do
          ping!
          "container_pinged_#{value}"
        end
        default do "other" end
      end
      res.should eq("container_pinged_1")
      container[:entity].value.should eq(1)
    end

    it "handles fallback to default branch" do
      val = Godot::Variant.new(true)
      res = match val do
        is Int64  do "int" end
        is String do "str" end
        default   do "default_fallback" end
      end
      res.should eq("default_fallback")
    end
  end

  describe "Symbol and String Group Parity" do
    it "compiles in_group? with symbols and strings cleanly" do
      node = Godot::Node.new
      # In headless mode without live engine ObjectDB, in_group? safely returns false
      node.in_group?(:combat_units).should be_false
      node.in_group?("combat_units").should be_false
    end
  end
end
