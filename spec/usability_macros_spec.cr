require "spec"
require "../src/libgodot"

# Custom test node class to exercise the new DSL macros
node UsabilityTestNode < Node2D do
  property speed : Float32 = 0.0_f32
  property score : Int32 = 0
  property label_text : String = ""

  signal scored(amount : Int32)
  signal finished

  def bump_score(pts : Int32) : Void
    @score += pts
  end
end

describe "Lapis Usability Macros & Ergonomic DSL" do
  describe "Fluent Instantiation & Property Setting" do
    it "instantiates and configures via create macro with keyword arguments" do
      node = create UsabilityTestNode, speed: 25.5_f32, score: 100, label_text: "Hero"
      node.should be_a(UsabilityTestNode)
      node.speed.should eq(25.5_f32)
      node.score.should eq(100)
      node.label_text.should eq("Hero")
    end

    it "instantiates and configures via create macro with block property assignments and method calls" do
      node = create UsabilityTestNode do
        speed = 50.0_f32
        score = 250
        label_text = "Boss"
        bump_score(50)
        add_to_group("enemies")
      end
      node.should be_a(UsabilityTestNode)
      node.speed.should eq(50.0_f32)
      node.score.should eq(300)
      node.label_text.should eq("Boss")
      node.in_group?("enemies").should be_true
    end

    it "instantiates and configures via build alias macro" do
      node = build UsabilityTestNode, speed: 75.0_f32, score: 400
      node.speed.should eq(75.0_f32)
      node.score.should eq(400)
    end

    it "instantiates and configures via class-level create macro" do
      node = UsabilityTestNode.create do
        speed = 100.0_f32
        score = 500
        bump_score(25)
      end
      node.speed.should eq(100.0_f32)
      node.score.should eq(525)
    end

    it "instantiates and configures via class-level build macro" do
      node = UsabilityTestNode.build(speed: 80.0_f32) do
        score = 600
      end
      node.speed.should eq(80.0_f32)
      node.score.should eq(600)
    end

    it "instantiates via Object.new with block parameter" do
      node = UsabilityTestNode.new do |n|
        n.speed = 120.0_f32
        n.score = 700
      end
      node.speed.should eq(120.0_f32)
      node.score.should eq(700)
    end

    it "configures existing object in-place using configure method" do
      node = Godot.create(UsabilityTestNode)
      node.configure do |n|
        n.speed = 150.0_f32
        n.score = 800
      end
      node.speed.should eq(150.0_f32)
      node.score.should eq(800)
    end
  end

  describe "Entity Spawning & Scene Tree Attachment" do
    it "spawns a node and attaches to parent via spawn_node macro" do
      parent = Godot.create(Godot::Node2D)
      child = spawn_node UsabilityTestNode, under: parent, speed: 10.0_f32, score: 50
      parent.child_count.should eq(1)
      child.speed.should eq(10.0_f32)
      child.score.should eq(50)
      child.get_parent.should eq(parent)
    end

    it "spawns a child node via spawn_child macro" do
      parent = Godot.create(Godot::Node2D)
      child = spawn_child UsabilityTestNode, under: parent do
        speed = 20.0_f32
        score = 80
      end
      parent.child_count.should eq(1)
      child.speed.should eq(20.0_f32)
      child.score.should eq(80)
      child.get_parent.should eq(parent)
    end

    it "spawns a child node via Node#spawn_child instance method" do
      parent = Godot.create(Godot::Node2D)
      child = parent.spawn_child(UsabilityTestNode) do |n|
        n.speed = 30.0_f32
        n.score = 90
      end
      parent.child_count.should eq(1)
      child.speed.should eq(30.0_f32)
      child.score.should eq(90)
      child.get_parent.should eq(parent)
    end

    it "creates a child node via Node#create_child instance method with block" do
      parent = Godot.create(Godot::Node2D)
      child = parent.create_child(UsabilityTestNode) do |n|
        n.speed = 40.0_f32
        n.score = 110
      end
      parent.child_count.should eq(1)
      child.speed.should eq(40.0_f32)
      child.score.should eq(110)
      child.get_parent.should eq(parent)
    end
  end

  describe "Signal Connection Sugar (on)" do
    it "connects block to TypedSignal via on macro" do
      emitter = Godot.create(UsabilityTestNode)
      received = 0
      on(emitter.scored) do |amount|
        received = amount
      end

      emitter.scored.emit(123)
      received.should eq(123)
    end

    it "connects zero-argument signal via on macro" do
      emitter = Godot.create(UsabilityTestNode)
      called = false
      on(emitter.finished) do
        called = true
      end

      emitter.finished.emit
      called.should be_true
    end
  end

  describe "Timers and Tweening Extensions" do
    it "provides Node#after and Node#every methods" do
      node = Godot.create(Godot::Node2D)
      node.responds_to?(:after).should be_true
      node.responds_to?(:every).should be_true
    end

    it "provides Node#tween without tween_to or punch_scale" do
      node = Godot.create(Godot::Node2D)
      node.responds_to?(:tween).should be_true
      node.responds_to?(:tween_to).should be_false
      node.responds_to?(:punch_scale).should be_false
    end

    it "supports tween macro with dot syntax, fluent chaining, and Time::Span" do
      node = Godot.create(Godot::Node2D)
      t1 = tween(node.position.y, to: 150.0_f32, in: 0.4.seconds)
      t1.should be_a(Godot::Tween)
      t2 = tween(node) do
        animate(scale, to: Godot::Vector2.new(1.2_f32, 1.2_f32), in: 0.2.seconds)
      end
      t2.should be_a(Godot::Tween)
    end

    it "supports automatic statement peeling with chain(), parallel(), and ease(Ease.Out)" do
      node = UsabilityTestNode.new
      tw = tween(node) do
        animate(speed, to: 120.0_f32, in: 4.seconds)
        chain()
        animate(score, from: 120, to: 400, in: 10.seconds)
        parallel()
        ease(Ease.Out)
      end
      tw.should be_a(Godot::Tween)
    end
  end
end
