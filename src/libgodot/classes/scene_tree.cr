module Godot
  # Manages the hierarchy of scene nodes and execution loops.
  class SceneTree < MainLoop
    property current_scene : Node = Node.new
    property root : Node = Node.new
  end

end
