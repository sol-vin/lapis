# Generated strongly typed wrapper for GDScript node `ComprehensiveInteropNode`
# Script Path: res://scripts/comprehensive_interop_node.gd
module Godot
  class ComprehensiveInteropNode < Godot::Node2D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    def self.from(node : Godot::Object) : self
      new(node.pointer)
    end
    # Property `int_prop` (Int64)
    def int_prop : Int64
      call_i64("get", "int_prop")
    end
    def int_prop=(val) : Void
      call("set", "int_prop", val)
    end
    # Property `float_prop` (Float64)
    def float_prop : Float64
      call_f64("get", "float_prop")
    end
    def float_prop=(val) : Void
      call("set", "float_prop", val)
    end
    # Property `string_prop` (String)
    def string_prop : String
      call_str("get", "string_prop")
    end
    def string_prop=(val) : Void
      call("set", "string_prop", val)
    end
    # Property `bool_prop` (Bool)
    def bool_prop : Bool
      call_bool("get", "bool_prop")
    end
    def bool_prop=(val) : Void
      call("set", "bool_prop", val)
    end
    # Property `internal_reset_count` (Int64)
    def internal_reset_count : Int64
      call_i64("get", "internal_reset_count")
    end
    def internal_reset_count=(val) : Void
      call("set", "internal_reset_count", val)
    end
    # Property `last_transition_old` (String)
    def last_transition_old : String
      call_str("get", "last_transition_old")
    end
    def last_transition_old=(val) : Void
      call("set", "last_transition_old", val)
    end
    # Property `last_transition_new` (String)
    def last_transition_new : String
      call_str("get", "last_transition_new")
    end
    def last_transition_new=(val) : Void
      call("set", "last_transition_new", val)
    end
    # Method `compute_scaled_sum` -> Int64
    def compute_scaled_sum(a : Int64, b : Int64, multiplier : Float64) : Int64
      call_i64("compute_scaled_sum", a, b, multiplier)
    end
    # Method `calculate_hypotenuse` -> Float64
    def calculate_hypotenuse(a : Float64, b : Float64) : Float64
      call_f64("calculate_hypotenuse", a, b)
    end
    # Method `format_complex_message` -> String
    def format_complex_message(prefix : String, id : Int64, status : String) : String
      call_str("format_complex_message", prefix, id, status)
    end
    # Method `validate_conditions` -> Bool
    def validate_conditions(flag_a : Bool, flag_b : Bool) : Bool
      call_bool("validate_conditions", flag_a, flag_b)
    end
    # Method `distance_to_point` -> Float64
    def distance_to_point(point : Godot::Vector2) : Float64
      call_f64("distance_to_point", point)
    end
    # Method `compute_dot3` -> Float64
    def compute_dot3(v1 : Godot::Vector3, v2 : Godot::Vector3) : Float64
      call_f64("compute_dot3", v1, v2)
    end
    # Method `color_brightness` -> Float64
    def color_brightness(c : Godot::Color) : Float64
      call_f64("color_brightness", c)
    end
    # Method `duplicate_child_node` -> Godot::Node?
    def duplicate_child_node(node_name : String) : Godot::Node?
      call_obj_as(Godot::Node, "duplicate_child_node", node_name)
    end
    # Method `inspect_incoming_node` -> String
    def inspect_incoming_node(target : Godot::Node) : String
      call_str("inspect_incoming_node", target)
    end
    # Method `perform_state_reset` -> Void
    def perform_state_reset() : Void
      call("perform_state_reset")
      nil
    end
    # Method `trigger_data_processed` -> Void
    def trigger_data_processed(record_id : Int64, label : String, score : Float64) : Void
      call("trigger_data_processed", record_id, label, score)
      nil
    end
    # Method `trigger_state_transitioned` -> Void
    def trigger_state_transitioned(old_state : String, new_state : String) : Void
      call("trigger_state_transitioned", old_state, new_state)
      nil
    end
    # Bound Signal `data_processed`
    def data_processed : Godot::BoundSignal
      signal("data_processed")
    end
    # Bound Signal `state_transitioned`
    def state_transitioned : Godot::BoundSignal
      signal("state_transitioned")
    end
  end
end

alias ComprehensiveInteropNode = Godot::ComprehensiveInteropNode
