module Godot
  # ===========================================================================
  # AStar2D & AStar3D Ergonomic Extensions
  # ===========================================================================
  class AStar2D
    # Predicate alias for `has_point`
    def has_point?(id : Int64) : Bool
      has_point(id)
    end

    # Predicate alias for `are_points_connected`
    def points_connected?(id : Int64, with_id : Int64, bidirectional : Bool = true) : Bool
      are_points_connected(id, with_id, bidirectional)
    end
  end

  class AStar3D
    # Predicate alias for `has_point`
    def has_point?(id : Int64) : Bool
      has_point(id)
    end

    # Predicate alias for `are_points_connected`
    def points_connected?(id : Int64, with_id : Int64, bidirectional : Bool = true) : Bool
      are_points_connected(id, with_id, bidirectional)
    end
  end
end
