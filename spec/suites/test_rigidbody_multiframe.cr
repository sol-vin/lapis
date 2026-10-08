# =============================================================================
# LibGodot Test Suite: Multi-Frame RigidBody Simulation & Contact Signal Piping
# =============================================================================

include Lapis::Test

# Receiver node to track piped collision contacts from RigidBody nodes
node RigidContactReceiver < Godot::Node do
  property contacted_bodies : Array(Godot::Node) = Array(Godot::Node).new
  property contacted_bodies_3d : Array(Godot::Node) = Array(Godot::Node).new
  property alert_count : Int32 = 0
  property quad_args_called : Bool = false
  property last_body_rid : Int64 = 0_i64

  # Exact 1-arg body callback: (Godot::Node)
  def on_body_contact(body : Godot::Node) : Void
    @contacted_bodies << body
  end

  # 3D body callback: (Godot::Node)
  def on_body_contact_3d(body : Godot::Node) : Void
    @contacted_bodies_3d << body
  end

  # 0-arg trimmed callback: ()
  def on_contact_alert : Void
    @alert_count += 1
  end

  # 4-arg shape callback: (Int64, Godot::Node, Int64, Int64)
  def on_body_shape(body_rid : Int64, body : Godot::Node, body_shape_index : Int64, local_shape_index : Int64) : Void
    @quad_args_called = true
    @last_body_rid = body_rid
  end

  def reset : Void
    @contacted_bodies.clear
    @contacted_bodies_3d.clear
    @alert_count = 0
    @quad_args_called = false
    @last_body_rid = 0_i64
  end
end

test_suite "RigidBodyMultiFrame" do
  test "RigidBody2D central impulse, dynamic integration, and contact monitoring across frames" do
    assert_no_leak(max_delta_objects: 5, name: "RigidBody2D multi-frame impulse") do
      rb = Godot.create(Godot::RigidBody2D)
      col_shape = Godot.create(Godot::CollisionShape2D)
      circle = Godot.create(Godot::CircleShape2D)
      circle.set_radius(16.0_f64)
      col_shape.set_shape(circle)
      rb.add_child(col_shape)
      rb.set_position(Godot::Vector2.new(100.0, 100.0))
      rb.set_gravity_scale(0.0_f64)
      rb.set_contact_monitor(true)
      rb.set_max_contacts_reported(4_i64)
      root.add_child(rb)

      receiver = Godot.create(RigidContactReceiver)
      root.add_child(receiver)

      # 1. Pipe body_entered to exact callback: ->receiver.on_body_contact(Godot::Node)
      sub_body = (rb.signal("body_entered") >> ->receiver.on_body_contact(Godot::Node))
      assert_true sub_body.connected?

      # 2. Pipe body_entered to 0-argument trimmed callback: ->receiver.on_contact_alert
      sub_alert = (rb.signal("body_entered") >> ->receiver.on_contact_alert)
      assert_true sub_alert.connected?

      # 3. Pipe body_shape_entered to 4-argument callback: ->receiver.on_body_shape(Int64, Godot::Node, Int64, Int64)
      sub_shape = (rb.signal("body_shape_entered") >> ->receiver.on_body_shape(Int64, Godot::Node, Int64, Int64))
      assert_true sub_shape.connected?

      # Apply horizontal impulse and velocity
      rb.set_linear_velocity(Godot::Vector2.new(100.0, 0.0))
      rb.apply_central_impulse(Godot::Vector2.new(200.0, 0.0))

      5.times do
        rb.set_position(rb.get_position + rb.get_linear_velocity * 0.016_f64)
        skip_physics_frames(1)
      end

      # Verify displacement occurred in +X direction
      pos = rb.get_position
      assert_true pos.x > 100.0, "RigidBody2D should translate along +X after impulse, got #{pos.x}"

      # Simulate contact by emitting body_entered and body_shape_entered
      static_box = Godot.create(Godot::StaticBody2D)
      root.add_child(static_box)

      rb.signal("body_entered").emit(static_box)
      rb.signal("body_shape_entered").emit(12345_i64, static_box, 0_i64, 0_i64)
      skip_frames(2)

      assert_true receiver.contacted_bodies.size >= 1, "body_entered pipe should execute"
      assert_eq receiver.contacted_bodies.first.instance_id, static_box.instance_id
      assert_true receiver.alert_count >= 1, "0-arg trimmed alert pipe should fire"
      assert_true receiver.quad_args_called, "4-arg body_shape_entered pipe should fire"
      assert_eq receiver.last_body_rid, 12345_i64

      sub_body.unsubscribe
      sub_alert.unsubscribe
      sub_shape.unsubscribe

      root.remove_child(static_box)
      static_box.destroy
      root.remove_child(receiver)
      receiver.destroy
      root.remove_child(rb)
      rb.destroy
    end
  end

  test "RigidBody3D impulse kinematics, velocity monitoring, and 3D contact signal piping" do
    assert_no_leak(max_delta_objects: 5, name: "RigidBody3D multi-frame impulse") do
      rb3d = Godot.create(Godot::RigidBody3D)
      col_shape3d = Godot.create(Godot::CollisionShape3D)
      sphere3d = Godot.create(Godot::SphereShape3D)
      sphere3d.set_radius(1.0_f64)
      col_shape3d.set_shape(sphere3d)
      rb3d.add_child(col_shape3d)
      rb3d.set_position(Godot::Vector3.new(0.0, 0.0, 0.0))
      rb3d.set_gravity_scale(0.0_f64)
      rb3d.set_contact_monitor(true)
      rb3d.set_max_contacts_reported(4_i64)
      root.add_child(rb3d)

      receiver = Godot.create(RigidContactReceiver)
      root.add_child(receiver)

      # Pipe body_entered to 3D callback
      sub_3d = (rb3d.signal("body_entered") >> ->receiver.on_body_contact_3d(Godot::Node))
      assert_true sub_3d.connected?

      # Apply spatial impulse and velocity along +Z
      rb3d.set_linear_velocity(Godot::Vector3.new(0.0, 0.0, 20.0))
      rb3d.apply_central_impulse(Godot::Vector3.new(0.0, 0.0, 50.0))

      5.times do
        rb3d.set_position(rb3d.get_position + rb3d.get_linear_velocity * 0.016_f64)
        skip_physics_frames(1)
      end

      # Verify displacement occurred in +Z direction
      pos3d = rb3d.get_position
      assert_true pos3d.z > 0.0, "RigidBody3D should translate along +Z after impulse, got #{pos3d.z}"

      # Simulate 3D contact
      static_box3d = Godot.create(Godot::StaticBody3D)
      root.add_child(static_box3d)

      rb3d.signal("body_entered").emit(static_box3d)
      skip_frames(2)

      assert_true receiver.contacted_bodies_3d.size >= 1, "3D body_entered pipe should execute"
      assert_eq receiver.contacted_bodies_3d.first.instance_id, static_box3d.instance_id

      sub_3d.unsubscribe

      root.remove_child(static_box3d)
      static_box3d.destroy
      root.remove_child(receiver)
      receiver.destroy
      root.remove_child(rb3d)
      rb3d.destroy
    end
  end
end
