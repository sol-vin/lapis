module Godot
  # ===========================================================================
  # RayCast & ShapeCast Query Extensions
  # ===========================================================================
  godot_collider_query RayCast2D, indexed: false
  godot_collider_query RayCast3D, indexed: false
  godot_collider_query ShapeCast2D, indexed: true
  godot_collider_query ShapeCast3D, indexed: true
end
