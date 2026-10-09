module Godot
  class Node3D < Node
    @position : Vector3 = Vector3.new
    @global_position : Vector3 = Vector3.new
    @rotation : Vector3 = Vector3.new
    @rotation_degrees : Vector3 = Vector3.new
    @global_rotation : Vector3 = Vector3.new
    @global_rotation_degrees : Vector3 = Vector3.new
    @scale : Vector3 = Vector3.new(1.0_f32, 1.0_f32, 1.0_f32)
    @transform : Transform3D = Transform3D.new
    @global_transform : Transform3D = Transform3D.new
    @basis : Basis = Basis.new
    @global_basis : Basis = Basis.new
    @visible : Bool = true
    @top_level : Bool = false

    def position : Vector3
      if !@pointer.null?
        get_position
      else
        @position
      end
    end

    def position=(v : Vector3)
      @position = v
      if @pointer.null? && !@has_explicit_global_pos
        @global_position = v
      end
      if !@pointer.null?
        set_position(v)
      end
    end

    def global_position : Vector3
      if !@pointer.null?
        get_global_position
      else
        @global_position
      end
    end

    def global_position=(v : Vector3)
      @global_position = v
      @has_explicit_global_pos = true
      if !@pointer.null?
        set_global_position(v)
      end
    end

    def rotation : Vector3
      if !@pointer.null?
        get_rotation
      else
        @rotation
      end
    end

    def rotation=(v : Vector3)
      @rotation = v
      if !@pointer.null?
        set_rotation(v)
      end
    end

    def rotation_degrees : Vector3
      if !@pointer.null?
        get_rotation_degrees
      else
        @rotation_degrees
      end
    end

    def rotation_degrees=(v : Vector3)
      @rotation_degrees = v
      if !@pointer.null?
        set_rotation_degrees(v)
      end
    end

    def global_rotation : Vector3
      if !@pointer.null?
        get_global_rotation
      else
        @global_rotation
      end
    end

    def global_rotation=(v : Vector3)
      @global_rotation = v
      if !@pointer.null?
        set_global_rotation(v)
      end
    end

    def global_rotation_degrees : Vector3
      if !@pointer.null?
        get_global_rotation_degrees
      else
        @global_rotation_degrees
      end
    end

    def global_rotation_degrees=(v : Vector3)
      @global_rotation_degrees = v
      if !@pointer.null?
        set_global_rotation_degrees(v)
      end
    end

    def scale : Vector3
      if !@pointer.null?
        get_scale
      else
        @scale
      end
    end

    def scale=(v : Vector3)
      @scale = v
      if !@pointer.null?
        set_scale(v)
      end
    end

    def transform : Transform3D
      if !@pointer.null?
        get_transform
      else
        @transform
      end
    end

    def transform=(v : Transform3D)
      @transform = v
      if !@pointer.null?
        set_transform(v)
      end
    end

    def global_transform : Transform3D
      if !@pointer.null?
        get_global_transform
      else
        @global_transform
      end
    end

    def global_transform=(v : Transform3D)
      @global_transform = v
      if !@pointer.null?
        set_global_transform(v)
      end
    end

    def basis : Basis
      if !@pointer.null?
        get_basis
      else
        @basis
      end
    end

    def basis=(v : Basis)
      @basis = v
      if !@pointer.null?
        set_basis(v)
      end
    end

    def global_basis : Basis
      if !@pointer.null?
        get_global_basis
      else
        @global_basis
      end
    end

    def global_basis=(v : Basis)
      @global_basis = v
      if !@pointer.null?
        set_global_basis(v)
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

    def top_level : Bool
      if !@pointer.null?
        is_set_as_top_level
      else
        @top_level
      end
    end

    def top_level=(v : Bool)
      @top_level = v
      if !@pointer.null?
        set_as_top_level(v)
      end
    end
  end

  # Base class for all 2D collision and physics objects.
end
