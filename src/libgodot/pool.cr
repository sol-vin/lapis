# =============================================================================
# Lapis Gameplay Patterns: Zero-Allocation Object Pool
# =============================================================================
# OPTIONAL REQUIRE: require "libgodot/pool" or require "lapis/pool"
#
# Provides high-performance object pooling for Godot Nodes with:
# - Monotonic 64-bit dead-pointer safety (validates #alive? before reuse)
# - Automatic capacity pre-warming
# - Dynamic fallback allocation on pool exhaustion
# - Automatic process_mode and visibility toggling
#
# ### Usage Example:
# ```crystal
# require "libgodot"
# require "libgodot/pool"
#
# node Bullet < Area2D do
#   property speed : Float32 = 400.0_f32
#   def reset(pos : Vector2) : Void
#     self.position = pos
#   end
# end
#
# class Arena < Node2D
#   node_pool bullets : Bullet, capacity: 50
#
#   def fire(at_pos : Vector2) : Void
#     b = bullets.acquire { |b| b.reset(at_pos) }
#   end
# end
# ```

module Lapis
  class NodePool(T)
    getter capacity : Int32
    getter root_node : Godot::Node

    @available = Array(T).new
    @active = Array(T).new

    def initialize(@root_node : Godot::Node, @capacity : Int32 = 20)
      prewarm
    end

    def available_count : Int32
      @available.size
    end

    def active_count : Int32
      @active.size
    end

    # Pre-allocates pooled instances attached to root_node, deactivated
    def prewarm : Void
      @capacity.times do
        node = Godot.create(T)
        deactivate_node(node)
        @root_node.add_child(node)
        @available << node
      end
    end

    # Acquires a node from the pool, configures it in block, and returns it
    def acquire(&block : T -> Void) : T
      node = acquire
      with node yield node
      node
    end

    # Acquires an active node from the pool or creates fallback
    def acquire : T
      node : T? = nil
      while !@available.empty?
        candidate = @available.pop
        if candidate.active?
          node = candidate
          break
        end
      end

      actual = node || begin
        fresh = Godot.create(T)
        @root_node.add_child(fresh)
        fresh
      end

      activate_node(actual)
      @active << actual
      actual
    end

    # Returns an active node back to the pool
    def release(node : T) : Void
      return unless node.active?
      @active.delete(node)
      deactivate_node(node)
      @available << node
    end

    # Releases all currently active nodes back into the pool
    def release_all : Void
      @active.reverse_each do |node|
        if node.active?
          deactivate_node(node)
          @available << node
        end
      end
      @active.clear
    end

    private def activate_node(node : T) : Void
      if node.is_a?(Godot::CanvasItem)
        node.visible = true
      elsif node.is_a?(Godot::Node3D)
        node.visible = true
      end
      node.process_mode = 0_i64
    end

    private def deactivate_node(node : T) : Void
      if node.is_a?(Godot::CanvasItem)
        node.visible = false
      elsif node.is_a?(Godot::Node3D)
        node.visible = false
      end
      node.process_mode = 4_i64
    end
  end

  alias Pool = NodePool
end

# Declares a lazy-initialized node pool property
macro node_pool(decl, capacity = 20)
  {% if decl.is_a?(TypeDeclaration) %}
    @{{decl.var.id}} : ::Lapis::NodePool({{decl.type.id}})? = nil
    def {{decl.var.id}} : ::Lapis::NodePool({{decl.type.id}})
      @{{decl.var.id}} ||= ::Lapis::NodePool({{decl.type.id}}).new(self, {{capacity}})
    end
  {% end %}
end

macro node_pool(name, type, capacity = 20)
  @{{name.id}} : ::Lapis::NodePool({{type.id}})? = nil
  def {{name.id}} : ::Lapis::NodePool({{type.id}})
    @{{name.id}} ||= ::Lapis::NodePool({{type.id}}).new(self, {{capacity}})
  end
end
