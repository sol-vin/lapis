require "./spec_helper"

describe "LibGodot Core & Node DSL" do
  describe "ClassRegistry" do
    it "registers declared nodes in ClassRegistry" do
      entries = Godot::ClassRegistry.entries
      entries.size.should be >= 2

      camera_entry = entries.find { |e| e.class_name == "SpecCameraRig" }
      camera_entry.should_not be_nil
      camera_entry.not_nil!.parent_name.should eq("Node")

      player_entry = entries.find { |e| e.class_name == "SpecPlayer" }
      player_entry.should_not be_nil
      player_entry.not_nil!.parent_name.should eq("CharacterBody3D")
    end

    it "registers exported properties in ClassRegistry entries" do
      player_entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "SpecPlayer" }.not_nil!
      speed_prop = player_entry.properties.find { |p| p.name == "speed" }
      speed_prop.should_not be_nil

      health_prop = player_entry.properties.find { |p| p.name == "max_health" }
      health_prop.should_not be_nil
    end

    it "registers custom signals in ClassRegistry entries" do
      player_entry = Godot::ClassRegistry.entries.find { |e| e.class_name == "SpecPlayer" }.not_nil!
      health_sig = player_entry.signals.find { |s| s.name == "health_changed" }
      health_sig.should_not be_nil
      health_sig.not_nil!.args.size.should eq(2)

      died_sig = player_entry.signals.find { |s| s.name == "died" }
      died_sig.should_not be_nil
      died_sig.not_nil!.args.size.should eq(0)
    end
  end

  describe "Node Instantiation & Properties" do
    it "initializes nodes with default property values" do
      player = SpecPlayer.new
      player.speed.should eq(300.0_f32)
      player.max_health.should eq(100)
    end

    it "allows updating property values" do
      player = SpecPlayer.new
      player.speed = 450.0_f32
      player.speed.should eq(450.0_f32)

      player.max_health = 200
      player.max_health.should eq(200)
    end
  end

  describe "Range Type Cohesion" do
    it "initializes custom Range sliders with bounds" do
      slider = SpecCustomSlider.new(0..100)
      slider.min_value.should eq(0.0)
      slider.max_value.should eq(100.0)
    end

    it "supports range assignment and queries" do
      slider = SpecCustomSlider.new(0..100)
      slider.range = 25..75
      slider.to_range.should eq(25.0..75.0)
      slider.includes?(50).should be_true
      slider.includes?(10).should be_false
    end

    it "generates Godot hint strings from Range" do
      hint = (0.0..100.0).to_godot_hint_string(0.5)
      hint.should eq("0.0,100.0,0.5")
    end

    it "extracts bounds tuples from Range" do
      bounds = (10..50).to_godot_bounds
      bounds.should eq({10.0, 50.0})
    end
  end

  describe "Node Hierarchy & Path Navigation" do
    it "raises an exception when get_node receives an invalid path" do
      test_node = Godot::Node.new
      expect_raises(Exception, /Node not found/) do
        test_node.get_node("non_existent_node")
      end
    end

    it "returns nil when get_node? receives an invalid path" do
      test_node = Godot::Node.new
      test_node.get_node?("non_existent_node").should be_nil
    end

    it "returns nil when get_node_or_null receives an invalid path" do
      test_node = Godot::Node.new
      test_node.get_node_or_null("non_existent_node").should be_nil
    end
  end

  describe "Node Property Aliases" do
    it "supports Node3D spatial property getters and setters" do
      n3d = Godot::Node3D.new
      n3d.position = Vector3.new(1.0, 2.0, 3.0)
      n3d.position.should eq(Vector3.new(1.0_f32, 2.0_f32, 3.0_f32))

      n3d.global_position = Vector3.new(10.0, 20.0, 30.0)
      n3d.global_position.should eq(Vector3.new(10.0_f32, 20.0_f32, 30.0_f32))

      n3d.rotation = Vector3.new(0.1, 0.2, 0.3)
      n3d.rotation.should eq(Vector3.new(0.1_f32, 0.2_f32, 0.3_f32))

      n3d.rotation_degrees = Vector3.new(45.0, 90.0, 0.0)
      n3d.rotation_degrees.should eq(Vector3.new(45.0_f32, 90.0_f32, 0.0_f32))

      n3d.global_rotation = Vector3.new(0.4, 0.5, 0.6)
      n3d.global_rotation.should eq(Vector3.new(0.4_f32, 0.5_f32, 0.6_f32))

      n3d.global_rotation_degrees = Vector3.new(180.0, 0.0, 0.0)
      n3d.global_rotation_degrees.should eq(Vector3.new(180.0_f32, 0.0_f32, 0.0_f32))

      n3d.scale = Vector3.new(2.0, 2.0, 2.0)
      n3d.scale.should eq(Vector3.new(2.0_f32, 2.0_f32, 2.0_f32))

      n3d.visible = false
      n3d.visible?.should be_false
      n3d.visible = true
      n3d.visible?.should be_true

      n3d.top_level = true
      n3d.top_level.should be_true

      t = Transform3D.new(Basis.new, Vector3.new(5.0, 6.0, 7.0))
      n3d.transform = t
      n3d.transform.origin.should eq(Vector3.new(5.0_f32, 6.0_f32, 7.0_f32))

      gt = Transform3D.new(Basis.new, Vector3.new(50.0, 60.0, 70.0))
      n3d.global_transform = gt
      n3d.global_transform.origin.should eq(Vector3.new(50.0_f32, 60.0_f32, 70.0_f32))

      b = Basis.from_axis_angle(Vector3::UP, Math::PI / 4.0)
      n3d.basis = b
      n3d.basis.should eq(b)
    end

    it "supports CharacterBody3D kinematic properties" do
      cb = Godot::CharacterBody3D.new
      cb.velocity = Vector3.new(10.0, -9.8, 5.0)
      cb.velocity.should eq(Vector3.new(10.0_f32, -9.8_f32, 5.0_f32))

      cb.up_direction = Vector3.new(0.0, 1.0, 0.0)
      cb.up_direction.should eq(Vector3::UP)

      cb.floor_normal.should eq(Vector3::UP)
      cb.max_slides = 6_i64
      cb.max_slides.should eq(6_i64)

      cb.floor_snap_length = 0.2
      cb.floor_snap_length.should eq(0.2)

      cb.floor_max_angle = 1.0
      cb.floor_max_angle.should eq(1.0)

      cb.floor_stop_on_slope = false
      cb.floor_stop_on_slope.should be_false

      cb.floor_constant_speed = true
      cb.floor_constant_speed.should be_true

      cb.on_floor?.should be_false
      cb.on_wall?.should be_false
      cb.on_ceiling?.should be_false
      cb.move_and_slide.should be_false
    end

    it "supports Node2D and CharacterBody2D properties" do
      n2d = Godot::Node2D.new
      n2d.position = Vector2.new(100.0, 200.0)
      n2d.position.should eq(Vector2.new(100.0_f32, 200.0_f32))

      n2d.global_position = Vector2.new(500.0, 600.0)
      n2d.global_position.should eq(Vector2.new(500.0_f32, 600.0_f32))

      n2d.rotation_degrees = 90.0_f32
      n2d.rotation_degrees.should eq(90.0_f32)

      n2d.global_rotation_degrees = 180.0_f32
      n2d.global_rotation_degrees.should eq(180.0_f32)

      n2d.scale = Vector2.new(2.0, 3.0)
      n2d.scale.should eq(Vector2.new(2.0_f32, 3.0_f32))

      n2d.global_scale = Vector2.new(4.0, 5.0)
      n2d.global_scale.should eq(Vector2.new(4.0_f32, 5.0_f32))

      n2d.skew = 0.1_f32
      n2d.skew.should eq(0.1_f32)

      t2d = Transform2D.new(Vector2.new(1.0, 0.0), Vector2.new(0.0, 1.0), Vector2.new(50.0, 50.0))
      n2d.transform = t2d
      n2d.transform.origin.should eq(Vector2.new(50.0_f32, 50.0_f32))

      cb2d = Godot::CharacterBody2D.new
      cb2d.velocity = Vector2.new(15.0, -30.0)
      cb2d.velocity.should eq(Vector2.new(15.0_f32, -30.0_f32))
      cb2d.up_direction = Vector2.new(0.0, -1.0)
      cb2d.up_direction.should eq(Vector2::UP)
      cb2d.floor_normal.should eq(Vector2::UP)
      cb2d.on_floor?.should be_false
    end

    it "supports Camera3D, RayCast3D, CollisionShape3D, and Control properties" do
      cam = Godot::Camera3D.new
      cam.fov = 90.0
      cam.fov.should eq(90.0)
      cam.near = 0.1
      cam.near.should eq(0.1)
      cam.far = 2000.0
      cam.far.should eq(2000.0)
      cam.current = true
      cam.current?.should be_true

      ray = Godot::RayCast3D.new
      ray.target_position = Vector3.new(0.0, -5.0, 0.0)
      ray.target_position.should eq(Vector3.new(0.0_f32, -5.0_f32, 0.0_f32))
      ray.enabled = false
      ray.enabled?.should be_false
      ray.colliding?.should be_false

      col = Godot::CollisionShape3D.new
      col.disabled = true
      col.disabled?.should be_true

      ctrl = Godot::Control.new
      ctrl.size = Vector2.new(300.0, 200.0)
      ctrl.size.should eq(Vector2.new(300.0_f32, 200.0_f32))
      ctrl.position = Vector2.new(50.0, 25.0)
      ctrl.position.should eq(Vector2.new(50.0_f32, 25.0_f32))
      ctrl.visible = false
      ctrl.visible?.should be_false
    end
  end
end
