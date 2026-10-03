# =============================================================================
# Batch Collection Extensions for Godot Nodes
# =============================================================================
# Adds batch manipulation, state broadcasting, filtering, and lifecycle management
# methods directly to Array(T).

class Array(T)
  # Calls queue_free on every alive node in the collection
  def queue_free_all : Void
    each do |item|
      if item.is_a?(Godot::Node)
        item.queue_free if item.active?
      end
    end
  end

  # Calls destroy on every alive node in the collection
  def destroy_all : Void
    each do |item|
      if item.is_a?(Godot::Node)
        item.destroy if item.active?
      end
    end
  end

  # Broadcasts a dynamic method call to all alive objects in the collection
  def call_all(method : String | Symbol, *args) : Void
    m_str = method.to_s
    each do |item|
      if item.is_a?(Godot::Object)
        item.call(m_str, *args) if item.active?
      end
    end
  end

  # Broadcasts a property assignment to all alive objects in the collection
  def set_all(prop : String | Symbol, value) : Void
    p_str = prop.to_s
    each do |item|
      if item.is_a?(Godot::Object)
        item.set(p_str, value) if item.active?
      end
    end
  end

  # Adds all alive nodes in the collection to the specified group
  def add_to_group_all(group : String) : Void
    each do |item|
      if item.is_a?(Godot::Node)
        item.add_to_group(group) if item.active?
      end
    end
  end

  # Removes all alive nodes in the collection from the specified group
  def remove_from_group_all(group : String) : Void
    each do |item|
      if item.is_a?(Godot::Node)
        item.remove_from_group(group) if item.active?
      end
    end
  end

  # Shows all 2D canvas items, 3D spatial nodes, or objects with a visible property
  def show_all : Void
    each do |item|
      if item.is_a?(Godot::CanvasItem)
        item.show if item.active?
      elsif item.is_a?(Godot::Node3D)
        item.show if item.active?
      elsif item.is_a?(Godot::Object)
        item.set("visible", true) rescue nil
      end
    end
  end

  # Hides all 2D canvas items, 3D spatial nodes, or objects with a visible property
  def hide_all : Void
    each do |item|
      if item.is_a?(Godot::CanvasItem)
        item.hide if item.active?
      elsif item.is_a?(Godot::Node3D)
        item.hide if item.active?
      elsif item.is_a?(Godot::Object)
        item.set("visible", false) rescue nil
      end
    end
  end

  # Filters the collection and downcasts all elements matching type U into an Array(U)
  def filter_as(type : U.class) : ::Array(U) forall U
    res = ::Array(U).new
    each do |item|
      if item.is_a?(Godot::Node)
        if typed = Godot::Node.cast_to?(item, U)
          res << typed
        end
      elsif item.is_a?(U)
        res << item
      end
    end
    res
  end

  # Reparents all alive nodes in the collection to the specified new parent
  def reparent_all(new_parent : Godot::Node, keep_global_transform : Bool = true) : Void
    each do |item|
      if item.is_a?(Godot::Node)
        item.reparent(new_parent, keep_global_transform) if item.active?
      end
    end
  end
end
