# =============================================================================
# LibGodot Test Suite: Multi-Frame Physics & >> Signal Piping to Class Methods
# =============================================================================

include Lapis::Test

# Probe character body node representing a 2D gameplay entity
node SpecPlayerNode2D < Godot::CharacterBody2D do
  @[Export]
  property player_tag : String = "HeroPlayer2D"

  @[Export]
  property health : Int32 = 100
end

# Probe character body node representing a 3D gameplay entity
node SpecPlayerNode3D < Godot::CharacterBody3D do
  @[Export]
  property player_tag : String = "HeroPlayer3D"
end

# Target listener node tracking piped signal callbacks from Area2D / Area3D
node AreaCollisionReceiver < Godot::Node do
  property entered_bodies : Array(Godot::Node2D) = Array(Godot::Node2D).new
  property typed_players : Array(SpecPlayerNode2D) = Array(SpecPlayerNode2D).new
  property alert_count : Int32 = 0
  property exited_bodies : Array(Godot::Node2D) = Array(Godot::Node2D).new

  property entered_bodies_3d : Array(Godot::Node3D) = Array(Godot::Node3D).new
  property typed_players_3d : Array(SpecPlayerNode3D) = Array(SpecPlayerNode3D).new

  # Exact typed callback: (Godot::Node2D)
  def on_body_entered(body : Godot::Node2D) : Void
    @entered_bodies << body
  end

  # Polymorphically downcasted callback: (SpecPlayerNode2D)
  def on_player_entered(player : SpecPlayerNode2D) : Void
    @typed_players << player
  end

  # 0-argument trimmed callback: ()
  def on_zone_alert : Void
    @alert_count += 1
  end

  # Exit callback: (Godot::Node2D)
  def on_body_exited(body : Godot::Node2D) : Void
    @exited_bodies << body
  end

  # 3D exact callback: (Godot::Node3D)
  def on_body_entered_3d(body : Godot::Node3D) : Void
    @entered_bodies_3d << body
  end

  # 3D downcasted callback: (SpecPlayerNode3D)
  def on_player_entered_3d(player : SpecPlayerNode3D) : Void
    @typed_players_3d << player
  end

  property quad_shape_calls : Int32 = 0
  property last_body_rid : Int64 = 0_i64

  # 4-argument callback for body_shape_entered: (Int64, Godot::Node2D, Int64, Int64)
  def on_body_shape_entered(body_rid : Int64, body : Godot::Node2D, body_shape_index : Int64, local_shape_index : Int64) : Void
    @quad_shape_calls += 1
    @last_body_rid = body_rid
  end

  def reset : Void
    @entered_bodies.clear
    @typed_players.clear
    @alert_count = 0
    @exited_bodies.clear
    @entered_bodies_3d.clear
    @typed_players_3d.clear
  end
end

# Intermediate signal forwarding hub node
node ZoneHubNode < Godot::Node do
  signal forwarded_body_entered(body : Godot::Node2D)
  signal forwarded_alert
end

test_suite "SignalPiping" do
  test "Area2D body_entered piped to class method with >> during multi-frame physics simulation" do
    assert_no_leak(max_delta_objects: 5, name: "Area2D body_entered >> method") do
      # 1. Create Area2D trigger zone
      area = Godot.create(Godot::Area2D)
      area_shape = Godot.create(Godot::CollisionShape2D)
      box = Godot.create(Godot::RectangleShape2D)
      box.set_size(Godot::Vector2.new(120.0, 120.0))
      area_shape.set_shape(box)
      area.add_child(area_shape)
      area.set_position(Godot::Vector2.new(200.0, 200.0))
      area.set_monitoring(true)
      area.set_monitorable(true)
      root.add_child(area)

      # 2. Create receiver node
      receiver = Godot.create(AreaCollisionReceiver)
      root.add_child(receiver)

      # 3. Connect body_entered using >> to class-specific methods:
      # a) exact method pointer: ->receiver.on_body_entered(Godot::Node2D)
      sub_exact = (area.body_entered >> ->receiver.on_body_entered(Godot::Node2D))
      assert_true sub_exact.connected?

      # b) downcasted method pointer: ->receiver.on_player_entered(SpecPlayerNode2D)
      sub_downcast = (area.body_entered >> ->receiver.on_player_entered(SpecPlayerNode2D))
      assert_true sub_downcast.connected?

      # c) 0-argument trimmed method pointer: ->receiver.on_zone_alert
      sub_alert = (area.body_entered >> ->receiver.on_zone_alert)
      assert_true sub_alert.connected?

      # d) exit method pointer: ->receiver.on_body_exited(Godot::Node2D)
      sub_exit = (area.body_exited >> ->receiver.on_body_exited(Godot::Node2D))
      assert_true sub_exit.connected?

      # 4. Spawn Player node inside the scene tree outside the area
      player = Godot.create(SpecPlayerNode2D)
      p_shape = Godot.create(Godot::CollisionShape2D)
      circle = Godot.create(Godot::CircleShape2D)
      circle.set_radius(16.0_f64)
      p_shape.set_shape(circle)
      player.add_child(p_shape)
      player.set_position(Godot::Vector2.new(50.0, 200.0))
      root.add_child(player)

      # Initial state before stepping
      assert_eq receiver.entered_bodies.size, 0
      assert_eq receiver.typed_players.size, 0
      assert_eq receiver.alert_count, 0

      # 5. Move player into the area and advance physics simulation
      player.set_position(Godot::Vector2.new(200.0, 200.0))
      area.body_entered.emit(player)
      skip_frames(2)

      # 6. Verify all piped callbacks were executed with exact references
      assert_true receiver.entered_bodies.size >= 1, "Expected on_body_entered to fire via >> pipe"
      assert_eq receiver.entered_bodies.first.instance_id, player.instance_id

      assert_true receiver.typed_players.size >= 1, "Expected downcasted on_player_entered to fire via >> pipe"
      assert_eq receiver.typed_players.first.instance_id, player.instance_id

      assert_true receiver.alert_count >= 1, "Expected 0-arg on_zone_alert to fire via >> pipe"

      # 7. Move player out of the area and verify body_exited pipe
      player.set_position(Godot::Vector2.new(500.0, 200.0))
      area.body_exited.emit(player)
      skip_frames(2)

      assert_true receiver.exited_bodies.size >= 1, "Expected on_body_exited to fire via >> pipe"
      assert_eq receiver.exited_bodies.first.instance_id, player.instance_id

      # 8. Unsubscribe and cleanup
      sub_exact.unsubscribe
      sub_downcast.unsubscribe
      sub_alert.unsubscribe
      sub_exit.unsubscribe

      root.remove_child(player)
      player.destroy

      root.remove_child(receiver)
      receiver.destroy

      root.remove_child(area)
      area.destroy
    end
  end

  test "Area2D body_entered piped to target node TypedSignal via >> operator" do
    assert_no_leak(max_delta_objects: 5, name: "Area2D body_entered >> signal") do
      area = Godot.create(Godot::Area2D)
      area_shape = Godot.create(Godot::CollisionShape2D)
      box = Godot.create(Godot::RectangleShape2D)
      box.set_size(Godot::Vector2.new(100.0, 100.0))
      area_shape.set_shape(box)
      area.add_child(area_shape)
      area.set_position(Godot::Vector2.new(150.0, 150.0))
      area.set_monitoring(true)
      root.add_child(area)

      hub = Godot.create(ZoneHubNode)
      root.add_child(hub)

      hub_events = Array(Godot::Node2D).new
      hub_alerts = 0

      hub.forwarded_body_entered += ->(body : Godot::Node2D) { hub_events << body }
      hub.forwarded_alert += ->{ hub_alerts += 1 }

      # Pipe signal to signal: area.body_entered >> hub.forwarded_body_entered
      sub_sig = (area.body_entered >> hub.forwarded_body_entered)
      assert_true sub_sig.connected?

      # Pipe signal to 0-argument signal: area.body_entered >> hub.forwarded_alert
      sub_sig_alert = (area.body_entered >> hub.forwarded_alert)
      assert_true sub_sig_alert.connected?

      body = Godot.create(Godot::CharacterBody2D)
      b_shape = Godot.create(Godot::CollisionShape2D)
      circle = Godot.create(Godot::CircleShape2D)
      circle.set_radius(10.0_f64)
      b_shape.set_shape(circle)
      body.add_child(b_shape)
      body.set_position(Godot::Vector2.new(150.0, 150.0))
      root.add_child(body)

      area.body_entered.emit(body)
      skip_frames(2)

      assert_true hub_events.size >= 1, "Expected forwarded signal on hub to receive body"
      assert_eq hub_events.first.instance_id, body.instance_id
      assert_true hub_alerts >= 1, "Expected forwarded alert signal to fire with arity trimming"

      sub_sig.unsubscribe
      sub_sig_alert.unsubscribe

      root.remove_child(body)
      body.destroy
      root.remove_child(hub)
      hub.destroy
      root.remove_child(area)
      area.destroy
    end
  end

  test "Area3D body_entered piped to class method with >> during 3D physics multi-frame stepping" do
    assert_no_leak(max_delta_objects: 5, name: "Area3D body_entered >> method") do
      area3d = Godot.create(Godot::Area3D)
      area3d_shape = Godot.create(Godot::CollisionShape3D)
      box3d = Godot.create(Godot::BoxShape3D)
      box3d.set_size(Godot::Vector3.new(4.0, 4.0, 4.0))
      area3d_shape.set_shape(box3d)
      area3d.add_child(area3d_shape)
      area3d.set_position(Godot::Vector3.new(0.0, 0.0, 0.0))
      area3d.set_monitoring(true)
      area3d.set_monitorable(true)
      root.add_child(area3d)

      receiver = Godot.create(AreaCollisionReceiver)
      root.add_child(receiver)

      # Pipe Area3D body_entered >> ->receiver.on_body_entered_3d(Godot::Node3D)
      sub_3d = (area3d.body_entered >> ->receiver.on_body_entered_3d(Godot::Node3D))
      assert_true sub_3d.connected?

      # Pipe Area3D body_entered >> ->receiver.on_player_entered_3d(SpecPlayerNode3D)
      sub_3d_typed = (area3d.body_entered >> ->receiver.on_player_entered_3d(SpecPlayerNode3D))
      assert_true sub_3d_typed.connected?

      # Spawn 3D player inside area
      player3d = Godot.create(SpecPlayerNode3D)
      p3d_shape = Godot.create(Godot::CollisionShape3D)
      sphere = Godot.create(Godot::SphereShape3D)
      sphere.set_radius(1.0_f64)
      p3d_shape.set_shape(sphere)
      player3d.add_child(p3d_shape)
      player3d.set_position(Godot::Vector3.new(0.0, 0.0, 0.0))
      root.add_child(player3d)

      area3d.body_entered.emit(player3d)
      skip_frames(2)

      assert_true receiver.entered_bodies_3d.size >= 1, "Expected 3D body entered to invoke callback"
      assert_eq receiver.entered_bodies_3d.first.instance_id, player3d.instance_id

      assert_true receiver.typed_players_3d.size >= 1, "Expected 3D typed downcasted entry to invoke callback"
      assert_eq receiver.typed_players_3d.first.instance_id, player3d.instance_id

      sub_3d.unsubscribe
      sub_3d_typed.unsubscribe

      root.remove_child(player3d)
      player3d.destroy
      root.remove_child(receiver)
      receiver.destroy
      root.remove_child(area3d)
      area3d.destroy
    end
  end

  test "Dynamic BoundSignal body_entered piping to Proc via >>" do
    assert_no_leak(max_delta_objects: 5, name: "Dynamic BoundSignal >> Proc") do
      area = Godot.create(Godot::Area2D)
      shape = Godot.create(Godot::CollisionShape2D)
      rect = Godot.create(Godot::RectangleShape2D)
      rect.set_size(Godot::Vector2.new(80.0, 80.0))
      shape.set_shape(rect)
      area.add_child(shape)
      area.set_position(Godot::Vector2.new(100.0, 100.0))
      area.set_monitoring(true)
      root.add_child(area)

      receiver = Godot.create(AreaCollisionReceiver)
      root.add_child(receiver)

      # Obtain dynamic BoundSignal: area.signal("body_entered")
      dyn_sig = area.signal("body_entered")
      sub = (dyn_sig >> ->receiver.on_body_entered(Godot::Node2D))
      assert_true sub.connected?

      body = Godot.create(Godot::CharacterBody2D)
      b_shape = Godot.create(Godot::CollisionShape2D)
      circle = Godot.create(Godot::CircleShape2D)
      circle.set_radius(8.0_f64)
      b_shape.set_shape(circle)
      body.add_child(b_shape)
      body.set_position(Godot::Vector2.new(100.0, 100.0))
      root.add_child(body)

      dyn_sig.emit(body)
      skip_frames(2)

      assert_true receiver.entered_bodies.size >= 1, "Dynamic BoundSignal pipe must forward body_entered"
      assert_eq receiver.entered_bodies.first.instance_id, body.instance_id

      sub.unsubscribe
      root.remove_child(body)
      body.destroy
      root.remove_child(receiver)
      receiver.destroy
      root.remove_child(area)
      area.destroy
    end
  end

  test "Area2D body_shape_entered 4-argument signal piping via >> to class method and 0-argument trimming" do
    assert_no_leak(max_delta_objects: 5, name: "Area2D body_shape_entered >> 4-arg & 0-arg") do
      area = Godot.create(Godot::Area2D)
      shape = Godot.create(Godot::CollisionShape2D)
      box = Godot.create(Godot::RectangleShape2D)
      box.set_size(Godot::Vector2.new(100.0, 100.0))
      shape.set_shape(box)
      area.add_child(shape)
      area.set_position(Godot::Vector2.new(200.0, 200.0))
      root.add_child(area)

      receiver = Godot.create(AreaCollisionReceiver)
      root.add_child(receiver)

      # 1. Pipe 4-argument signal to 4-argument class method: ->receiver.on_body_shape_entered(Int64, Godot::Node2D, Int64, Int64)
      sub_quad = (area.signal("body_shape_entered") >> ->receiver.on_body_shape_entered(Int64, Godot::Node2D, Int64, Int64))
      assert_true sub_quad.connected?

      # 2. Pipe 4-argument signal to 0-argument trimmed callback: ->receiver.on_zone_alert
      sub_trim = (area.signal("body_shape_entered") >> ->receiver.on_zone_alert)
      assert_true sub_trim.connected?

      player = Godot.create(Godot::CharacterBody2D)
      root.add_child(player)

      # Emit 4-argument body_shape_entered
      area.signal("body_shape_entered").emit(9999_i64, player, 0_i64, 0_i64)
      skip_frames(2)

      assert_true receiver.quad_shape_calls >= 1, "Expected 4-arg on_body_shape_entered to fire via >> pipe"
      assert_eq receiver.last_body_rid, 9999_i64
      assert_true receiver.alert_count >= 1, "Expected 0-arg on_zone_alert to fire via >> pipe from 4-arg signal"

      sub_quad.unsubscribe
      sub_trim.unsubscribe

      root.remove_child(player)
      player.destroy
      root.remove_child(receiver)
      receiver.destroy
      root.remove_child(area)
      area.destroy
    end
  end
end
