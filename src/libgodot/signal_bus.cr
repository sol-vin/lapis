# =============================================================================
# Lapis Gameplay Patterns: Type-Safe Signal Bus & Event Aggregator
# =============================================================================
# OPTIONAL REQUIRE: require "libgodot/signal_bus" or require "lapis/signal_bus"
#
# Provides a declarative, statically typed event bus macro for Lapis.
# Enables decoupled communication between game entities, UI, audio, and systems
# without direct parent-child references.
#
# ### Usage Example:
# ```crystal
# require "libgodot"
# require "libgodot/signal_bus"
#
# signal_bus GameEvents do
#   signal score_changed(new_score : Int32)
#   signal enemy_defeated(kind : String, bounty : Int32)
#   signal player_died
# end
#
# # Emitting from gameplay node:
# GameEvents.instance.score_changed.emit(100)
#
# # Subscribing from UI node:
# GameEvents.instance.score_changed.connect do |score|
#   label.text = "Score: #{score}"
# end
# ```

macro signal_bus(name, &block)
  node {{name}} < Godot::Node do
    {{yield}}

    @@bus_instance : {{name}}? = nil
    @@bus_mutex : ::Thread::Mutex = ::Thread::Mutex.new

    # Retrieves or lazily creates the singleton signal bus instance
    def self.instance : {{name}}
      @@bus_mutex.synchronize do
        if inst = @@bus_instance
          if inst.alive?
            return inst
          else
            @@bus_instance = nil
          end
        end

        # Attempt SceneTree root discovery
        if tree = Godot.get_tree?
          if root = (tree.get_root rescue nil)
            if existing = root.get_node_or_null(Godot::NodePath.new("{{name}}")).as?({{name}})
              @@bus_instance = existing
              return existing
            end
          end
        end

        # Create new instance attached to SceneTree or standalone
        created = Godot.create({{name}})
        created.name = "{{name}}"
        if tree = Godot.get_tree?
          if root = (tree.get_root rescue nil)
            root.add_child(created)
          end
        end
        @@bus_instance = created
        created
      end
    end

    # Resets the singleton instance (for test fixtures)
    def self.reset_bus! : Void
      @@bus_mutex.synchronize do
        if inst = @@bus_instance
          if inst.alive?
            inst.queue_free
          end
          @@bus_instance = nil
        end
      end
    end
  end
end
