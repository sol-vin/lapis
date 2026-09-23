module Godot
  # ===========================================================================
  # Key & InputEventKey Extensions
  # ===========================================================================
  class InputEventKey < Godot::InputEventWithModifiers
    # Returns the pressed keycode as a strongly-typed `Godot::Key` enum
    def key : Godot::Key
      Godot::Key.new(keycode)
    end

    # Returns the physical keycode as a strongly-typed `Godot::Key` enum
    def physical_key : Godot::Key
      Godot::Key.new(physical_keycode)
    end
  end

  enum Key : Int64
    # Allows direct equality comparison between Godot::Key and integer keycodes
    def ==(other : Int) : Bool
      value == other.to_i64
    end
  end

  # ===========================================================================
  # Input Delegators
  # ===========================================================================
  class Input < Godot::Object
    def action_pressed?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_pressed(action, exact_match)
    end

    def action_just_pressed?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_pressed(action, exact_match)
    end

    def action_just_released?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_released(action, exact_match)
    end

    def axis(negative_action : String, positive_action : String) : Float32
      Bridge.get_axis(negative_action, positive_action)
    end

    def get_vector(negative_x : String, positive_x : String, negative_y : String, positive_y : String, deadzone : Float64 = -1.0_f64) : Vector2
      Bridge.get_vector(negative_x, positive_x, negative_y, positive_y, deadzone)
    end

    def is_mouse_button_pressed(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def mouse_button_pressed?(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def use_accumulated_input : Bool
      Bridge.use_accumulated_input
    end

    def use_accumulated_input=(enable : Bool) : Void
      Bridge.use_accumulated_input = enable
    end

    delegate_to_instance(
      action_pressed?,
      action_just_pressed?,
      action_just_released?,
      axis,
      get_vector,
      is_mouse_button_pressed,
      mouse_button_pressed?
    )
    delegate_property_to_instance(use_accumulated_input)
  end
end
