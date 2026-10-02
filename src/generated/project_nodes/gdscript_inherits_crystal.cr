# Generated strongly typed wrapper for GDScript node `GdscriptInheritsCrystal`
# Script Path: res://scripts/gdscript_inherits_crystal.gd
module Godot
  class GdscriptInheritsCrystal < Godot::CharacterBody2D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self.from(node : Godot::Object) : self
      new(node.pointer)
    end

    # Property `gdscript_bonus` (Int64)
    def gdscript_bonus : Int64
      call_i64("get", "gdscript_bonus")
    end

    def gdscript_bonus=(val) : Void
      call("set", "gdscript_bonus", val)
    end

    # Method `compute_damage` -> Int64
    def compute_damage(raw_input : Int64) : Int64
      call_i64("compute_damage", raw_input)
    end

    # Method `get_effective_speed` -> Float64
    def get_effective_speed : Float64
      call_f64("get_effective_speed")
    end

    # Method `trigger_entity_action` -> String
    def trigger_entity_action(act : String) : String
      call_str("trigger_entity_action", act)
    end
  end
end

alias GdscriptInheritsCrystal = Godot::GdscriptInheritsCrystal
