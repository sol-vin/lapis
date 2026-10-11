require "./dummy_base_dep"
ensure_lapis

# =============================================================================
# Dummy Base Dependency Addon: Concrete ClassDB Entities
# =============================================================================
# These classes are registered in ClassDB exclusively by dummy_base_dep.dll
# (or in unified source mode). Consumer plugins compile against dummy_base_dep.cr
# for shared mixins and utilities, preventing duplicate ClassDB registration.

# Shared base entity node
@[Tool]
node DummyBaseEntity < Node2D do
  # Unique base identifier
  @[Export]
  property base_id : String = "base_entity_0"

  # Health ratio percentage from 0.0 to 1.0
  @[Export]
  property health_ratio : Float64 = 1.0

  # Tracks whether this base entity is currently enabled/active
  @[Export]
  property is_base_active : Bool = true

  # Emitted when the base entity state is toggled
  signal state_toggled(active : Bool)

  # Emitted when a generic base event occurs
  signal base_event(name : String, code : Int32)

  def ping_base : String
    "pong_from_base:#{@base_id}"
  end

  def calculate_power(multiplier : Float64) : Float64
    @health_ratio * multiplier * 10.0
  end

  def set_active(active : Bool) : Void
    @is_base_active = active
    state_toggled.emit(active)
  end

  def trigger_event(name : String, code : Int32) : Void
    base_event.emit(name, code)
  end
end

# Shared configuration resource provided by base dependency
@[Tool]
node DummyBaseConfig < Resource do
  @[Export]
  property config_version : Int32 = 1

  @[Export]
  property debug_tag : String = "CORE"

  signal config_reloaded

  def reload_config : Void
    @config_version += 1
    config_reloaded.emit
  end
end

# Editor plugin for base dep
@[Tool]
node DummyBasePlugin < EditorPlugin do
  signal base_inspected

  def _enter_tree : Void
    Godot.print("[DummyBasePlugin] Initialized successfully in editor!")
  end

  def _exit_tree : Void
    Godot.print("[DummyBasePlugin] Deinitialized.")
  end
end
