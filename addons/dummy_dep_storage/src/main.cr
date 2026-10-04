require "../../dummy_base_dep/src/dummy_base_dep"
ensure_lapis

# =============================================================================
# Dummy Dep Storage: Inventory/Storage Plugin depending on dummy_base_dep
# =============================================================================

# Storage entity mixing in DummyBaseMixin and utilizing DummyBaseUtils
@[Tool]
node DummyStorageEntity < Node2D do
  include DummyBaseMixin

  # Total container slot capacity
  @[Export]
  property max_slots : Int32 = 32

  # Currently occupied slots
  @[Export]
  property used_slots : Int32 = 0

  # Emitted when an item stack is stored
  signal item_deposited(item_id : String, quantity : Int32)

  # Emitted when inventory reaches full capacity
  signal inventory_full

  def deposit_item(item_id : String, quantity : Int32) : Bool
    if @used_slots + quantity > @max_slots
      inventory_full.emit
      return false
    end

    @used_slots += quantity
    item_deposited.emit(item_id, quantity)
    true
  end

  def available_capacity : Int32
    Math.max(0, @max_slots - @used_slots)
  end

  def format_storage_log(action : String) : String
    DummyBaseUtils.format_action("Storage", action)
  end

  def storage_status : String
    "StorageEntity[slots=#{@used_slots}/#{@max_slots},tag=#{@shared_tag}]"
  end
end

# Editor plugin for storage system
@[Tool]
node DummyStoragePlugin < EditorPlugin do
  signal storage_system_ready

  def _enter_tree : Void
    storage_system_ready.emit
    Godot.print("[DummyStoragePlugin] Initialized successfully in editor!")
  end

  def _exit_tree : Void
    Godot.print("[DummyStoragePlugin] Deinitialized.")
  end
end
