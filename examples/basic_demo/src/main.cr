require "../../../src/lapis"

# # Crystal LibGodot 4.8 Interactive Demo

# Main scene controller managing game lifecycle and stats
node DemoScene do
  def _ready
    Godot.print("==================================================================")
    Godot.print("       Welcome to the Crystal LibGodot 4.8 Interactive Demo!      ")
    Godot.print("==================================================================")
  end
end

node ModifierNode < Node3D do
  def _ready
    self.get_parent.get_node("RunMe").call_deferred("imma_print")
  end
end
