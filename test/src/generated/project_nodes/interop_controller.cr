# Generated strongly typed wrapper for GDScript node `InteropController`
# Script Path: res://scripts/interop_controller.gd
module Godot
  class InteropController < Godot::Node
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    def self.from(node : Godot::Object) : self
      new(node.pointer)
    end
    # Property `counter` (Int64)
    def counter : Int64
      call_i64("get", "counter")
    end
    def counter=(val) : Void
      call("set", "counter", val)
    end
    # Property `received_node_name` (String)
    def received_node_name : String
      call_str("get", "received_node_name")
    end
    def received_node_name=(val) : Void
      call("set", "received_node_name", val)
    end
    # Property `channel_received_count` (Int64)
    def channel_received_count : Int64
      call_i64("get", "channel_received_count")
    end
    def channel_received_count=(val) : Void
      call("set", "channel_received_count", val)
    end
    # Property `last_channel_received_val` (String)
    def last_channel_received_val : String
      call_str("get", "last_channel_received_val")
    end
    def last_channel_received_val=(val) : Void
      call("set", "last_channel_received_val", val)
    end
    # Property `last_crystal_signal_name` (String)
    def last_crystal_signal_name : String
      call_str("get", "last_crystal_signal_name")
    end
    def last_crystal_signal_name=(val) : Void
      call("set", "last_crystal_signal_name", val)
    end
    # Property `last_crystal_signal_data` (String)
    def last_crystal_signal_data : String
      call_str("get", "last_crystal_signal_data")
    end
    def last_crystal_signal_data=(val) : Void
      call("set", "last_crystal_signal_data", val)
    end
    # Property `signal_call_count` (Int64)
    def signal_call_count : Int64
      call_i64("get", "signal_call_count")
    end
    def signal_call_count=(val) : Void
      call("set", "signal_call_count", val)
    end
    # Method `add_numbers` -> Int64
    def add_numbers(a : Int64, b : Int64) : Int64
      call_i64("add_numbers", a, b)
    end
    # Method `compute_distance` -> Float64
    def compute_distance(p1 : Godot::Vector2, p2 : Godot::Vector2) : Float64
      call_f64("compute_distance", p1, p2)
    end
    # Method `format_greeting` -> String
    def format_greeting(name : String) : String
      call_str("format_greeting", name)
    end
    # Method `is_node_valid_and_named` -> Bool
    def is_node_valid_and_named(node : Godot::Node, expected_name : String) : Bool
      call_bool("is_node_valid_and_named", node, expected_name)
    end
    # Method `spawn_node_for_crystal` -> Godot::Node?
    def spawn_node_for_crystal(node_name : String) : Godot::Node?
      call_obj_as(Godot::Node, "spawn_node_for_crystal", node_name)
    end
    # Method `inspect_crystal_node` -> String
    def inspect_crystal_node(node : Godot::Node) : String
      call_str("inspect_crystal_node", node)
    end
    # Method `reparent_node_from_crystal` -> Bool
    def reparent_node_from_crystal(child : Godot::Node, new_parent : Godot::Node) : Bool
      call_bool("reparent_node_from_crystal", child, new_parent)
    end
    # Method `increment_counter` -> Int64
    def increment_counter(amount : Int64) : Int64
      call_i64("increment_counter", amount)
    end
    # Method `fire_gd_ping` -> Void
    def fire_gd_ping(val : Int64) : Void
      call("fire_gd_ping", val)
      nil
    end
    # Method `run_await_sequence` -> String
    def run_await_sequence() : String
      call_str("run_await_sequence")
    end
    # Method `destroy_node_from_gdscript` -> Bool
    def destroy_node_from_gdscript(target : Godot::Node) : Bool
      call_bool("destroy_node_from_gdscript", target)
    end
    # Method `queue_free_node_from_gdscript` -> Bool
    def queue_free_node_from_gdscript(target : Godot::Node) : Bool
      call_bool("queue_free_node_from_gdscript", target)
    end
    # Method `inspect_resource_power` -> Int64
    def inspect_resource_power(res : Godot::Resource) : Int64
      call_i64("inspect_resource_power", res)
    end
    # Method `inspect_resource_name` -> String
    def inspect_resource_name(res : Godot::Resource) : String
      call_str("inspect_resource_name", res)
    end
    # Method `modify_resource_power` -> Bool
    def modify_resource_power(res : Godot::Resource, new_power : Int64) : Bool
      call_bool("modify_resource_power", res, new_power)
    end
    # Method `load_resource_from_disk_and_get_power` -> Int64
    def load_resource_from_disk_and_get_power(path : String) : Int64
      call_i64("load_resource_from_disk_and_get_power", path)
    end
    # Method `inspect_enum_property` -> Int64
    def inspect_enum_property(node : Godot::Node, prop_name : String) : Int64
      call_i64("inspect_enum_property", node, prop_name)
    end
    # Method `set_enum_property` -> Bool
    def set_enum_property(node : Godot::Node, prop_name : String, val : Int64) : Bool
      call_bool("set_enum_property", node, prop_name, val)
    end
    # Method `get_enum_property_hint_string` -> String
    def get_enum_property_hint_string(node : Godot::Node, prop_name : String) : String
      call_str("get_enum_property_hint_string", node, prop_name)
    end
    # Method `get_enum_property_hint` -> Int64
    def get_enum_property_hint(node : Godot::Node, prop_name : String) : Int64
      call_i64("get_enum_property_hint", node, prop_name)
    end
    # Method `query_classdb_enum_constant` -> Int64
    def query_classdb_enum_constant(class_name_str : String, const_name : String) : Int64
      call_i64("query_classdb_enum_constant", class_name_str, const_name)
    end
    # Method `create_channel` -> Godot::RefCounted?
    def create_channel(capacity : Int64) : Godot::RefCounted?
      call_obj_as(Godot::RefCounted, "create_channel", capacity)
    end
    # Method `send_to_channel` -> Bool
    def send_to_channel(ch : Godot::RefCounted, data : String) : Bool
      call_bool("send_to_channel", ch, data)
    end
    # Method `try_send_to_channel` -> Bool
    def try_send_to_channel(ch : Godot::RefCounted, data : String) : Bool
      call_bool("try_send_to_channel", ch, data)
    end
    # Method `receive_from_channel` -> String
    def receive_from_channel(ch : Godot::RefCounted) : String
      call_str("receive_from_channel", ch)
    end
    # Method `try_receive_from_channel` -> String
    def try_receive_from_channel(ch : Godot::RefCounted) : String
      call_str("try_receive_from_channel", ch)
    end
    # Method `get_channel_size` -> Int64
    def get_channel_size(ch : Godot::RefCounted) : Int64
      call_i64("get_channel_size", ch)
    end
    # Method `is_channel_empty` -> Bool
    def is_channel_empty(ch : Godot::RefCounted) : Bool
      call_bool("is_channel_empty", ch)
    end
    # Method `is_channel_full` -> Bool
    def is_channel_full(ch : Godot::RefCounted) : Bool
      call_bool("is_channel_full", ch)
    end
    # Method `is_channel_closed` -> Bool
    def is_channel_closed(ch : Godot::RefCounted) : Bool
      call_bool("is_channel_closed", ch)
    end
    # Method `close_channel` -> Void
    def close_channel(ch : Godot::RefCounted) : Void
      call("close_channel", ch)
      nil
    end
    # Method `connect_channel_received` -> Bool
    def connect_channel_received(ch : Godot::RefCounted) : Bool
      call_bool("connect_channel_received", ch)
    end
    # Method `_on_channel_received` -> Void
    def _on_channel_received(val : String) : Void
      call("_on_channel_received", val)
      nil
    end
    # Method `connect_crystal_signals` -> Bool
    def connect_crystal_signals(crystal_node : Godot::Node) : Bool
      call_bool("connect_crystal_signals", crystal_node)
    end
    # Method `_on_crystal_event` -> Void
    def _on_crystal_event(msg : String) : Void
      call("_on_crystal_event", msg)
      nil
    end
    # Method `_on_health_changed` -> Void
    def _on_health_changed(current : Int64, max_val : Int64) : Void
      call("_on_health_changed", current, max_val)
      nil
    end
    # Method `_on_data_transferred` -> Void
    def _on_data_transferred(text : String) : Void
      call("_on_data_transferred", text)
      nil
    end
    # Method `emit_crystal_node_signal` -> Void
    def emit_crystal_node_signal(crystal_node : Godot::Node, signal_name : String, arg : String) : Void
      call("emit_crystal_node_signal", crystal_node, signal_name, arg)
      nil
    end
    # Method `find_property_in_list` -> Void
    def find_property_in_list(node : Godot::Node, prop_name : String) : Void
      call("find_property_in_list", node, prop_name)
      nil
    end
    # Method `inspect_property_val` -> Void
    def inspect_property_val(node : Godot::Node, prop_name : String) : Void
      call("inspect_property_val", node, prop_name)
      nil
    end
    # Method `set_property_val` -> Bool
    def set_property_val(node : Godot::Node, prop_name : String, val) : Bool
      call_bool("set_property_val", node, prop_name, val)
    end
    # Method `load_and_inspect_crystal_scene` -> Void
    def load_and_inspect_crystal_scene(scene_path : String) : Void
      call("load_and_inspect_crystal_scene", scene_path)
      nil
    end
    # Method `verify_crystal_scene_properties` -> Bool
    def verify_crystal_scene_properties(scene_path : String) : Bool
      call_bool("verify_crystal_scene_properties", scene_path)
    end
    # Bound Signal `gd_ping`
    def gd_ping : Godot::BoundSignal
      signal("gd_ping")
    end
    # Bound Signal `gd_pong`
    def gd_pong : Godot::BoundSignal
      signal("gd_pong")
    end
  end
end

alias InteropController = Godot::InteropController
