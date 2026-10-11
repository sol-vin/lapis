module Godot
  class Control < CanvasItem
    @size : Vector2 = Vector2.new
    @position : Vector2 = Vector2.new
    @global_position : Vector2 = Vector2.new
    @rotation : Float32 = 0.0_f32
    @scale : Vector2 = Vector2.new(1.0_f32, 1.0_f32)
    @visible : Bool = true

    def size : Vector2
      if !@pointer.null?
        get_size
      else
        @size
      end
    end

    def size=(v : Vector2)
      @size = v
      if !@pointer.null?
        set_size(v, false)
      end
    end

    def set_size(size : Vector2) : Void
      if !@pointer.null?
        set_size(size, false)
      else
        @size = size
      end
    end

    def position : Vector2
      if !@pointer.null?
        get_position
      else
        @position
      end
    end

    def position=(v : Vector2)
      @position = v
      if !@pointer.null?
        set_position(v, false)
      end
    end

    def set_position(position : Vector2) : Void
      if !@pointer.null?
        set_position(position, false)
      else
        @position = position
      end
    end

    def global_position : Vector2
      if !@pointer.null?
        get_global_position
      else
        @global_position
      end
    end

    def global_position=(v : Vector2)
      @global_position = v
      if !@pointer.null?
        set_global_position(v, false)
      end
    end

    def set_global_position(position : Vector2) : Void
      if !@pointer.null?
        set_global_position(position, false)
      else
        @global_position = position
      end
    end

    def rotation : Float32
      if !@pointer.null?
        get_rotation.to_f32
      else
        @rotation
      end
    end

    def rotation=(v : Float32)
      @rotation = v
      if !@pointer.null?
        set_rotation(v.to_f64)
      end
    end

    def scale : Vector2
      if !@pointer.null?
        get_scale
      else
        @scale
      end
    end

    def scale=(v : Vector2)
      @scale = v
      if !@pointer.null?
        set_scale(v)
      end
    end

    def visible : Bool
      if !@pointer.null?
        is_visible
      else
        @visible
      end
    end

    def visible=(v : Bool)
      @visible = v
      if !@pointer.null?
        set_visible(v)
      end
    end

    def visible? : Bool
      visible
    end
  end

  # Base class for numeric control elements (sliders, progress bars, spinboxes).
end
