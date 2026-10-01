require "lapis"

# Game HUD displaying status and player health
node GameHUD < Control do
  @[Export]
  property title : String = "Lapis Starter Game"

  def _ready : Void
    Godot.print("[LapisTemplate] GameHUD initialized: #{@title}")
  end

  def update_health(current : Int32, max_hp : Int32) : Void
    Godot.print("[LapisTemplate] HUD health update: #{current}/#{max_hp}")
  end
end
