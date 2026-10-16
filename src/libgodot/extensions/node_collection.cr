# =============================================================================
# Collection Filtering Extensions for Godot Nodes
# =============================================================================

class Array(T)
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
end
