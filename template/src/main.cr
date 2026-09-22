require "lapis"
require "./**"

# In non-release builds, load in-editor test suites so they register with Lapis::Test
# and appear in the Crystal Editor Hub (Unit Test Runner tab)
{% unless flag?(:release) %}
  require "../spec/editor/**"
{% end %}

# Main root node for the template project
node MainNode < Node3D do
  @[ExportMultiline]
  property say_text : String = "Hello! Welcome to crystal in godot!\n Written with love by sol.vin"

  # Emitted when the node completes initialization
  signal initialized

  def _ready
	Godot.print("Starting the game!!!!!!!")
	Godot.print(say_text)
	get_tree.create_timer(1.0).timeout.connect do
	  say
	end
	

	emit_initialized
  end
  
  def say
	  each_child {|c| Godot.print(c.name)}
	
	  Godot.print get_node_as(MyCrystalNode, "MyCrystalNode").my_var
	  Godot.print get_node_as(MyGDNode, "MyGDNode").my_var
	
	  Godot.print("HELLO 12345678")
  end
end
