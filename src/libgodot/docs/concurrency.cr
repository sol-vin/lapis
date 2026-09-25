module Lapis
  module Docs
    # # I. Concurrency, Fibers & Thread Safety Manual
    #
    # Godot and Crystal both possess sophisticated concurrency models. Combining them safely
    # requires understanding their boundaries: Godot relies on a single-threaded SceneTree main loop
    # with background OS threads, while Crystal uses lightweight M:N cooperative fibers atop
    # operating system threads.
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
    #       <td><strong>Execution Model</strong></td>
    #       <td><code>.topic_01_execution_model</code></td>
    #       <td>Crystal fiber scheduler vs Godot OS main loop and thread boundaries.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Cooperative Fibers</strong></td>
    #       <td><code>.topic_02_cooperative_fibers_in_process</code></td>
    #       <td>Pumping spawned fibers via Fiber.yield in _process and avoiding blocking sleep.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>OS Worker Threads</strong></td>
    #       <td><code>.topic_03_os_worker_threads</code></td>
    #       <td>Offloading heavy computation to Thread.new with Crystal::System::Thread.sleep.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Buffered Actor Channels</strong></td>
    #       <td><code>.topic_04_buffered_actor_channels</code></td>
    #       <td>Using buffered Channel(T).new(capacity) across OS threads without fiber suspension.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>call_deferred Dispatch</strong></td>
    #       <td><code>.topic_05_call_deferred_dispatch</code></td>
    #       <td>Marshalling background thread completions into Godot's MessageQueue.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Thread Mutex Safety</strong></td>
    #       <td><code>.topic_06_thread_mutex_collections</code></td>
    #       <td>Guarding non-thread-safe Crystal collections with ::Thread::Mutex.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Signal Await Safety</strong></td>
    #       <td><code>.topic_07_signal_awaiting_safety</code></td>
    #       <td>Awaiting signals, timeout handling, and automatic DisposedObjectError on early free.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ### Related Guides & Source References
    # - **Source Implementation**: `src/libgodot/channel.cr`, `src/libgodot/extensions.cr`
    # - **Live Specifications**: `spec/suites/test_concurrency.cr`, `spec/suites/test_concurrency_multi_thread_gc.cr`
    # - **Related Guides**: `Docs::K_CONCURRENCY_CHANNELS_AND_ERGONOMICS`, `Docs::H_LIFECYCLE_MEMORY_AND_DEAD_POINTER_SAFETY`
    module I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY
      # **Concurrency Best Practices**: Summary of architectural guidelines and threading rules for LibGodot.
      def self.topic_00_best_practices : Array(String)
        [
          "Yield cooperatively (Fiber.yield) in _process to advance background fibers",
          "Use Channel(T).new(capacity) to marshal data from background worker threads to the main thread",
          "Never mutate SceneTree nodes (add_child/remove_child) from background threads",
          "Use call_deferred for cross-thread method dispatch to engine objects",
          "Avoid blocking sleep in fibers; prefer Godot SceneTreeTimer or delta accumulators",
          "Use Crystal::System::Thread.sleep for true OS thread sleeps inside Thread.new",
          "Protect shared Crystal state across threads with ::Thread::Mutex or Atomic primitives",
        ]
      end

      # **Dual Concurrency Model**: Crystal fiber scheduler vs Godot OS main loop and thread boundaries.
      #
      # <table>
      #   <thead>
      #     <tr>
      #       <th>System</th>
      #       <th>Primitive</th>
      #       <th>Scheduler</th>
      #       <th>SceneTree Access</th>
      #     </tr>
      #   </thead>
      #   <tbody>
      #     <tr>
      #       <td><strong>Godot Engine</strong></td>
      #       <td>OS Threads (Main, Render, Physics)</td>
      #       <td>OS Kernel + Godot Main Loop</td>
      #       <td>Main Thread ONLY</td>
      #     </tr>
      #     <tr>
      #       <td><strong>Crystal Runtime</strong></td>
      #       <td>Green Fibers (<code>spawn</code>)</td>
      #       <td>Crystal Cooperative Scheduler</td>
      #       <td>Cooperative Main Thread ONLY</td>
      #     </tr>
      #   </tbody>
      # </table>
      #
      # Because Godot controls the OS main loop, Crystal's fiber scheduler does not run autonomously
      # unless the engine thread yields control.
      def self.topic_01_execution_model : Nil
      end

      # **Cooperative Fibers & Fiber.yield**: Pumping spawned fibers via Fiber.yield in _process and avoiding blocking sleep.
      #
      # When spawning lightweight Crystal fibers via `spawn do ... end`, you must cooperatively
      # yield the main thread during `_process(delta)`:
      #
      # ```crystal
      # node GameController < Node do
      #   def _ready : Void
      #     spawn do
      #       loop do
      #         # Fiber logic
      #         Fiber.yield
      #       end
      #     end
      #   end
      #
      #   def _process(delta : Float64) : Void
      #     # Give waiting fibers an execution slice every visual frame:
      #     Fiber.yield
      #   end
      # end
      # ```
      #
      # > [!WARNING]
      # > **Never call top-level `sleep` in a spawned fiber**: Godot does not pump Crystal's IOCP/epoll
      # > event loop, so a blocking fiber `sleep` will hang indefinitely. Use `get_tree.create_timer(sec)` instead.
      def self.topic_02_cooperative_fibers_in_process : Nil
      end

      # **OS Worker Threads**: Offloading heavy computation to Thread.new with Crystal::System::Thread.sleep.
      #
      # Offload expensive procedural generation, pathfinding, or physics crunching to OS threads:
      #
      # ```crystal
      # Thread.new do
      #   data = generate_procedural_mesh()
      #   # Communicate result back via Channel or call_deferred
      # end
      # ```
      #
      # > [!WARNING]
      # > **Never call top-level `sleep` in `Thread.new`**: In Crystal 1.20+, top-level `sleep` yields
      # > to an `ExecutionContext`, raising `NilAssertionError: Fiber#execution_context cannot be nil`.
      # > For true OS thread sleeps, use `Crystal::System::Thread.sleep(duration)`.
      def self.topic_03_os_worker_threads : Nil
      end

      # **Buffered Actor Channels**: Using buffered Channel(T).new(capacity) across OS threads without fiber suspension.
      #
      # To communicate between background OS worker threads and Godot:
      #
      # > [!IMPORTANT]
      # > **Always use buffered channels (`Channel(T).new(capacity)`) across OS threads.**
      # > In Crystal 1.20+, unbuffered channels suspend the calling fiber when no receiver is ready;
      # > on raw OS threads (`Thread.new`), `Fiber#execution_context` is `nil`, so suspending raises
      # > `NilAssertionError: Fiber#execution_context cannot be nil`.
      #
      # ```crystal
      # class WorldGenWorker
      #   @channel = Channel(ChunkData).new(16) # Buffered!
      #
      #   def start_worker
      #     Thread.new do
      #       chunk = build_chunk()
      #       @channel.send(chunk)
      #     end
      #   end
      #
      #   def poll_main_thread(target_node : Node)
      #     select
      #     when chunk = @channel.receive
      #       target_node.add_child(chunk.to_mesh_instance)
      #     else
      #       # No chunk ready this frame
      #     end
      #   end
      # end
      # ```
      #
      # See also: `spec/suites/test_concurrency.cr`
      def self.topic_04_buffered_actor_channels : Nil
      end

      # **call_deferred Dispatch**: Marshalling background thread completions into Godot's MessageQueue.
      #
      # When background threads need to notify Godot nodes, use `node.call_deferred("method", *args)`.
      # Godot buffers these into its thread-safe `MessageQueue` for dispatch on the main thread:
      #
      # ```crystal
      # Thread.new do
      #   score = compute_score()
      #   # Safely invokes on main thread:
      #   hud_node.call_deferred("update_score", score)
      # end
      # ```
      def self.topic_05_call_deferred_dispatch : Nil
      end

      # **Thread Mutex Safety**: Guarding non-thread-safe Crystal collections with ::Thread::Mutex.
      #
      # Standard Crystal `Hash` and `Array` collections are **not** thread-safe:
      #
      # ```crystal
      # class ThreadSafeCache
      #   @mutex = ::Thread::Mutex.new
      #   @items = Hash(String, Vector3).new
      #
      #   def set(key : String, val : Vector3) : Void
      #     @mutex.synchronize { @items[key] = val }
      #   end
      #
      #   def get(key : String) : Vector3?
      #     @mutex.synchronize { @items[key]? }
      #   end
      # end
      # ```
      def self.topic_06_thread_mutex_collections : Nil
      end

      # **Signal Await Safety**: Awaiting signals, timeout handling, and automatic DisposedObjectError on early free.
      #
      # Awaiting fibers validate `#alive?` on every frame slice:
      #
      # ```crystal
      # begin
      #   # Await signal with 10-second timeout:
      #   await(enemy.died, timeout_sec: 10.0)
      #   Godot.print("Enemy successfully defeated!")
      # rescue ex : Godot::DisposedObjectError
      #   # Caught safely if enemy was queue_free'd before emitting
      #   Godot.print_warn("Enemy was destroyed before signal: #{ex.message}")
      # end
      # ```
      #
      # Awaiting fibers never hang indefinitely and cannot trigger native segmentation faults.
      #
      # See also: `spec/suites/test_editor_signals.cr`
      def self.topic_07_signal_awaiting_safety : Nil
      end
    end
  end
end
