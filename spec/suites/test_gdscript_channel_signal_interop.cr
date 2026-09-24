# =============================================================================
# LibGodot Test Suite: GDScript <-> Crystal Channel & Signal Interoperability
# =============================================================================

# Dedicated Crystal node registering custom signals for GDScript interop verification
include Lapis::Test

node CrystalSignalEmitterNode < Godot::Node do
  signal crystal_event(msg : String)
  signal health_changed(current : Int32, max_val : Int32)
  signal data_transferred(text : String)

  property last_received_callback_msg : String = ""

  def trigger_event(msg : String) : Void
    emit_crystal_event(msg)
  end

  def trigger_health(curr : Int32, max_val : Int32) : Void
    emit_health_changed(curr, max_val)
  end

  def trigger_transfer(text : String) : Void
    emit_data_transferred(text)
  end
end

test_suite "GDScript" do
  test "Crystal signal emitted from Crystal is received by GDScript listener" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  assert_not_nil scene
  root = scene.not_nil!.instantiate
  assert_not_nil root

  emitter = Godot.create(CrystalSignalEmitterNode)
  emitter.name = "EmitterFromCrystal"
  root.add_child(emitter)

  connected = root.call_bool("connect_crystal_signals", emitter)
  assert_true connected, "GDScript connect_crystal_signals must return true"

  # Emit event from Crystal
  emitter.emit_crystal_event("HelloGDScriptFromCrystal")

  sig_name = root.call_str("get", "last_crystal_signal_name")
  sig_data = root.call_str("get", "last_crystal_signal_data")
  sig_count = root.call_i64("get", "signal_call_count")

  assert_eq sig_name, "crystal_event", "GDScript listener must record crystal_event"
  assert_eq sig_data, "HelloGDScriptFromCrystal", "GDScript listener must receive event payload"
  assert_eq sig_count, 1_i64, "Signal call count must be 1"

  # Emit multi-arg signal from Crystal
  emitter.emit_health_changed(75, 100)

  sig_name2 = root.call_str("get", "last_crystal_signal_name")
  sig_data2 = root.call_str("get", "last_crystal_signal_data")
  sig_count2 = root.call_i64("get", "signal_call_count")

  assert_eq sig_name2, "health_changed", "GDScript listener must record health_changed"
  assert_eq sig_data2, "75/100", "GDScript listener must format multi-arg health payload"
  assert_eq sig_count2, 2_i64, "Signal call count must be incremented to 2"

  root.remove_child(emitter)
  emitter.destroy
  root.destroy
  scene.destroy
end

  test "Crystal signal emitted from GDScript is received by Crystal listener" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.not_nil!.instantiate

  emitter = Godot.create(CrystalSignalEmitterNode)
  emitter.name = "EmitterForGDScript"
  root.add_child(emitter)

  received_payload = ""
  listener_called = false

  emitter.on_crystal_event do |msg|
    received_payload = msg
    listener_called = true
  end

  # GDScript emits signal on the Crystal node
  root.call("emit_crystal_node_signal", emitter, "crystal_event", "PayloadFromGDScript")

  assert_true listener_called, "Crystal on_crystal_event listener must be invoked"
  assert_eq received_payload, "PayloadFromGDScript", "Crystal listener must receive payload emitted by GDScript"

  root.remove_child(emitter)
  emitter.destroy
  root.destroy
  scene.destroy
end

  test "GodotChannel created in GDScript passed to Crystal: GDScript sends -> Crystal receives" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.not_nil!.instantiate

  # 1. GDScript creates channel via ClassDB.instantiate("GodotChannel")
  ch = root.call_obj_as(Godot::Channel, "create_channel", 16)
  assert_not_nil ch, "create_channel must return valid GodotChannel instance"

  actual_ch = ch.not_nil!
  assert_true actual_ch.empty?, "Newly created channel must be empty"

  # 2. GDScript sends data into the channel
  sent = root.call_bool("send_to_channel", actual_ch, "GDScriptMessage_Alfa")
  assert_true sent, "GDScript send_to_channel must return true"

  # 3. Crystal receives data from the channel
  received_item = actual_ch.try_receive
  assert_not_nil received_item, "Crystal try_receive must retrieve the enqueued item"
  assert_eq received_item.to_s, "GDScriptMessage_Alfa", "Received item content must match"
  assert_true actual_ch.empty?, "Channel must be empty after receiving item"

  actual_ch.destroy
  root.destroy
  scene.destroy
end

  test "GodotChannel created in Crystal passed to GDScript: Crystal sends -> GDScript receives" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.not_nil!.instantiate

  # 1. Crystal creates channel
  ch = Godot::Channel.new(16)
  assert_true ch.empty?

  # 2. Crystal sends data
  ch.send("CrystalMessage_Bravo")
  assert_eq ch.size, 1

  # 3. GDScript receives data from the channel
  received_str = root.call_str("receive_from_channel", ch)
  assert_eq received_str, "CrystalMessage_Bravo", "GDScript receive_from_channel must return Crystal's message"
  assert_true ch.empty?, "Channel must be empty after GDScript receives item"

  ch.destroy
  root.destroy
  scene.destroy
end

  test "Bidirectional multi-message Ping-Pong conversation over channels" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.not_nil!.instantiate

  ch_cr_to_gd = Godot::Channel.new(16)
  ch_gd_to_cr = root.call_obj_as(Godot::Channel, "create_channel", 16).not_nil!

  messages = ["Ping_1", "Ping_2", "Ping_3"]

  messages.each do |msg|
    # Crystal sends to GDScript
    ch_cr_to_gd.send(msg)

    # GDScript receives from ch_cr_to_gd
    received_in_gd = root.call_str("receive_from_channel", ch_cr_to_gd)
    assert_eq received_in_gd, msg

    # GDScript replies on ch_gd_to_cr
    reply_msg = "Pong_#{received_in_gd}"
    sent = root.call_bool("send_to_channel", ch_gd_to_cr, reply_msg)
    assert_true sent

    # Crystal receives from ch_gd_to_cr
    received_in_cr = ch_gd_to_cr.try_receive
    assert_not_nil received_in_cr
    assert_eq received_in_cr.to_s, reply_msg
  end

  assert_true ch_cr_to_gd.empty?
  assert_true ch_gd_to_cr.empty?

  ch_cr_to_gd.destroy
  ch_gd_to_cr.destroy
  root.destroy
  scene.destroy
end

  test "Channel state inspection from GDScript (empty, full, size, close)" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.not_nil!.instantiate

  ch = Godot::Channel.new(2)

  # Initially empty
  is_empty = root.call_bool("is_channel_empty", ch)
  size0 = root.call_i64("get_channel_size", ch)
  assert_true is_empty, "Channel must initially be empty from GDScript"
  assert_eq size0, 0_i64, "Initial size must be 0"

  # Push 1 item
  ch.send("item1")
  assert_false root.call_bool("is_channel_empty", ch)
  assert_eq root.call_i64("get_channel_size", ch), 1_i64
  assert_false root.call_bool("is_channel_full", ch)

  # Push 2nd item (reaches capacity 2)
  ch.send("item2")
  assert_eq root.call_i64("get_channel_size", ch), 2_i64
  assert_true root.call_bool("is_channel_full", ch), "Channel must be full when size equals capacity"

  # Close channel from GDScript
  root.call("close_channel", ch)
  assert_true root.call_bool("is_channel_closed", ch), "Channel must report closed after close_channel"
  assert_true ch.closed?, "Crystal getter must also report closed"

  ch.destroy
  root.destroy
  scene.destroy
end

  test "GodotChannel received signal notifies GDScript reactive listener" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  root = scene.not_nil!.instantiate

  ch = Godot::Channel.new(16)

  # GDScript connects to ch.received
  connected = root.call_bool("connect_channel_received", ch)
  assert_true connected, "Connecting GDScript listener to channel received signal must succeed"

  # Crystal sends into channel (dispatches received signal via call_deferred)
  ch.send("ReactivePayload")

  # Allow deferred signal to flush
  5.times { Fiber.yield }

  last_val = root.call_str("get", "last_channel_received_val")
  received_count = root.call_i64("get", "channel_received_count")

  assert_eq last_val, "ReactivePayload", "GDScript channel listener must receive value"
  assert_true received_count >= 1_i64, "Received count must be at least 1"

  ch.destroy
  root.destroy
  scene.destroy
end

  test "Auto-generated typed GDScript binding InteropController methods and properties" do
  scene = Godot.load_as(Godot::PackedScene, "res://scenes/test_gdscript_interop.tscn")
  assert_not_nil scene
  root = scene.not_nil!.instantiate
  assert_not_nil root

  controller = Godot::InteropController.from(root)
  assert_not_nil controller

  # Strongly typed method calls without manual call_i64 / call_str
  sum = controller.add_numbers(123_i64, 456_i64)
  assert_eq sum, 579_i64, "controller.add_numbers must return 579"

  greeting = controller.format_greeting("Antigravity")
  assert_eq greeting, "Hello from GDScript, Antigravity!", "controller.format_greeting must return formatted string"

  dist = controller.compute_distance(Godot::Vector2.new(0.0, 0.0), Godot::Vector2.new(3.0, 4.0))
  assert_approx_eq dist, 5.0, 0.001, "controller.compute_distance must return approx 5.0"

  # Strongly typed properties
  controller.counter = 77_i64
  assert_eq controller.counter, 77_i64, "controller.counter getter must reflect setter value"

  incremented = controller.increment_counter(23_i64)
  assert_eq incremented, 100_i64, "controller.increment_counter must return 100"
  assert_eq controller.counter, 100_i64, "controller.counter must now be 100"

  # Strongly typed signal helper
  assert_not_nil controller.gd_ping, "controller.gd_ping bound signal must be present"
  assert_not_nil controller.gd_pong, "controller.gd_pong bound signal must be present"

  root.destroy
  scene.destroy
end

end
