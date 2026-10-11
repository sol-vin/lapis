module Godot
  class Camera3D < Node3D
    @fov : Float64 = 75.0
    @near : Float64 = 0.05
    @far : Float64 = 4000.0
    @current : Bool = false

    def fov : Float64
      if !@pointer.null?
        get_fov
      else
        @fov
      end
    end

    def fov=(v : Number)
      @fov = v.to_f64
      if !@pointer.null?
        set_fov(v.to_f64)
      end
    end

    def current : Bool
      if !@pointer.null?
        is_current
      else
        @current
      end
    end

    def current=(v : Bool)
      @current = v
      if !@pointer.null?
        set_current(v)
      end
    end

    def current? : Bool
      current
    end

    def near : Float64
      if !@pointer.null?
        get_near
      else
        @near
      end
    end

    def near=(v : Number)
      @near = v.to_f64
      if !@pointer.null?
        set_near(v.to_f64)
      end
    end

    def far : Float64
      if !@pointer.null?
        get_far
      else
        @far
      end
    end

    def far=(v : Number)
      @far = v.to_f64
      if !@pointer.null?
        set_far(v.to_f64)
      end
    end
  end

  # Ray casting node for 3D physics ray intersection queries.
end
