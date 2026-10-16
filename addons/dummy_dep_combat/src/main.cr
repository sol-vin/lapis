require "../../dummy_base_dep/src/dummy_base_dep"
ensure_lapis

# =============================================================================
# Dummy Dep Combat: Combat Subsystem Plugin depending on dummy_base_dep
# =============================================================================

# Combat entity mixing in DummyBaseMixin and utilizing DummyBaseUtils
@[Tool]
node DummyCombatEntity < Node2D do
  include DummyBaseMixin

  # Base attack power for combat calculations
  @[Export]
  property attack_power : Float64 = 45.0

  # Monotonic combo hit counter
  @[Export]
  property combo_counter : Int32 = 0

  # Emitted when an attack is successfully executed
  signal attack_executed(target_name : String, damage_amount : Float64)

  # Emitted when a critical hit occurs
  signal critical_hit(multiplier : Float64)

  def execute_strike(target_name : String, is_crit : Bool = false) : Float64
    mult = is_crit ? 2.5 : 1.2
    base_pwr = mult * 10.0
    total_damage = base_pwr + @attack_power
    @combo_counter += 1

    attack_executed.emit(target_name, total_damage)
    critical_hit.emit(mult) if is_crit
    total_damage
  end

  def format_combat_log(action : String) : String
    DummyBaseUtils.format_action("Combat", action)
  end

  def combat_status : String
    "CombatEntity[pwr=#{@attack_power},combo=#{@combo_counter},tag=#{@shared_tag}]"
  end
end

# Editor plugin for combat system
@[Tool]
node DummyCombatPlugin < EditorPlugin do
  signal combat_system_ready

  def _enter_tree : Void
    combat_system_ready.emit
    Godot.print("[DummyCombatPlugin] Initialized successfully in editor!")
  end

  def _exit_tree : Void
    Godot.print("[DummyCombatPlugin] Deinitialized.")
  end
end
