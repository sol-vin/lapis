require "lapis"

# Grid container managing item slots, capacity limits, and inventory additions
@[Tool]
node InventoryGrid < Control do
  # Maximum total number of item storage slots in the grid
  @[Export]
  property capacity : Int32 = 20

  # Current count of occupied item storage slots
  @[Export]
  property item_count : Int32 = 5

  # Emitted when an item is successfully placed into an inventory slot
  signal item_added(item_name : String, slot : Int32)

  # Adds an item to the first available inventory storage slot
  def add_item(item_name : String) : Bool
    return false if @item_count >= @capacity
    @item_count += 1
    emit_item_added(item_name, @item_count)
    true
  end
end

# Editor plugin providing item database management and inventory slot debugging
@[Tool]
node DummyInventoryPlugin < EditorPlugin do
  # Currently selected inventory slot index in the editor inspector
  @[Export]
  property active_slot : Int32 = 0

  # Emitted when an inventory slot is inspected in the editor
  signal slot_inspected(slot : Int32, item_info : String)

  # Inspects an inventory slot index and returns formatted item descriptor information
  def inspect_inventory_slot(slot_index : Int32) : String
    @active_slot = slot_index
    info = "Slot #{slot_index}: TestItem_#{slot_index}"
    emit_slot_inspected(slot_index, info)
    info
  end

  # Resets and clears all cached inventory items for editor testing
  def clear_test_inventory : Void
    @active_slot = 0
    Godot.print("[DummyInventoryPlugin] Cleared test inventory slots.")
  end

  def _enter_tree : Void
    Godot.print("[DummyInventoryPlugin] Initialized successfully in editor!")
  end

  def _exit_tree : Void
    Godot.print("[DummyInventoryPlugin] Deinitialized.")
  end
end
