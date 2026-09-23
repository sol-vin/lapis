require "lapis"

# my_node node
node MyCrystalNode < Node do
  # This my var, there are many like but this one is mine!
  @[Export]
  property my_var : Int32 = 1234

  def _ready : Void
    Godot.print("my_node initialized")
  end

  def _process(delta : Float64) : Void
  end
end
