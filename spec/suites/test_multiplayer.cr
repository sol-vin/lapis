# =============================================================================
# LibGodot Test Suite: Multiplayer, RPCs, Spawners & Multi-Client Harness
# =============================================================================
#
# Exhaustive verification of:
# - ENetMultiplayerPeer lifecycle, compression, and socket binding
# - MultiplayerAPI default interface creation, peer binding, and signals
# - Node multiplayer authority management and tree inheritance
# - @[RPC] declarative reflection, ClassRegistry metadata, and local calls
# - MultiplayerSpawner scene registration and limits
# - MultiplayerSynchronizer & SceneReplicationConfig property synchronization
# - Multi-client input pumping and frame stepping via Lapis::Multiplayer::Harness
# - Wireshark-style Spy packet auditing and bandwidth verification
# - Quantitative zero-leak verification across multiplayer allocations
# =============================================================================

require "../fixtures/test_target_nodes"

include Lapis::Test

# Networked node fixture exercising @[RPC] modes and replication
node SpecMultiplayerHero < Godot::Node do
  property health : Int32 = 100
  property sync_counter : Int32 = 0
  property chat_history : Array(String) = [] of String

  @[RPC(mode: :any_peer, sync: :call_local, transfer_mode: :reliable, channel: 0)]
  def apply_damage(amount : Int32) : Void
    @health -= amount
  end

  @[RPC(mode: :authority, sync: :call_local, transfer_mode: :unreliable_ordered, channel: 1)]
  def sync_counter_step(step : Int32) : Void
    @sync_counter += step
  end

  @[RPC(mode: :any_peer, sync: :call_local, transfer_mode: :reliable, channel: 0)]
  def broadcast_message(text : String) : Void
    @chat_history << text
  end
end

test_suite "Multiplayer" do
  test "ENetMultiplayerPeer lifecycle, compression modes and server creation" do
    peer = Godot.create(Godot::ENetMultiplayerPeer)
    assert_not_nil peer

    # 1. Bind server on local ephemeral port
    err = peer.create_server(18910, 4)
    assert_eq err.to_i64, Godot::Error::Ok.to_i64, "create_server on port 18910 must succeed"

    # Server must have connection status CONNECTED and unique ID 1
    assert_eq peer.get_connection_status.to_i64, Godot::MultiplayerPeer::ConnectionStatus::ConnectionConnected.to_i64
    assert_eq peer.get_unique_id, 1_i64, "Server unique ID must always be 1"

    # 2. Verify compression modes via ENetConnection host
    host = peer.get_host
    assert_not_nil host
    host.compress(Godot::ENetConnection::CompressionMode::CompressRangeCoder)
    host.compress(Godot::ENetConnection::CompressionMode::CompressFastlz)

    # Poll peer without error
    peer.poll

    # 3. Clean close
    peer.close
    assert_eq peer.get_connection_status.to_i64, Godot::MultiplayerPeer::ConnectionStatus::ConnectionDisconnected.to_i64
    peer.destroy
  end

  test "MultiplayerAPI interface creation, peer binding, and signals" do
    mp = Godot::MultiplayerAPI.create_default_interface
    assert_not_nil mp

    # Create server peer and assign
    peer = Godot.create(Godot::ENetMultiplayerPeer)
    err = peer.create_server(18911, 2)
    assert_eq err.to_i64, Godot::Error::Ok.to_i64

    mp.set_multiplayer_peer(peer)
    assert_true mp.has_multiplayer_peer?, "MultiplayerAPI must report has_multiplayer_peer? true after assignment"
    assert_true mp.is_server?, "MultiplayerAPI must report is_server? true when server peer is bound"
    assert_eq mp.get_unique_id, 1_i64

    # Advance network poll
    poll_err = mp.poll
    assert_eq poll_err.to_i64, Godot::Error::Ok.to_i64

    # Clean teardown
    peer.close
    peer.destroy
  end

  test "Node multiplayer authority management and tree inheritance" do
    parent = Godot.create(Godot::Node)
    child = Godot.create(Godot::Node)
    parent.add_child(child)

    # Default authority is Server (1)
    assert_eq parent.get_multiplayer_authority, 1_i64
    assert_eq child.get_multiplayer_authority, 1_i64

    # Set authority on parent recursively
    parent.set_multiplayer_authority(1007, recursive: true)
    assert_eq parent.get_multiplayer_authority, 1007_i64
    assert_eq child.get_multiplayer_authority, 1007_i64, "Child authority must inherit parent authority when recursive is true"

    # Clean cleanup
    parent.destroy
  end

  test "@[RPC] declarative reflection and ClassRegistry metadata" do
    reg = Godot::ClassRegistry.find("SpecMultiplayerHero")
    assert_not_nil reg, "SpecMultiplayerHero must be registered in ClassRegistry"

    entry = reg.not_nil!
    rpc_methods = entry.rpc_methods
    assert_true rpc_methods.size >= 3, "SpecMultiplayerHero must register at least 3 RPC methods"

    # 1. Verify apply_damage RPC configuration: any_peer, reliable, call_local, ch 0
    dmg_rpc = rpc_methods.find { |m| m[:name] == "apply_damage" }
    assert_not_nil dmg_rpc
    assert_eq dmg_rpc.not_nil![:rpc_mode], 1       # any_peer
    assert_eq dmg_rpc.not_nil![:transfer_mode], 2   # reliable
    assert_true dmg_rpc.not_nil![:call_local]
    assert_eq dmg_rpc.not_nil![:channel], 0

    # 2. Verify sync_counter_step RPC configuration: authority, unreliable_ordered, call_local, ch 1
    sync_rpc = rpc_methods.find { |m| m[:name] == "sync_counter_step" }
    assert_not_nil sync_rpc
    assert_eq sync_rpc.not_nil![:rpc_mode], 2       # authority
    assert_eq sync_rpc.not_nil![:transfer_mode], 1   # unreliable_ordered
    assert_true sync_rpc.not_nil![:call_local]
    assert_eq sync_rpc.not_nil![:channel], 1

    # 3. Test direct local execution and rpc dispatch on instance
    hero = Godot.create(SpecMultiplayerHero)
    assert_eq hero.health, 100

    hero.apply_damage(20)
    assert_eq hero.health, 80

    # Mount in scene tree to activate RPC configurations and test dispatch
    root.add_child(hero)
    hero.apply_damage(15)
    assert_eq hero.health, 65

    root.remove_child(hero)
    hero.destroy
  end

  test "MultiplayerSpawner configuration and limits" do
    spawner = Godot.create(Godot::MultiplayerSpawner)

    spawner.set_spawn_path("..")
    assert_eq spawner.get_spawn_path.to_s, ".."

    spawner.add_spawnable_scene("res://scenes/player.tscn")
    assert_eq spawner.get_spawnable_scene_count, 1_i64
    assert_eq spawner.get_spawnable_scene(0), "res://scenes/player.tscn"

    spawner.set_spawn_limit(16)
    assert_eq spawner.get_spawn_limit, 16_i64

    spawner.clear_spawnable_scenes
    assert_eq spawner.get_spawnable_scene_count, 0_i64

    spawner.destroy
  end

  test "MultiplayerSynchronizer and SceneReplicationConfig property DSL" do
    sync = Godot.create(Godot::MultiplayerSynchronizer)

    sync.set_root_path("..")
    assert_eq sync.get_root_path.to_s, ".."

    sync.set_replication_interval(0.05)
    assert_in_delta sync.get_replication_interval, 0.05, 0.001

    sync.set_delta_interval(0.02)
    assert_in_delta sync.get_delta_interval, 0.02, 0.001

    # Test SceneReplicationConfig
    config = Godot.create(Godot::SceneReplicationConfig)
    config.add_property(".:position")
    assert_true config.has_property(".:position")

    # Test clean DSL watch method
    config.watch(:rotation)
    assert_true config.has_property(".:rotation"), "config.watch(:rotation) must automatically format as '.:rotation'"

    config.remove_property(".:position")
    assert_false config.has_property(".:position")

    sync.set_replication_config(config)
    sync.destroy
  end

  multiplayer_test "Multi-client input pumping and lockstep frame stepping", clients: 2 do |harness|
    assert_eq harness.server.peer_id, 1
    assert_eq harness.client(1).peer_id, 2
    assert_eq harness.client(2).peer_id, 3

    # Spawn hero on server
    server_hero = harness.server.spawn(SpecMultiplayerHero, name: "Hero")
    assert_not_nil server_hero

    # Step frame ticks to pump network and lifecycle
    harness.step_frames(3)

    # Client 1 pumps input action with Symbol
    harness.client(1).send_action(:attack, pressed: true)

    # Client 1 issues RPC to server with Symbol
    harness.client(1).rpc_id(1, :apply_damage, 35)

    # Advance network pump across all peers
    harness.step_frames(3)

    # Verify server state was updated
    assert_eq server_hero.health, 65
  end

  multiplayer_test "Wireshark-style Spy packet auditing and bandwidth verification", clients: 2 do |harness|
    spy = harness.spy
    spy.clear

    # Configure simulated latency
    spy.latency_ms = 10.0

    # Issue multiple RPC transmissions using both Symbols and Strings
    harness.client(1).rpc_id(1, :apply_damage, 10)
    harness.client(2).rpc_id(1, "broadcast_message", "Hello Network")
    harness.server.rpc(:sync_counter_step, 1)

    harness.step_frames(2)

    # Wireshark Spy Assertions verifying both Symbol and String matching
    assert_true spy.packets.size >= 3, "Spy must record all 3 packet transmissions"
    spy.assert_rpc_sent(from: 2, to: 1, method: :apply_damage)
    spy.assert_rpc_sent(from: 2, to: 1, method: "apply_damage")
    spy.assert_rpc_sent(from: 3, to: 1, method: :broadcast_message)
    spy.assert_rpc_sent(from: 1, to: 0, method: :sync_counter_step)

    # Filter reliable packets
    reliable = spy.filter(&.reliable?)
    assert_true reliable.size >= 2

    # Bandwidth threshold
    spy.assert_max_bandwidth(10240.0) # < 10 MB/s

    # Radare2 debug pipeline verification
    spy.enable_r2_pipeline!
    assert_true spy.r2_pipeline_enabled?

    # Capture simulated anomaly
    report = spy.capture_r2_forensics!("Test Anomaly at RPC frame", 0x140001000_u64)
    assert_not_nil report
    assert_eq spy.forensics_snapshots.size, 1
    spy.disable_r2_pipeline!
    assert_false spy.r2_pipeline_enabled?
  end

  test "assert_no_leak verifies zero object or memory leak across multiplayer node allocations" do
    assert_no_leak(max_delta_objects: 0, name: "MultiplayerNodeAlloc") do
      20.times do |i|
        spawner = Godot.create(Godot::MultiplayerSpawner)
        spawner.name = "Spawner_#{i}"
        spawner.set_spawn_path("..")
        spawner.destroy

        sync = Godot.create(Godot::MultiplayerSynchronizer)
        sync.name = "Sync_#{i}"
        sync.destroy

        hero = Godot.create(SpecMultiplayerHero)
        hero.name = "Hero_#{i}"
        hero.destroy
      end
    end
  end
end
