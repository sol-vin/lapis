require "./spec_helper"

class MatchSpecHero < Godot::Node
  property name : String = "Hero"
  property level : Int32 = 10
end

class MatchSpecMonster < Godot::Node
  property boss : Bool = true
end

describe "Lapis::Match" do
  it "matches polymorphic class types with downcasting" do
    hero = MatchSpecHero.new
    monster = MatchSpecMonster.new

    result1 = match hero do
      is MatchSpecHero do |h|
        "Hero lvl #{h.level}"
      end
      is MatchSpecMonster do |_m|
        "Monster"
      end
      default do
        "Unknown"
      end
    end

    result2 = match monster do
      is MatchSpecHero do |_h|
        "Hero"
      end
      is MatchSpecMonster do |m|
        m.boss ? "Boss Monster" : "Minion"
      end
      default do
        "Unknown"
      end
    end

    result1.should eq("Hero lvl 10")
    result2.should eq("Boss Monster")
  end

  it "matches Variant unboxed types" do
    v_int = Godot::Variant.new(42_i64)
    v_str = Godot::Variant.new("Lapis Engine")
    v_vec = Godot::Variant.new(Godot::Vector2.new(10.0_f32, 20.0_f32))

    eval_v = ->(v : Godot::Variant) {
      match v do
        is Int64 do |i|
          "Int: #{i * 2}"
        end
        is String do |s|
          "Str: #{s.upcase}"
        end
        is Godot::Vector2 do |vec|
          "Vec: #{vec.x}, #{vec.y}"
        end
        default do
          "Other"
        end
      end
    }

    eval_v.call(v_int).should eq("Int: 84")
    eval_v.call(v_str).should eq("Str: LAPIS ENGINE")
    eval_v.call(v_vec).should eq("Vec: 10.0, 20.0")
  end

  it "matches value equality" do
    code = 404
    status = match code do
      is 200 do
        "OK"
      end
      is 404 do
        "Not Found"
      end
      is 500 do
        "Internal Server Error"
      end
      default do
        "Unknown"
      end
    end

    status.should eq("Not Found")
  end

  it "evaluates pattern guards" do
    score = 85
    grade = match score do
      is Int32, if: score >= 90 do
        "A"
      end
      is Int32, if: score >= 80 do
        "B"
      end
      is Int32, if: score >= 70 do
        "C"
      end
      default do
        "F"
      end
    end

    grade.should eq("B")
  end

  it "destructures tuples" do
    action = {:jump, false}
    text = match action do
      is :jump, true do
        "Air Jump"
      end
      is :jump, false do
        "Ground Jump"
      end
      default do
        "Other"
      end
    end

    text.should eq("Ground Jump")
  end

  it "matches array rest with double dot: [first, .., last]" do
    arr = [1, 2, 3, 4, 5]
    summary = match arr do
      is [first, .., last] do |h, t|
        "Head: #{h}, Tail: #{t}"
      end
      default do
        "Other"
      end
    end

    summary.should eq("Head: 1, Tail: 5")
  end

  it "matches array rest with rest macro: rest(head, _, _, tail)" do
    arr = ["GET", "/api/v1/users", "HTTP/1.1", "200"]
    parsed = match arr do
      is rest(method, _, _, status) do |m, s|
        "#{m} -> #{s}"
      end
      default do
        "Invalid format"
      end
    end

    parsed.should eq("GET -> 200")
  end

  it "matches partial dictionaries with dict macro" do
    packet = {
      "type" => "chat",
      "user" => "Alice",
      "msg"  => "Hello world!",
      "time" => 123456789_i64
    }

    message = match packet do
      is dict(type: "login", user: u) do |_, u|
        "User #{u} logged in"
      end
      is dict(type: "chat", user: u, msg: m) do |_, u, m|
        "#{u}: #{m}"
      end
      default do
        "Unknown packet"
      end
    end

    message.should eq("Alice: Hello world!")
  end

  it "supports wildcard is _" do
    val = 999
    res = match val do
      is 1 do
        "One"
      end
      is _ do
        "Wildcard matched"
      end
    end

    res.should eq("Wildcard matched")
  end
end
