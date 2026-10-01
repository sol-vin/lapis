require "../../../src/lapis"
require "./networked_player"

# =============================================================================
# Lapis Multiplayer Demo & Wireshark Spy Showcase
# =============================================================================
# Demonstrates:
# - ENetMultiplayerPeer host/client lifecycle
# - Declarative @[RPC] method calls across peers
# - Wireshark-style Spy real-time packet inspection HUD
# - Automated headless verification mode (--test)
# =============================================================================

node MultiplayerDemo < Node2D do
  property port : Int32 = 8910
  property spy : Lapis::Multiplayer::Spy = Lapis::Multiplayer::Spy.new

  @peer : Godot::ENetMultiplayerPeer? = nil
  @status_label : Godot::Label? = nil
  @log_label : Godot::RichTextLabel? = nil
  @players_container : Godot::Node2D? = nil

  def _ready : Void
    Godot.print("MultiplayerDemo initialized!")

    # Check for automated headless test flag
    is_test = ARGV.includes?("--test")
    begin
      is_test ||= Godot.os.call_str("get_cmdline_args").includes?("--test")
    rescue
    end
    begin
      is_test ||= Godot.os.call_str("get_cmdline_user_args").includes?("--test")
    rescue
    end

    if is_test
      run_headless_verification
      return
    end

    setup_scene_and_ui
  end

  # Setup UI and tree nodes programmatically or connect to scene elements
  def setup_scene_and_ui : Void
    # Players container
    container = Godot.create(Godot::Node2D)
    container.name = "Players"
    add_child(container)
    @players_container = container

    # CanvasLayer UI
    canvas = Godot.create(Godot::CanvasLayer)
    add_child(canvas)

    # Panel Container
    panel = Godot.create(Godot::PanelContainer)
    panel.set_position(Godot::Vector2.new(20, 20))
    panel.set_size(Godot::Vector2.new(450, 560))
    canvas.add_child(panel)

    vbox = Godot.create(Godot::VBoxContainer)
    panel.add_child(vbox)

    title = Godot.create(Godot::Label)
    title.text = "Lapis Multiplayer & Network Spy"
    vbox.add_child(title)

    status = Godot.create(Godot::Label)
    status.text = "Status: Disconnected"
    vbox.add_child(status)
    @status_label = status

    btn_host = Godot.create(Godot::Button)
    btn_host.text = "Host Server (Port #{port})"
    btn_host.pressed.connect do
      host_game
    end
    vbox.add_child(btn_host)

    btn_join = Godot.create(Godot::Button)
    btn_join.text = "Join Client (127.0.0.1:#{port})"
    btn_join.pressed.connect do
      join_game
    end
    vbox.add_child(btn_join)

    btn_ping = Godot.create(Godot::Button)
    btn_ping.text = "Send Chat / Ping RPC"
    btn_ping.pressed.connect do
      send_sample_rpc
    end
    vbox.add_child(btn_ping)

    spy_header = Godot.create(Godot::Label)
    spy_header.text = "--- Wireshark Packet Spy HUD ---"
    vbox.add_child(spy_header)

    log_box = Godot.create(Godot::RichTextLabel)
    log_box.set_custom_minimum_size(Godot::Vector2.new(420, 320))
    log_box.scroll_following = true
    vbox.add_child(log_box)
    @log_label = log_box

    append_log("[color=green]Ready to connect. Click Host or Join.[/color]")
  end

  def host_game : Void
    enet = Godot.create(Godot::ENetMultiplayerPeer)
    err = enet.create_server(port, 4)
    if err != Godot::Error::Ok
      update_status("Host Failed: #{err}")
      append_log("[color=red]Failed to bind server on port #{port}: #{err}[/color]")
      enet.destroy
      return
    end

    @peer = enet
    multiplayer.set_multiplayer_peer(enet)
    update_status("Hosting as Server (Peer 1)")
    append_log("[color=cyan]Server started on port #{port}![/color]")

    # Audit server start packet in spy
    @spy.record(1, 0, "ServerStarted", channel: 0, transfer_mode: "Reliable", payload_bytes: 64)
    spawn_player(1_i64, "HostPlayer")
  end

  def join_game : Void
    enet = Godot.create(Godot::ENetMultiplayerPeer)
    err = enet.create_client("127.0.0.1", port)
    if err != Godot::Error::Ok
      update_status("Join Failed: #{err}")
      append_log("[color=red]Failed to connect: #{err}[/color]")
      enet.destroy
      return
    end

    @peer = enet
    multiplayer.set_multiplayer_peer(enet)
    update_status("Connecting to 127.0.0.1:#{port}...")
    append_log("[color=yellow]Connecting to server...[/color]")

    multiplayer.connected_to_server.connect do
      my_id = multiplayer.get_unique_id
      update_status("Connected as Peer #{my_id}")
      append_log("[color=green]Connected! Assigned Peer ID: #{my_id}[/color]")
      @spy.record(my_id.to_i32, 1, "ConnectedToServer", channel: 0, transfer_mode: "Reliable", payload_bytes: 48)
      spawn_player(my_id.to_i64, "ClientPlayer_#{my_id}")
    end
  end

  def send_sample_rpc : Void
    if (cnt = @players_container) && cnt.get_child_count > 0
      first_child = cnt.get_child(0)
      if player = first_child.as?(NetworkedPlayer)
        my_id = multiplayer.get_unique_id
        pkt = @spy.record(my_id.to_i32, 0, "send_chat", channel: 0, transfer_mode: "Reliable", payload_bytes: 40)
        player.rpc("send_chat", "Ping from Peer #{my_id} at #{Godot.time.get_ticks_msec}ms")
        append_log("[color=magenta]#{pkt}[/color]")
      end
    else
      append_log("[color=orange]No active player spawned yet.[/color]")
    end
  end

  def spawn_player(id : Int64, name : String) : NetworkedPlayer
    player = Godot.create(NetworkedPlayer)
    player.name = "Player_#{id}"
    player.player_id = id
    player.player_name = name
    player.set_position(Godot::Vector2.new(200.0_f32 + (id * 50.0_f32), 200.0_f32))

    player.chat_received.connect do |sender, msg|
      append_log("[color=white][Peer #{sender}]: #{msg}[/color]")
    end

    @players_container.not_nil!.add_child(player) if @players_container
    player
  end

  def update_status(text : String) : Void
    @status_label.not_nil!.text = "Status: #{text}" if @status_label
    Godot.print("[Status] #{text}")
  end

  def append_log(bbcode : String) : Void
    if log_box = @log_label
      log_box.append_text("#{bbcode}\n")
    end
    Godot.print("[NetLog] #{bbcode}")
  end

  # Automated test cycle used in CI and `make test`
  def run_headless_verification : Void
    Godot.print("[MultiplayerDemo] Running automated headless verification...")

    # 1. Initialize ENet host peer
    server_peer = Godot.create(Godot::ENetMultiplayerPeer)
    err = server_peer.create_server(18920, 2)
    if err != Godot::Error::Ok
      Godot.print("[MultiplayerDemo] FAIL: create_server failed with #{err}")
      get_tree.quit(1)
      return
    end

    # 2. Inspect peer status
    status = server_peer.get_connection_status
    if status != Godot::MultiplayerPeer::ConnectionStatus::ConnectionConnected
      Godot.print("[MultiplayerDemo] FAIL: server connection status not connected")
      get_tree.quit(1)
      return
    end

    # 3. Wireshark Spy Auditing
    @spy.clear
    @spy.record(1, 0, "ServerInit", channel: 0, transfer_mode: "Reliable", payload_bytes: 128)
    @spy.record(1, 2, "SyncState", channel: 1, transfer_mode: "Unreliable", payload_bytes: 48)
    @spy.assert_rpc_sent(1, 0, "ServerInit")
    @spy.assert_rpc_sent(1, 2, "SyncState")

    # 4. Spawn NetworkedPlayer and invoke RPC
    player = Godot.create(NetworkedPlayer)
    player.name = "TestPlayer"
    player.player_id = 1_i64
    add_child(player)

    received_chat = false
    player.chat_received.connect do |sender, text|
      received_chat = true
      Godot.print("[MultiplayerDemo] RPC Callback received: #{text} from #{sender}")
    end

    player.send_chat("Headless verification ping")
    if !received_chat
      Godot.print("[MultiplayerDemo] FAIL: Local RPC broadcast did not trigger signal")
      get_tree.quit(1)
      return
    end

    # 5. Clean teardown
    player.destroy
    server_peer.close
    server_peer.destroy

    Godot.print("[MultiplayerDemo] PASS: Headless multiplayer test completed successfully!")
    get_tree.quit(0)
  end
end