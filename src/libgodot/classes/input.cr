module Godot
  class Input < Object
    def self.is_action_pressed(action : String | Symbol, exact_match : Bool = false) : Bool
      Bridge.is_action_pressed(action, exact_match)
    end

    def self.is_action_just_pressed(action : String | Symbol, exact_match : Bool = false) : Bool
      Bridge.is_action_just_pressed(action, exact_match)
    end

    def self.is_action_just_released(action : String | Symbol, exact_match : Bool = false) : Bool
      Bridge.is_action_just_released(action, exact_match)
    end

    def self.action_pressed?(action : String | Symbol, exact_match : Bool = false) : Bool
      Bridge.is_action_pressed(action, exact_match)
    end

    def self.action_just_pressed?(action : String | Symbol, exact_match : Bool = false) : Bool
      Bridge.is_action_just_pressed(action, exact_match)
    end

    def self.action_just_released?(action : String | Symbol, exact_match : Bool = false) : Bool
      Bridge.is_action_just_released(action, exact_match)
    end

    def self.is_key_pressed(key : Key | Int32 | Int64) : Bool
      Bridge.is_key_pressed(key.to_i32) || Bridge.is_physical_key_pressed(key.to_i32)
    end

    def self.is_physical_key_pressed(key : Key | Int32 | Int64) : Bool
      Bridge.is_physical_key_pressed(key.to_i32)
    end

    def self.is_mouse_button_pressed(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def self.mouse_button_pressed?(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def self.axis(negative_action : String, positive_action : String) : Float32
      Bridge.get_axis(negative_action, positive_action)
    end

    def self.get_vector(negative_x : String, positive_x : String, negative_y : String, positive_y : String, deadzone : Float64 = -1.0_f64) : Vector2
      Bridge.get_vector(negative_x, positive_x, negative_y, positive_y, deadzone)
    end

    def self.use_accumulated_input : Bool
      Bridge.use_accumulated_input
    end

    def self.use_accumulated_input=(enable : Bool) : Void
      Bridge.use_accumulated_input = enable
    end
  end

end
