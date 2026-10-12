module Godot
  # ===========================================================================
  # Viewport Ergonomic Extensions
  # ===========================================================================
  class Viewport < Node
    # Convenience getter returning visible rectangular size as Vector2
    def size : Vector2
      get_visible_rect.size
    end
  end
end
