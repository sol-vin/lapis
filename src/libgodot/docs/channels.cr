module Lapis
  module Docs
    # # K. Concurrency, Channels & Engine Ergonomics
    #
    # LibGodot bridges Crystal's fiber and thread models with Godot's multi-threaded
    # engine architecture. This module details the actor concurrency primitives (`Godot::Channel`),
    # GDScript interop signals, and asynchronous engine ergonomics available to developers.
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
    #       <td><strong>GodotChannel Actor Pattern</strong></td>
    #       <td><code>.topic_01_godot_channel_actor_pattern</code></td>
    #       <td>Thread-safe message passing between background worker threads and main loop.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>GDScript Signal Interop</strong></td>
    #       <td><code>.topic_02_gdscript_channel_interop</code></td>
    #       <td>Reactive signal received emission enabling GDScript await channel.received.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Async Engine Helpers</strong></td>
    #       <td><code>.topic_03_async_engine_helpers</code></td>
    #       <td>delay(sec), next_frame, physics_frame, and cooperative timing helpers.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Collection Ergonomics</strong></td>
    #       <td><code>.topic_04_collection_ergonomics</code></td>
    #       <td>Idiomatic Crystal enumerable wrappers for Godot Array and Dictionary.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/channel.cr`, `src/libgodot/collections.cr`
    # - **Live Specifications**: `spec/suites/test_channel_exhaustive.cr`, `spec/suites/test_gdscript_channel_signal_interop.cr`
    # - **Related Guides**: `Docs::I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY`, `Docs::F_GDSCRIPT_INTEROP`
    module K_CONCURRENCY_CHANNELS_AND_ERGONOMICS
      # **Key Features & Capabilities**: Core channel ergonomics supported by LibGodot.
      def self.topic_00_key_features : Array(String)
        [
          "GodotChannel registered in ClassDB for 2-way interop with GDScript",
          "Thread-safe bounded or unbounded message queues",
          "Reactive signal emission when items arrive on channel",
          "Cooperative async helpers: delay, next_frame, physics_frame",
        ]
      end

      # **GodotChannel Actor Pattern**: Thread-safe message passing between background worker threads and main loop.
      #
      # `Godot::Channel` (registered in Godot's `ClassDB` as `GodotChannel`) is a
      # thread-safe actor channel that can pass messages between Crystal OS threads and Godot:
      #
      # ```crystal
      # # Create bounded channel with capacity 16:
      # channel = Godot::Channel.new(capacity: 16)
      #
      # # Spawn background worker:
      # Thread.new do
      #   result = compute_heavy_simulation()
      #   channel.send(result)
      # end
      #
      # # Main thread non-blocking poll:
      # if item = channel.try_receive
      #   apply_simulation(item)
      # end
      # ```
      #
      # See also: `spec/suites/test_channel_exhaustive.cr`
      def self.topic_01_godot_channel_actor_pattern : Nil
      end

      # **GDScript Signal Interop**: Reactive signal received emission enabling GDScript await channel.received.
      #
      # In GDScript, `GodotChannel` emits `signal received(item)` whenever data is pushed
      # from Crystal, allowing clean, non-blocking coroutines:
      #
      # ```gdscript
      # # GDScript consumer:
      # func _ready():
      #     var channel = GodotChannel.new(16)
      #     # Asynchronously wait for worker payload:
      #     var data = await channel.received
      #     print("Received from Crystal worker: ", data)
      # ```
      #
      # See also: `spec/suites/test_gdscript_channel_signal_interop.cr`
      def self.topic_02_gdscript_channel_interop : Nil
      end

      # **Async Engine Helpers**: delay(sec), next_frame, physics_frame, and cooperative timing helpers.
      #
      # LibGodot provides non-blocking async helpers that work seamlessly inside spawned fibers:
      #
      # ```crystal
      # spawn do
      #   # Wait 1.5 seconds without freezing main thread:
      #   Godot.delay(1.5)
      #   Godot.print("Timer elapsed!")
      #
      #   # Wait exactly one render frame:
      #   Godot.next_frame
      #
      #   # Wait exactly one physics step:
      #   Godot.physics_frame
      # end
      # ```
      def self.topic_03_async_engine_helpers : Nil
      end

      # **Collection Ergonomics**: Idiomatic Crystal enumerable wrappers for Godot Array and Dictionary.
      #
      # LibGodot wraps Godot's native `Array` and `Dictionary` types with full Crystal `Enumerable`
      # support, map/select pipelines, and type-safe indexers:
      #
      # ```crystal
      # array = Godot::Array.new
      # array << "Alpha"
      # array << "Beta"
      #
      # # Crystal Enumerable methods:
      # names = array.map(&.to_s.upcase)
      # ```
      #
      # See also: `src/libgodot/collections.cr`
      def self.topic_04_collection_ergonomics : Nil
      end
    end
  end
end
