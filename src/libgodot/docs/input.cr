module Lapis
  module Docs
    # # O. Low-Latency Input & Responsive Controls Guide
    #
    # LibGodot provides zero-overhead, highly responsive input handling across both event-driven
    # virtual callbacks and high-frequency polling APIs.
    #
    # ### Executive Summary & Key Topics
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Topic</th>
    #       <th>Method / Anchor</th>
    #       <th>Description</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>Key Features</strong></td>
    #       <td><code>.topic_00_key_features</code></td>
    #       <td>Key features of LibGodot's low-latency input architecture.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Event-Driven vs Polling</strong></td>
    #       <td><code>.topic_01_event_driven_vs_polling</code></td>
    #       <td>Latency characteristics, mouse look responsiveness, and avoiding decay filters.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Virtual Callbacks</strong></td>
    #       <td><code>.topic_02_virtual_input_callbacks</code></td>
    #       <td>_unhandled_input, _input, and strongly-typed InputEvent downcasting.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Unaccumulated Input</strong></td>
    #       <td><code>.topic_03_disabling_accumulated_input</code></td>
    #       <td>Sub-frame mouse streaming for 500Hz-8000Hz gaming mice.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Zero-Allocation Queries</strong></td>
    #       <td><code>.topic_04_zero_allocation_queries</code></td>
    #       <td>get_vector, is_action_pressed, and stack StringName caching.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/binding_macros.cr`, `src/libgodot/generated/singletons.cr`
    # - **Live Specifications**: `spec/suites/test_virtual_methods_dispatch.cr`
    # - **Showcase Examples**: `examples/basic_demo/src/main.cr`
    # - **Related Guides**: `Docs::D_NODE_DSL_AND_SIGNALS`, `Docs::V_PERFORMANCE_AND_BENCHMARKS`
    module O_LOW_LATENCY_INPUT_GUIDE
      # **Key Features**: Returns key features of LibGodot's low-latency input architecture.
      def self.topic_00_key_features : Array(String)
        [
          "Immediate virtual dispatch via _unhandled_input bypassing frame-rate batching",
          "Sub-frame mouse motion precision by disabling accumulated input",
          "Zero-allocation vector calculation via Godot::Input.get_vector",
          "StringName caching for zero GC pressure during high-frequency physics ticks",
        ]
      end

      # **Event-Driven Input vs Polling**: Latency characteristics, mouse look responsiveness, and avoiding decay filters.
      #
      # For high-frequency, responsive inputs like mouse look and twitch keypresses, rely on
      # virtual event callbacks (`_unhandled_input` or `_input`) rather than polling in `_process`:
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>Paradigm</th>
      #       <th>Method / API</th>
      #       <th>Latency &amp; Characteristics</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Event Dispatch (Recommended for Mouse)</strong></td>
      #       <td><code>def _unhandled_input(event : Godot::InputEvent)</code></td>
      #       <td>Sub-millisecond immediate dispatch. Delivers raw mouse relative delta without filtering.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Vector Polling (Recommended for Movement)</strong></td>
      #       <td><code>Godot::Input.get_vector(neg_x, pos_x, neg_y, pos_y)</code></td>
      #       <td>Runs single native engine dispatch with deadzone handling. Zero allocations per frame.</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Velocity Polling (Avoid for Mouse Look)</strong></td>
      #       <td><code>Godot.input.get_last_mouse_velocity * delta</code></td>
      #       <td><strong>Warning:</strong> Godot applies an internal low-pass decay filter, introducing 2-3 frames of lag.</td>
      #     </tr>
      #   </tbody>
      # </table>
      def self.topic_01_event_driven_vs_polling : Nil
      end

      # **Virtual Input Callbacks**: Direct virtual method dispatch for unhandled input events.
      #
      # Declare input callbacks inside any `node` class. LibGodot automatically registers
      # the virtual call table entries and wraps native pointers into typed `InputEvent` subclasses:
      #
      # ```crystal
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
      # See also: `spec/suites/test_virtual_methods_dispatch.cr`
      def self.topic_02_virtual_input_callbacks : Nil
      end

      # **Disabling Accumulated Input**: Sub-frame mouse streaming for high-refresh gaming mice.
      #
      # By default, Godot batches input events to match the OS display refresh rate.
      # For competitive games or high-polling-rate mice (500Hz - 8000Hz), disable accumulation:
      #
      # ```crystal
      # def _ready : Void
      #   # Disable frame batching to receive unbuffered sub-frame mouse events immediately
      #   Godot::Input.use_accumulated_input = false
      # end
      # ```
      def self.topic_03_disabling_accumulated_input : Nil
      end

      # **Zero-Allocation Queries**: Zero-overhead action and button queries via cached StringNames.
      #
      # `Godot::Input` action queries use process-wide thread-safe `StringName` caching and
      # stack-allocated argument buffers, guaranteeing zero GC heap allocations in `_physics_process`:
      #
      # ```crystal
      # def _physics_process(delta : Float64) : Void
      #   # Zero-allocation 2D composite input vector with circular deadzone
      #   input_dir = Godot::Input.get_vector("move_left", "move_right", "move_forward", "move_back")
      #
      #   # Zero-allocation button press checks
      #   if Godot::Input.is_action_just_pressed("jump") && is_on_floor
      #     velocity = Godot::Vector3.new(velocity.x, 10.0_f32, velocity.z)
      #   end
      # end
      # ```
      def self.topic_04_zero_allocation_queries : Nil
      end
    end
  end
end
