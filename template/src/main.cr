require "lapis"
require "./**"

# In non-release builds, load in-editor test suites so they register with Lapis::Test
# and appear in the Crystal Editor Hub (Unit Test Runner tab)
{% unless flag?(:release) %}
  require "../spec/editor/**"
{% end %}

# Main root scene controller for the template project
node MainNode < Node3D do
  @[ExportMultiline]
  property welcome_message : String = "Welcome to Lapis for Crystal in Godot 4!\nHigh-performance native gameplay scripting."

  @[ExportMultiline]
  property say_text : String = "Hello! Welcome to crystal in godot!\n Written with love by sol.vin"

  # Emitted when the template scene completes initialization
  signal initialized

  onready? player, PlayerController, "Player"
  onready? hud, GameHUD, "HUD"

  def _ready : Void
    Godot.print("[LapisTemplate] ========================================")
    Godot.print("[LapisTemplate] Starting Lapis Starter Game...")
    Godot.print("[LapisTemplate] #{welcome_message}")
    Godot.print("[LapisTemplate] #{say_text}")
    Godot.print("[LapisTemplate] ========================================")

    # Wire PlayerController signals to GameHUD if both child nodes are present
    if (p = player) && (h = hud)
      p.health_changed.connect do |curr, max_hp|
        h.update_health(curr, max_hp)
      end
      Godot.print("[LapisTemplate] Bound PlayerController signals to GameHUD")
    end

    emit(initialized)
    Godot.print("[LapisTemplate] MainNode initialization complete!")
  end
end
