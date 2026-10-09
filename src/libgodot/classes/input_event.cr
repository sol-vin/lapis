module Godot
  class InputEvent < Resource
    def self.wrap(ptr : Void*) : Godot::InputEvent
      return Godot::InputEvent.new(ptr) if ptr.null?
      cls = Bridge.object_class_name(ptr)
      if cls.empty?
        if Bridge.object_is_class(ptr, "InputEventMouseMotion")
          return Godot::InputEventMouseMotion.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventMouseButton")
          return Godot::InputEventMouseButton.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventKey")
          return Godot::InputEventKey.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventJoypadButton")
          return Godot::InputEventJoypadButton.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventJoypadMotion")
          return Godot::InputEventJoypadMotion.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventAction")
          return Godot::InputEventAction.new(ptr)
        end
      end

      case cls
      when "InputEventMouseMotion"
        Godot::InputEventMouseMotion.new(ptr)
      when "InputEventMouseButton"
        Godot::InputEventMouseButton.new(ptr)
      when "InputEventKey"
        Godot::InputEventKey.new(ptr)
      when "InputEventJoypadButton"
        Godot::InputEventJoypadButton.new(ptr)
      when "InputEventJoypadMotion"
        Godot::InputEventJoypadMotion.new(ptr)
      when "InputEventAction"
        Godot::InputEventAction.new(ptr)
      when "InputEventScreenDrag"
        Godot::InputEventScreenDrag.new(ptr)
      when "InputEventScreenTouch"
        Godot::InputEventScreenTouch.new(ptr)
      when "InputEventShortcut"
        Godot::InputEventShortcut.new(ptr)
      when "InputEventMagnifyGesture"
        Godot::InputEventMagnifyGesture.new(ptr)
      when "InputEventPanGesture"
        Godot::InputEventPanGesture.new(ptr)
      when "InputEventMIDI"
        Godot::InputEventMIDI.new(ptr)
      else
        Godot::InputEvent.new(ptr)
      end
    end
  end

end
