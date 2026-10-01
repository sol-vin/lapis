require "../../../src/lapis"

# Represents a networked player entity in 2D space.
# Uses @[RPC] annotations to declare network replication contract with ClassDB.
node NetworkedPlayer < CharacterBody2D do
  @[Export]
  property player_id : Int64 = 1_i64

  @[Export]
  property player_name : String = "Player"

  @[Export]
  property hp : Int32 = 100

  @[Export]
  property score : Int32 = 0

  signal hp_changed(new_hp : Int32)
  signal chat_received(sender_id : Int64, message : String)

  def _ready : Void
    # Automatically bind multiplayer authority to player_id if set
    set_multiplayer_authority(player_id.to_i32) if player_id > 0
  end

  # Broadcasts a chat message across all peers
  @[RPC(mode: :any_peer, sync: :call_local, transfer_mode: :reliable, channel: 0)]
  def send_chat(msg : String) : Void
    sender = multiplayer.get_remote_sender_id
    sender = player_id if sender == 0
    emit(chat_received, sender.to_i64, msg)
  end

  # Synchronizes authority position to all remote puppets
  @[RPC(mode: :authority, sync: :call_local, transfer_mode: :unreliable_ordered, channel: 1)]
  def sync_position(pos : Godot::Vector2) : Void
    set_position(pos)
  end

  # Applies damage to this player, notifying peers
  @[RPC(mode: :any_peer, sync: :call_local, transfer_mode: :reliable, channel: 0)]
  def apply_damage(amount : Int32) : Void
    @hp = Math.max(0, @hp - amount)
    emit(hp_changed, @hp)
  end

  def _physics_process(delta : Float64) : Void
    # Only authority calculates and broadcasts movement
    if is_multiplayer_authority?
      # If controlled locally, can send position updates when moved
    end
  end
end
