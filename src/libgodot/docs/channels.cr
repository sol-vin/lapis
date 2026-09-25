module Lapis
  module Docs
    # # K. Concurrency, Channels & Engine Ergonomics
    #
    # LibGodot bridges Crystal's fiber and thread models with Godot's multi-threaded
    # engine architecture. This module details the actor concurrency primitives,
    # thread safety invariants, and language ergonomics available to developers.
    #
    # ---
    #
    # ### 1. GodotChannel (Actor Concurrency)
    #
    # `Godot::Channel` (registered in Godot's `ClassDB` as `GodotChannel`) is a
    # thread-safe, bounded or unbounded actor channel that can be passed between
    # Crystal and Godot/GDScript:
    #
    # ```
    # # Inside Crystal:
    # channel = Godot::Channel.new(capacity: 16)
    #
    # # Spawn OS worker thread to crunch math:
    # Thread.new do
    #   result = compute_heavy_simulation()
    #   channel.send(result)
    # end
    #
    # # In Crystal fiber or _process:
    # if item = channel.try_receive
    #   apply_simulation(item)
    # end
    # ```
    #
    # In GDScript, `GodotChannel` emits `signal received` when data is sent,
    # allowing non-blocking reactive awaits:
    #
    # ```gdscript
    # # Inside GDScript:
    # func _ready():
    #     var channel = GodotChannel.new(16)
    #     # Asynchronously wait for data from Crystal worker
    #     var data = await channel.received
    #     print("Worker returned: ", data)
    # ```
    #
    # ---
    #
    # ### 2. Concurrency Safety Rules
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Runtime Context</th>
    #       <th>Allowed Operations</th>
    #       <th>Forbidden Operations</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>Godot Main Thread</strong></td>
    #       <td>SceneTree mutations, node creation/destruction, <code>try_receive</code>, <code>await_receive</code></td>
    #       <td>Blocking <code>receive()</code> (freezes window message pumping)</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Crystal Fibers (spawn)</strong></td>
    #       <td><code>await(signal)</code>, <code>await(timer)</code>, <code>delay(sec)</code>, <code>next_frame</code></td>
    #       <td>Top-level blocking <code>sleep(sec)</code></td>
    #     </tr>
    #     <tr>
    #       <td><strong>Background OS Threads</strong></td>
    #       <td>Heavy computation, <code>channel.send</code>, <code>call_deferred</code>, blocking <code>receive</code></td>
    #       <td>Direct SceneTree manipulation (<code>add_child</code>, <code>queue_free</code>)</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # ### 3. Resource & RefCounted DSL
    #
    # In addition to the `node` macro, developers can declare custom Godot Resources
    # and RefCounted objects with `@export` properties:
    #
    # ```
    # resource ItemStats < Resource do
    #   @[Export]
    #   property damage : Int32 = 10
    #
    #   @[Export]
    #   property rarity : String = "Legendary"
    # end
    #
    # gdclass StateMachine < RefCounted do
    #   @[Export]
    #   property current_state : String = "idle"
    # end
    # ```
    #
    # ---
    #
    # ### 4. Engine Async Helpers
    #
    # - `Godot.next_frame`: Cooperatively yields execution until the next render/process frame.
    # - `Godot.physics_frame`: Cooperatively yields execution until the next physics step.
    # - `Godot.delay(seconds)`: Pauses execution for the given duration without halting the engine.
    # - `Godot.spawn(&block)`: Spawns an exception-guarded cooperative fiber.
    #
    # ---
    #
    # ### 5. Collections Interoperability
    #
    # - `Godot::Dictionary` wraps Godot dictionaries and converts to/from Crystal `Hash` via `hash.to_godot_dict` and `dict.to_h`.
    # - `Godot::Array(T)` wraps Godot arrays with full `Enumerable` support and converts via `array.to_godot_array` and `arr.to_a`.
    #
    module K_CONCURRENCY_CHANNELS_AND_ERGONOMICS
      def self.features : Array(String)
        [
          "Thread-safe GodotChannel exposed to GDScript as RefCounted",
          "Reactive signal received emission on Main Thread via call_deferred",
          "Non-blocking try_receive and cooperative fiber await_receive",
          "resource and gdclass DSL macros for custom Resources and RefCounted objects",
          "Engine async helpers: Godot.next_frame, Godot.physics_frame, Godot.delay, Godot.spawn",
          "Godot::Dictionary and Godot::Array wrappers with Enumerable and Crystal conversions",
        ]
      end
    end
  end
end

