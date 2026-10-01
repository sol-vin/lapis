require "lapis"

# Sample Crystal node showcasing property exports, lifecycle methods, and class registration
node MyCrystalNode < Node do
  # Sample exported integer value
  @[Export]
  property my_var : Int32 = 1234

  # Sample exported string message
  @[Export]
  property greeting : String = "Hello from Crystal!"

  def _ready : Void
    Godot.print("[LapisTemplate] MyCrystalNode initialized: my_var=#{@my_var}, greeting='#{@greeting}'")
  end

  def _process(delta : Float64) : Void
  end
end
