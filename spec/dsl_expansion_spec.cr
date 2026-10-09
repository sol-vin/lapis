require "./spec_helper"

class PipeSourcePlayer < Godot::Node
  signal action_performed(tag : String, intensity : Float64, priority : Int32)
  signal tapped
  signal level_up(new_level : Int32)
end

class PipeTargetUI < Godot::Node
  signal on_notify(tag : String, intensity : Float32)
  signal on_any_action
  signal on_level_changed(level : Int32)
  signal strict_level(level : Int32)
end

class PipeCollisionEmitter < Godot::Node
  signal body_entered(body : Godot::Node)
end

class PipeEnemyReceiver < Godot::Node
  signal enemy_detected(enemy : PipeTargetEnemy)
  signal non_enemy_detected(node : Godot::Node)
end

class PipeTargetEnemy < Godot::Node
  property enemy_type : String = "goblin"
end

describe "DSL Expansion Suite" do
  describe "Signal Piping: Strict (>) and Loose (>>)" do
    it "pipes strictly typed signal with exact signature using >" do
      source = PipeSourcePlayer.new
      target = PipeTargetUI.new
      received_level = 0

      # Strict pipe (both are Int32):
      source.level_up > target.strict_level

      target.strict_level.connect do |lvl|
        received_level = lvl
      end

      source.level_up.emit(42)
      received_level.should eq(42)
    end

    it "loosely pipes signals with arity trimming (3 args -> 2 args) and numeric conversion" do
      source = PipeSourcePlayer.new
      target = PipeTargetUI.new
      received_tag = ""
      received_intensity = 0.0_f32

      # Loose pipe drops priority (Int32) and converts intensity Float64 -> Float32
      source.action_performed >> target.on_notify

      target.on_notify.connect do |tag, intensity|
        received_tag = tag
        received_intensity = intensity
      end

      source.action_performed.emit("slash", 8.5_f64, 1)
      received_tag.should eq("slash")
      received_intensity.should eq(8.5_f32)
    end

    it "loosely pipes signals with arity trimming to 0 arguments" do
      source = PipeSourcePlayer.new
      target = PipeTargetUI.new
      call_count = 0

      # Drops all 3 arguments and triggers on_any_action
      source.action_performed >> target.on_any_action

      target.on_any_action.connect do
        call_count += 1
      end

      source.action_performed.emit("block", 1.0_f64, 0)
      source.action_performed.emit("dodge", 2.0_f64, 0)
      call_count.should eq(2)
    end

    it "loosely pipes signals with type downcasting and filtering" do
      emitter = PipeCollisionEmitter.new
      receiver = PipeEnemyReceiver.new
      detected_type = ""

      # Only emits if body is a PipeTargetEnemy!
      emitter.body_entered >> receiver.enemy_detected

      receiver.enemy_detected.connect do |enemy|
        detected_type = enemy.enemy_type
      end

      # Non-enemy node should be filtered out silently:
      wall = Godot::Node.new
      emitter.body_entered.emit(wall)
      detected_type.should eq("")

      # Enemy node should pass through and downcast:
      enemy = PipeTargetEnemy.new
      emitter.body_entered.emit(enemy)
      detected_type.should eq("goblin")
    end

    it "supports disconnecting piped signals" do
      source = PipeSourcePlayer.new
      target = PipeTargetUI.new
      count = 0

      sub = (source.tapped >> target.on_any_action)
      target.on_any_action.connect { count += 1 }

      source.tapped.emit
      count.should eq(1)

      sub.disconnect
      source.tapped.emit
      count.should eq(1)
    end
  end

  describe "Node Relative Spatial Navigation" do
    it "computes 2D distance_to, direction_to, and angle_to_point" do
      origin = Godot::Node2D.new
      origin.position = Godot::Vector2.new(10.0_f32, 20.0_f32)

      target = Godot::Node2D.new
      target.position = Godot::Vector2.new(40.0_f32, 60.0_f32)

      origin.distance_to(target).should be_close(50.0_f32, 0.001_f32)
      origin.distance_to(Godot::Vector2.new(40.0_f32, 60.0_f32)).should be_close(50.0_f32, 0.001_f32)

      dir = origin.direction_to(target)
      dir.x.should be_close(0.6_f32, 0.001_f32)
      dir.y.should be_close(0.8_f32, 0.001_f32)

      angle = origin.angle_to_point(target)
      angle.should be_close(Math.atan2(40.0_f32, 30.0_f32), 0.001_f32)
    end

    it "computes 3D distance_to and direction_to" do
      origin = Godot::Node3D.new
      origin.position = Godot::Vector3.new(0.0_f32, 0.0_f32, 0.0_f32)

      target = Godot::Node3D.new
      target.position = Godot::Vector3.new(0.0_f32, 3.0_f32, 4.0_f32)

      origin.distance_to(target).should be_close(5.0_f32, 0.001_f32)
      origin.distance_to(Godot::Vector3.new(0.0_f32, 3.0_f32, 4.0_f32)).should be_close(5.0_f32, 0.001_f32)

      dir = origin.direction_to(target)
      dir.y.should be_close(0.6_f32, 0.001_f32)
      dir.z.should be_close(0.8_f32, 0.001_f32)
    end
  end

  describe "CanvasItem Modulate & Visual Ergonomics" do
    it "exposes alpha modulate accessor and does not expose artificial fade wrappers" do
      item = Godot::CanvasItem.new
      item.responds_to?(:alpha).should be_true
      item.responds_to?(:fade_to).should be_false
      item.responds_to?(:fade_in).should be_false
      item.responds_to?(:fade_out).should be_false
    end
  end

  describe "InputEvent Action Matchers & Query Helpers" do
    it "delegates continuous input vectors and axes from Input singleton" do
      vec = Godot::Input.get_vector(:ui_left, :ui_right, :ui_up, :ui_down)
      vec.should be_a(Godot::Vector2)

      ax = Godot::Input.axis(:ui_left, :ui_right)
      ax.should be_a(Float32)
    end
  end

  describe "Procedural Vectors & Math Helpers" do
    it "creates Vector2 from angle and random directions" do
      v_right = Godot::Vector2.from_angle(0.0)
      v_right.x.should be_close(1.0_f32, 0.001_f32)
      v_right.y.should be_close(0.0_f32, 0.001_f32)

      v_down = Godot::Vector2.from_angle(Math::PI / 2.0)
      v_down.x.should be_close(0.0_f32, 0.001_f32)
      v_down.y.should be_close(1.0_f32, 0.001_f32)

      # Random direction unit length check
      5.times do
        rnd = Godot::Vector2.random_direction
        rnd.length.should be_close(1.0_f32, 0.001_f32)
      end

      # Random range check
      rnd_box = Godot::Vector2.random(10.0..20.0, -5.0..5.0)
      rnd_box.x.should be >= 10.0_f32
      rnd_box.x.should be <= 20.0_f32
      rnd_box.y.should be >= -5.0_f32
      rnd_box.y.should be <= 5.0_f32
    end

    it "creates Vector3 random directions on unit sphere" do
      5.times do
        rnd3 = Godot::Vector3.random_direction
        rnd3.length.should be_close(1.0_f32, 0.001_f32)
      end

      rnd_cube = Godot::Vector3.random(0.0..10.0, 0.0..10.0, 0.0..10.0)
      rnd_cube.x.should be >= 0.0_f32
      rnd_cube.x.should be <= 10.0_f32
    end

    it "creates Color from hex strings and random colors" do
      red = Godot::Color.hex("#ff0000")
      red.r.should be_close(1.0_f32, 0.001_f32)
      red.g.should be_close(0.0_f32, 0.001_f32)
      red.b.should be_close(0.0_f32, 0.001_f32)
      red.a.should be_close(1.0_f32, 0.001_f32)

      rnd_col = Godot::Color.random
      rnd_col.r.should be >= 0.0_f32
      rnd_col.r.should be <= 1.0_f32
      rnd_col.a.should eq(1.0_f32)

      rnd_col_alpha = Godot::Color.random(include_alpha: true)
      rnd_col_alpha.a.should be <= 1.0_f32
    end
  end
end
