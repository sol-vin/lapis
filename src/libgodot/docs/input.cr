module Lapis
  module Docs
    # # O. Low-Latency Input & Responsive Controls Guide
    #
    # LibGodot provides zero-overhead, highly responsive input handling across both event-driven
    # virtual callbacks and high-frequency polling APIs.
    #
    # ---
    #
    # ### 1. Event-Driven Input vs. Polling
    #
    # For high-frequency, responsive inputs like mouse look and twitch keypresses, rely on
    # virtual event callbacks (`_unhandled_input` or `_input`) rather than polling in `_process`:
    #
    # <table style="width: 100%; border-collapse: collapse; margin: 1em 0;">
    #   <thead>
    #     <tr style="border-bottom: 2px solid #4a5568; text-align: left;">
    #       <th style="padding: 10px 14px;">Paradigm</th>
    #       <th style="padding: 10px 14px;">Method / API</th>
    #       <th style="padding: 10px 14px;">Latency &amp; Characteristics</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Event Dispatch (Recommended for Mouse)</strong></td>
    #       <td style="padding: 10px 14px;"><code>def _unhandled_input(event : Godot::InputEvent)</code></td>
    #       <td style="padding: 10px 14px;">Sub-millisecond immediate dispatch. Delivers raw mouse relative delta without filtering or frame delays.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Vector Polling (Recommended for Movement)</strong></td>
    #       <td style="padding: 10px 14px;"><code>Godot::Input.get_vector(neg_x, pos_x, neg_y, pos_y)</code></td>
    #       <td style="padding: 10px 14px;">Runs single native engine dispatch with deadzone handling. Zero allocations per frame.</td>
    #     </tr>
    #     <tr style="border-bottom: 1px solid #2d3748;">
    #       <td style="padding: 10px 14px;"><strong>Velocity Polling (Avoid for Mouse Look)</strong></td>
    #       <td style="padding: 10px 14px;"><code>Godot.input.get_last_mouse_velocity * delta</code></td>
    #       <td style="padding: 10px 14px;"><strong>Warning:</strong> Godot applies an internal low-pass decay filter, introducing 2-3 frames of perceptible inertia and lag.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # ### 2. First-Class Virtual Input Callbacks
    #
    # Declare input callbacks inside any `node` class. LibGodot automatically registers
    # the virtual call table entries and wraps native pointers into typed `InputEvent` subclasses:
    #
    # ```
    # node PlayerController < CharacterBody3D do
    #   property mouse_sensitivity : Float32 = 0.002_f32
    #
    #   def _unhandled_input(event : Godot::InputEvent) : Void
    #     if motion = event.as?(Godot::InputEventMouseMotion)
    #       # Instantaneous mouse look delta with zero inertia
    #       rotate_y(-motion.relative.x * @mouse_sensitivity)
    #     elsif key = event.as?(Godot::InputEventKey)
    #       if key.pressed? && !key.echo? && key.keycode == Godot::Key::Escape
    #         Godot::Input.mouse_mode = Godot::Input::MouseMode::Visible
    #       end
    #     end
    #   end
    # end
    # ```
    #
    # ---
    #
    # ### 3. Disabling Accumulated Input for Ultra-Low Latency
    #
    # By default, Godot batches input events to match the OS display refresh rate.
    # For competitive games or high-polling-rate mice (500Hz - 8000Hz), disable accumulation:
    #
    # ```
    # def _ready : Void
    #   # Disable frame batching to receive unbuffered sub-frame mouse events immediately
    #   Godot::Input.use_accumulated_input = false
    # end
    # ```
    #
    # ---
    #
    # ### 4. Zero-Allocation Action & Button Queries
    #
    # `Godot::Input` action queries use process-wide thread-safe `StringName` caching and
    # stack-allocated argument buffers, guaranteeing zero GC heap allocations in `_physics_process`:
    #
    # ```
    # def _physics_process(delta : Float64) : Void
    #   # Zero-allocation 2D composite input vector with circular deadzone
    #   input_dir = Godot::Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    #
    #   # Zero-allocation button press checks
    #   if Godot::Input.is_action_just_pressed("jump") && is_on_floor
    #     velocity = Godot::Vector3.new(velocity.x, jump_velocity, velocity.z)
    #   end
    # end
    # ```
    #
    module O_LOW_LATENCY_INPUT_GUIDE
      def self.features : Array(String)
        [
          "Direct virtual method dispatch for _input, _unhandled_input, _unhandled_key_input, and _gui_input",
          "Typed event unwrapping to InputEventMouseMotion, InputEventKey, InputEventMouseButton",
          "Stack-allocated argument buffers and StringName caching for zero heap allocation polling",
          "Direct C-API get_vector and mouse button state queries",
          "use_accumulated_input control for sub-frame raw input streaming",
        ]
      end
    end
  end
end

