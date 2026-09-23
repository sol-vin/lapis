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
    if p = get_parent
      begin
        if run_me = p.get_node("RunMe")
          run_me.call_deferred("imma_print")
        end
      rescue
      end
    end
  end
end
