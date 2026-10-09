module Godot
  class CollisionShape3D < Node3D
    @disabled : Bool = false

    def disabled : Bool
      if !@pointer.null?
        is_disabled
      else
        @disabled
      end
    end

    def disabled=(v : Bool)
      @disabled = v
      if !@pointer.null?
        set_disabled(v)
      end
    end

    def disabled? : Bool
      disabled
    end
  end

  # Base class for all GUI and user interface controls.
end
