module Lapis
  module Test
    class InputSender
      enum ActionType
        DispatchEvent
        WaitFrames
      end

      record Step, type : ActionType, event : Godot::InputEvent? = nil, frames : Int32 = 0

      @steps = Array(Step).new

      def key_down(keycode : Godot::Key | Int64, shift : Bool = false, ctrl : Bool = false, alt : Bool = false) : self
        ev = InputFactory.key_down(keycode, shift, ctrl, alt)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def key_up(keycode : Godot::Key | Int64, shift : Bool = false, ctrl : Bool = false, alt : Bool = false) : self
        ev = InputFactory.key_up(keycode, shift, ctrl, alt)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def mouse_down(button_index : Godot::MouseButton | Int64, position : Godot::Vector2 = Godot::Vector2::ZERO) : self
        ev = InputFactory.mouse_button_down(button_index, position)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def mouse_up(button_index : Godot::MouseButton | Int64, position : Godot::Vector2 = Godot::Vector2::ZERO) : self
        ev = InputFactory.mouse_button_up(button_index, position)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def action_down(action : String, strength : Float32 = 1.0_f32) : self
        ev = InputFactory.action_down(action, strength)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def action_up(action : String) : self
        ev = InputFactory.action_up(action)
        @steps << Step.new(ActionType::DispatchEvent, ev)
        self
      end

      def wait_frames(frames : Int32 = 1) : self
        @steps << Step.new(ActionType::WaitFrames, frames: frames)
        self
      end

      def send : Void
        input = Godot::Input.instance
        @steps.each do |step|
          case step.type
          when ActionType::DispatchEvent
            if ev = step.event
              input.parse_input_event(ev)
            end
          when ActionType::WaitFrames
            step.frames.times { Fiber.yield }
          end
        end
        @steps.clear
      end
    end
  end
end
