module Lapis
  module Docs
    # # I. Concurrency, Threading & Memory Architecture
    #
    # This section provides a comprehensive architectural guide on Crystal's concurrency models
    # (Fibers, Channels, Mutexes, and Multi-Threading) and how they integrate safely with the Godot Engine 4.x runtime.
    #
    # ---
    #
    # ### 1. Executive Summary & Core Rules
    #
    # 1. **SceneTree is Strictly Single-Threaded**:
    #    Never invoke `add_child`, `remove_child`, `reparent`, or `queue_free` from a background thread or fiber.
    #    Modifying the active scene hierarchy outside Godot's Main Thread causes memory corruption and engine crashes.
    # 2. **Cooperative Fibers Require Yield Points**:
    #    Godot controls the OS main loop. Spawned fibers (`spawn do ... end`) will not execute unless the main
    #    thread cooperatively yields via `Fiber.yield` in `_process(delta)`.
    # 3. **Avoid Blocking Sleep in Fibers**:
    #    Standard `sleep(duration)` relies on Crystal's event loop (LibEvent / IOCP), which is not pumped by
    #    Godot's host process. Use Godot's `get_tree.create_timer(duration)` or delta accumulators instead.
    # 4. **Use `Channel(T)` for Background Processing (Actor Pattern)**:
    #    Offload CPU-intensive tasks to background worker threads (`Thread.new`). Workers push results to a
    #    `Channel(T)`, and the Main Thread drains the channel non-blockingly during `_process(delta)`.
    # 5. **Cross-Thread Method Dispatch**:
    #    When background threads need to notify Godot nodes, use `node.call_deferred("method_name", *args)`.
    #    Godot buffers deferred calls into its thread-safe `MessageQueue` and dispatches them on the main thread
    #    during the next frame.
    #
    # ---
    #
    # ### 2. Crystal Concurrency Models vs. Godot Engine Architecture
    #
    # #### Concurrency Matrix
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Feature</th>
    #       <th>Crystal Mechanism</th>
    #       <th>Godot Threading Model</th>
    #       <th>Potential Hazard</th>
    #       <th>Solution / Best Practice</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>Fibers</strong></td>
    #       <td>M:1 cooperative coroutines; lightweight stacks.</td>
    #       <td>Godot Main Thread runs engine iterations.</td>
    #       <td>Fibers starve if main loop never yields; blocking <code>sleep</code> hangs.</td>
    #       <td>Call <code>Fiber.yield</code> in <code>_process</code>; use frame deltas instead of <code>sleep</code>.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>OS Threads (<code>Thread.new</code>)</strong></td>
    #       <td>1:1 kernel threads; registered with Boehm GC.</td>
    #       <td>Godot spawns Server &amp; Worker threads.</td>
    #       <td>Race conditions in Crystal data structures; off-thread Node access.</td>
    #       <td>Protect shared state with <code>::Thread::Mutex</code>; pass data via <code>Channel(T)</code>.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Multi-Threading (<code>-Dpreview_mt</code>)</strong></td>
    #       <td>M:N fibers across <code>CRYSTAL_WORKERS</code> threads; work stealing.</td>
    #       <td>Godot multithreaded rendering/physics.</td>
    #       <td>Concurrent access to <code>@@alive_instances</code> or global caches.</td>
    #       <td>Bridge uses <code>::Thread::Mutex</code> for <code>alive_instances</code>; confine SceneTree to Main Thread.</td>
    #     </tr>
    #     <tr>
    #       <td><strong>Channels (<code>Channel(T)</code>)</strong></td>
    #       <td>CSP message passing with thread-safe mutex and queue.</td>
    #       <td>Single-threaded Main Loop.</td>
    #       <td>Deadlock if blocking <code>receive</code> is called on the Main Thread.</td>
    #       <td>Use non-blocking <code>receive?</code> or select polling in <code>_process</code>.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # ### 3. Execution Contexts & Thread-Local Storage (TLS)
    #
    # #### Main Thread vs. Foreign Engine Threads
    # - **Main Thread Initialization**:
    #   When Godot loads `game.dll`, Godot invokes `crystal_godot_init` on the **Main Thread**. Crystal
    #   initializes its runtime (`Crystal.init_runtime`), sets up main thread TLS (`Thread.current`,
    #   `Fiber.current`), and boots the Boehm GC (`GC.init`).
    # - **Foreign Engine Threads (WorkerThreadPool / Audio / Physics)**:
    #   Godot creates worker threads natively in C++.
    #   - If a foreign engine thread directly calls an exported Crystal C callback, Crystal's TLS
    #     (`Thread.current`, `Fiber.current`) is uninitialized.
    #   - Raising an exception or attempting fiber operations on an unregistered foreign thread can
    #     trigger an immediate **Access Violation / Segmentation Fault (0xC0000005 / SIGSEGV)**.
    #   - **Rule**: All GDExtension class lifecycle methods (`_ready`, `_process`, exported properties)
    #     must be dispatched from the Main Thread.
    #
    # ---
    #
    # ### 4. Boehm Garbage Collector (BDWGC) Under Concurrency
    #
    # #### 1. Stack Scanning & Thread Registration
    # - Boehm GC stops the world and scans the call stacks of all registered threads to identify root pointers.
    # - Threads created through Crystal's `Thread.new` are automatically registered with BDWGC.
    # - If an unregistered thread executes Crystal code and allocates heap memory (e.g. strings, arrays, objects),
    #   BDWGC cannot scan its stack. Live objects held only on that stack could be prematurely freed, resulting
    #   in **silent heap corruption or use-after-free**.
    #
    # #### 2. Stop-The-World (STW) Pauses
    # - During a GC collection, BDWGC halts all registered threads (using `SuspendThread` on Windows or signals on POSIX).
    # - To minimize GC pause times in 60 FPS / 120 FPS games:
    #   - Avoid allocating temporary heap objects inside `_process` or `_physics_process`.
    #   - Use value types (`struct Vector2`, `struct Vector3`, `struct Transform3D`).
    #   - Pre-allocate arrays and reuse object pools.
    #
    # #### 3. Instance Rooting & Thread-Safe Registry
    # In `src/libgodot/bridge.cr`, the bridge maintains `@@alive_instances` (`Hash(Void*, Godot::Object)`) to root
    # active Crystal nodes and prevent premature GC deallocation.
    # - `Bridge.alive_instances` is protected by `Bridge.alive_mutex` (`Thread::Mutex.new`).
    # - Registration (`register_alive_instance`) and unregistration (`unregister_alive_instance`) are 100%
    #   thread-safe against concurrent scene deserialization or background worker instantiations.
    #
    # ---
    #
    # ### 5. Recommended Architecture: The 3-Tier Concurrency Model
    #
    # #### Tier 1: Cooperative Main-Thread Fibers (Gameplay & UI)
    # Best for gameplay scripts, cutscenes, state machines, and dialog systems.
    #
    # ```
    # class QuestManager < Godot::Node
    #   def _ready
    #     # Spawn a cooperative gameplay sequence
    #     spawn do
    #       Godot.print "Quest started!"
    #       # Wait 3 seconds using Godot SceneTreeTimer
    #       get_tree.create_timer(3.0)
    #       Godot.print "3 seconds elapsed, advancing quest!"
    #     end
    #   end
    #
    #   def _process(delta : Float64)
    #     # Grant cooperative execution slices to spawned fibers
    #     Fiber.yield
    #   end
    # end
    # ```
    #
    # #### Tier 2: Background Workers + Channel Message Passing (Actor Pattern)
    # Best for procedural generation, pathfinding grids, network requests, and heavy math.
    #
    # ```
    # class WorldGenerator < Godot::Node
    #   @result_channel = Channel(Array(Godot::Vector3)).new(1)
    #   @worker : Thread? = nil
    #
    #   def start_generation
    #     @worker = Thread.new do
    #       # Heavy background computation off-thread
    #       points = Array(Godot::Vector3).new
    #       100_000.times do |i|
    #         points << Godot::Vector3.new(i.to_f32, 0.0_f32, i.to_f32)
    #       end
    #       # Send immutable data back to main thread
    #       @result_channel.send(points)
    #     end
    #   end
    #
    #   def _process(delta : Float64)
    #     # Non-blocking poll on main thread
    #     select
    #     when points = @result_channel.receive
    #       apply_world_mesh(points)
    #     else
    #       # Work still in progress
    #     end
    #   end
    #
    #   private def apply_world_mesh(points : Array(Godot::Vector3))
    #     # Safe to mutate SceneTree here on Main Thread!
    #     Godot.print "Received #{points.size} points from background worker!"
    #   end
    # end
    # ```
    #
    # #### Tier 3: Thread-Safe Deferred Dispatch (`call_deferred`)
    # Best for fire-and-forget notifications from background threads to engine objects.
    #
    # ```
    # Thread.new do
    #   # Do background work...
    #   result = compute_heavy_score()
    #
    #   # Safely marshal back to Godot Main Thread via MessageQueue
    #   hud_node.call_deferred("update_score", result)
    # end
    # ```
    #
    # ---
    #
    # ### 6. Anti-Patterns & Common Pitfalls
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Anti-Pattern</th>
    #       <th>Why It Fails</th>
    #       <th>Correct Approach</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><code>node.add_child(c)</code> inside <code>Thread.new</code></td>
    #       <td>SceneTree is not thread-safe. Causes race condition in Godot child list.</td>
    #       <td>Marshal to main thread using <code>Channel(T)</code> or <code>call_deferred</code>.</td>
    #     </tr>
    #     <tr>
    #       <td><code>sleep(1.second)</code> inside a <code>spawn</code> fiber</td>
    #       <td>Crystal event loop is not pumped by Godot; fiber sleeps indefinitely.</td>
    #       <td>Use <code>get_tree.create_timer(1.0)</code> or frame delta accumulators.</td>
    #     </tr>
    #     <tr>
    #       <td><code>sleep(duration)</code> inside <code>Thread.new</code></td>
    #       <td>Top-level <code>sleep</code> yields a fiber to an <code>ExecutionContext</code>; raw threads lack context, raising <code>NilAssertionError: Fiber#execution_context cannot be nil</code>.</td>
    #       <td>Use <code>Crystal::System::Thread.sleep(duration)</code> for true OS thread sleeps.</td>
    #     </tr>
    #     <tr>
    #       <td>Unsynchronized global state (<code>@@my_cache[k] = v</code>)</td>
    #       <td>Crystal <code>Hash</code> and <code>Array</code> are not thread-safe under concurrent writes.</td>
    #       <td>Wrap access in <code>::Thread::Mutex.new</code> (<code>mutex.synchronize { ... }</code>).</td>
    #     </tr>
    #     <tr>
    #       <td>Keeping raw pointers to freed objects</td>
    #       <td>Accessing deleted C++ memory causes undefined behavior.</td>
    #       <td>Use monotonic instance IDs and check <code>is_valid?</code> or catch <code>DisposedObjectError</code>.</td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # #### Anti-Pattern 1: SceneTree Mutation from Background Threads
    #
    # Modifying Godot's active scene hierarchy (`add_child`, `remove_child`, `reparent`, `queue_free`)
    # from a background thread or fiber causes memory corruption in engine child vectors.
    #
    # ##### Bad Code:
    # ```
    # # BAD: Calling add_child directly from an OS background thread
    # Thread.new do
    #   new_enemy = Godot.create(Godot::Node2D)
    #   new_enemy.name = "OffThreadEnemy"
    #   parent_node.add_child(new_enemy) # CRASH: SceneTree race condition in engine child list!
    # end
    # ```
    #
    # ##### Good Code (Approach A — Channel to Main Thread):
    # ```
    # # GOOD: Compute off-thread, instantiate and add on Main Thread via Channel
    # class Spawner < Godot::Node
    #   @spawn_channel = Channel(String).new(10)
    #
    #   def spawn_async
    #     Thread.new do
    #       enemy_data = compute_enemy_stats()
    #       @spawn_channel.send(enemy_data)
    #     end
    #   end
    #
    #   def _process(delta : Float64)
    #     select
    #     when enemy_data = @spawn_channel.receive
    #       enemy = Godot.create(Godot::Node2D)
    #       enemy.name = enemy_data
    #       add_child(enemy) # SAFE: Executed on Godot Main Thread!
    #     else
    #       # No new spawn events this frame
    #     end
    #   end
    # end
    # ```
    #
    # ##### Good Code (Approach B — `call_deferred`):
    # ```
    # # GOOD: Use call_deferred to safely marshal node attachment to the Main Thread
    # Thread.new do
    #   new_enemy = Godot.create(Godot::Node2D)
    #   new_enemy.name = "DeferredEnemy"
    #   parent_node.call_deferred("add_child", new_enemy) # SAFE: Routed through thread-safe MessageQueue!
    # end
    # ```
    #
    # ---
    #
    # #### Anti-Pattern 2: Blocking `sleep` Inside a `spawn` Cooperative Fiber
    #
    # In standard standalone Crystal programs, `sleep` registers with the event loop. In Godot GDExtension,
    # Godot owns the main loop and does not pump Crystal's event loop. Calling `sleep(1.second)` inside a
    # fiber on the main thread causes the fiber to suspend indefinitely.
    #
    # ##### Bad Code:
    # ```
    # # BAD: Calling sleep inside a spawned fiber in GDExtension
    # spawn do
    #   Godot.print "Quest Step 1"
    #   sleep 2.seconds            # HANG: Crystal event loop is not pumped by Godot!
    #   Godot.print "Quest Step 2" # NEVER REACHED!
    # end
    # ```
    #
    # ##### Good Code:
    # ```
    # # GOOD: Use Godot's SceneTreeTimer or delta accumulators with Fiber.yield
    # class QuestSequencer < Godot::Node
    #   def start_quest
    #     spawn do
    #       Godot.print "Quest Step 1"
    #       timer = get_tree.create_timer(2.0)
    #       while timer.time_left > 0.0
    #         Fiber.yield # Cooperatively yield execution slices
    #       end
    #       Godot.print "Quest Step 2 reached safely!"
    #     end
    #   end
    #
    #   def _process(delta : Float64)
    #     Fiber.yield # Grant execution slices to spawned fibers each frame
    #   end
    # end
    # ```
    #
    # ---
    #
    # #### Anti-Pattern 3: Calling Fiber `sleep` Inside a Raw OS `Thread.new`
    #
    # In Crystal 1.20+, top-level `sleep` yields the current fiber to an `ExecutionContext`.
    # Raw OS threads created with `Thread.new` do not run inside an `ExecutionContext`, causing an
    # immediate runtime exception: `NilAssertionError: Fiber#execution_context cannot be nil`.
    #
    # ##### Bad Code:
    # ```
    # # BAD: Calling top-level sleep inside an OS thread
    # Thread.new do
    #   10.times do
    #     sleep 10.milliseconds # CRASH: NilAssertionError: Fiber#execution_context cannot be nil!
    #   end
    # end
    # ```
    #
    # ##### Good Code:
    # ```
    # # GOOD: Use Crystal::System::Thread.sleep for genuine OS thread sleeps
    # Thread.new do
    #   10.times do
    #     Crystal::System::Thread.sleep 10.milliseconds # SAFE: Native OS kernel sleep!
    #   end
    # end
    # ```
    #
    # ---
    #
    # #### Anti-Pattern 4: Unsynchronized Shared Mutable State Across Threads
    #
    # Crystal's standard `Hash` and `Array` collections are not thread-safe. Concurrent mutations
    # corrupt internal hash buckets, cause infinite loops, or trigger memory access violations.
    # Furthermore, using Crystal's standard `Mutex` alias (`Sync::Mutex`) from a raw thread fails under
    # contention because `Sync::Mutex` suspends fibers via `ExecutionContext`. Always use `::Thread::Mutex`.
    #
    # ##### Bad Code:
    # ```
    # # BAD: Modifying shared Hash from multiple threads without synchronization
    # class ScoreCache
    #   @@scores = Hash(String, Int32).new
    #
    #   def self.record(player_id : String, score : Int32)
    #     Thread.new do
    #       @@scores[player_id] = score # CORRUPTION: Data race on Hash buckets!
    #     end
    #   end
    # end
    # ```
    #
    # ##### Good Code:
    # ```
    # # GOOD: Protect shared mutable collections with ::Thread::Mutex
    # class ScoreCache
    #   @@scores = Hash(String, Int32).new
    #   @@mutex = ::Thread::Mutex.new # OS kernel mutex (CRITICAL_SECTION / pthread_mutex)
    #
    #   def self.record(player_id : String, score : Int32)
    #     Thread.new do
    #       @@mutex.synchronize do
    #         @@scores[player_id] = score # SAFE: Atomic and thread-safe!
    #       end
    #     end
    #   end
    #
    #   def self.get(player_id : String) : Int32?
    #     @@mutex.synchronize do
    #       @@scores[player_id]?
    #     end
    #   end
    # end
    # ```
    #
    # ---
    #
    # #### Anti-Pattern 5: Retaining Raw Pointers to Freed Engine Objects
    #
    # When a Godot object is destroyed (via GDScript `queue_free()`, `target.free()`, or engine scene reload),
    # the underlying C++ heap memory is deallocated. Calling methods on an unvalidated wrapper invokes
    # undefined behavior and native crashes (`0xC0000005`).
    #
    # ##### Bad Code:
    # ```
    # # BAD: Holding node references without checking engine liveness
    # class CombatTracker
    #   property cached_target : Godot::Node2D? = nil
    #
    #   def attack_target
    #     if target = @cached_target
    #       # If target was freed by GDScript via queue_free(), calling methods crashes!
    #       target.call("apply_damage", 25) # CRASH: ACCESS_VIOLATION / SIGSEGV!
    #     end
    #   end
    # end
    # ```
    #
    # ##### Good Code:
    # ```
    # # GOOD: Validate engine liveness with alive? or catch DisposedObjectError
    # class CombatTracker
    #   property cached_target : Godot::Node2D? = nil
    #
    #   def attack_target
    #     if target = @cached_target
    #       if target.alive? # Checks ObjectDB 64-bit instance validity in O(1)
    #         target.call("apply_damage", 25)
    #       else
    #         @cached_target = nil # Clean up dead reference
    #       end
    #     end
    #   rescue ex : Godot::DisposedObjectError
    #     Godot.print_warn "Target was disposed: #{ex.message}"
    #     @cached_target = nil
    #   end
    # end
    # ```
    #
    # ---
    #
    # ### 7. Awaiting Signals and Timers: The `await` Pattern
    #
    # In Godot, asynchronous sequencing for cutscenes, dialogue, animations, and cooldowns
    # is customarily performed using GDScript's `await` keyword.
    #
    # LibGodot provides a first-class, type-safe **`await`** system designed for Crystal's
    # cooperative fibers. It provides two fully supported signal awaiting styles:
    # 1. **First-Class Bound Signals (`await(enemy.died)` or `enemy.died.await`)**:
    #    Synthesized automatically by the `signal` macro and `Godot::Object#signal`. Provides compile-time checking,
    #    IDE auto-completion, and direct `.connect` / `.emit` methods.
    # 2. **Classic Target & String Identifier (`await(enemy, "died")` or `enemy.await_signal("died")`)**:
    #    The traditional Godot pattern. Indispensable when signal names are computed dynamically at runtime
    #    (e.g., from network RPC packets, configuration files, or GDScript dynamic events).
    # 3. **SceneTreeTimers (`await(timer.timeout)` or `await(timer)`)**.
    # 4. **Cooperative Durations (`await(2.5)` or `await(3.seconds)`)**.
    #
    # #### Comparison: GDScript vs. LibGodot Crystal
    #
    # <table>
    #   <thead>
    #     <tr>
    #       <th>Operation</th>
    #       <th>GDScript</th>
    #       <th>LibGodot Crystal</th>
    #     </tr>
    #   </thead>
    #   <tbody>
    #     <tr>
    #       <td><strong>Await Signal (Bound)</strong></td>
    #       <td><code>await target.died</code></td>
    #       <td><code>await(target.died)</code> or <code>target.died.await</code></td>
    #     </tr>
    #     <tr>
    #       <td><strong>Await Signal (Classic String)</strong></td>
    #       <td><code>await target.died</code></td>
    #       <td><code>await(target, "died")</code> or <code>target.await_signal("died")</code></td>
    #     </tr>
    #     <tr>
    #       <td><strong>Await with Arguments</strong></td>
    #       <td><code>var health = await player.health_changed</code></td>
    #       <td><code>args = await(player.health_changed)</code> or <code>await(player, "health_changed")</code></td>
    #     </tr>
    #     <tr>
    #       <td><strong>Await Timer</strong></td>
    #       <td><code>await get_tree().create_timer(2.0).timeout</code></td>
    #       <td><code>await(get_tree.create_timer(2.0).timeout)</code> or <code>await(timer)</code></td>
    #     </tr>
    #     <tr>
    #       <td><strong>Await Duration</strong></td>
    #       <td><code>await get_tree().create_timer(1.5).timeout</code></td>
    #       <td><code>await(1.5)</code> or <code>await(1.5.seconds)</code></td>
    #     </tr>
    #     <tr>
    #       <td><strong>Await with Timeout</strong></td>
    #       <td>Manual timer racing</td>
    #       <td><code>await(target.died, timeout_sec: 5.0)</code> or <code>await(target, "event", timeout_sec: 5.0)</code></td>
    #     </tr>
    #     <tr>
    #       <td><strong>Connect Directly</strong></td>
    #       <td><code>target.died.connect(...)</code></td>
    #       <td><code>target.died.connect { |args| ... }</code> or <code>target.connect("died", callback)</code></td>
    #     </tr>
    #   </tbody>
    # </table>
    #
    # ---
    #
    # #### Comprehensive Cutscene & Gameplay Example
    #
    # The following example demonstrates a Boss battle cinematic sequence authoring
    # cooperative fibers, signal emissions, timer awaits, and dead-pointer safety:
    #
    # ```
    # node BossFightController < Godot::Node do
    #   @[Export]
    #   property cutscene_speed : Float32 = 1.0_f32
    #
    #   signal battle_started
    #   signal battle_won
    #
    #   def _ready : Void
    #     # Launch cutscene sequence in a cooperative fiber
    #     spawn do
    #       run_intro_cinematic
    #     end
    #   end
    #
    #   def _process(delta : Float64) : Void
    #     # CRITICAL: Cooperatively yield execution slices each frame to advance awaiting fibers!
    #     Fiber.yield
    #   end
    #
    #   private def run_intro_cinematic : Void
    #     Godot.print("Cinematic starting: Camera pan...")
    #     # 1. Non-blocking delay: wait 2.0 seconds for camera transition
    #     await(2.0)
    #
    #     Godot.print("Spawn Boss entity...")
    #     boss = get_node_as(Godot::CharacterBody3D, "Boss")
    #
    #     # 2. Await a SceneTreeTimer via .timeout bound signal
    #     await(get_tree.create_timer(1.5).timeout)
    #     Godot.print("Boss roaring animation finished!")
    #
    #     emit_battle_started
    #
    #     # 3. Await custom signal on boss using first-class BoundSignal syntax
    #     begin
    #       Godot.print("Awaiting boss defeat signal...")
    #       # Returns Array(String) of signal arguments (e.g. loot drop ID, score)
    #       args = await(boss.boss_defeated, timeout_sec: 120.0)
    #       Godot.print("Victory! Boss dropped rewards: #{args}")
    #       emit_battle_won
    #     rescue ex : Godot::DisposedObjectError
    #       Godot.print_warn("Boss was prematurely destroyed: #{ex.message}")
    #     end
    #   end
    # end
    # ```
    #
    # ---
    #
    # #### Dead-Pointer Safety During `await`
    #
    # In dynamic multi-language games, an entity being awaited could be freed prematurely
    # by GDScript (e.g. `enemy.queue_free()`) or engine level unloading.
    #
    # LibGodot's `await` validates `#alive?` on every frame slice:
    # - If the target is destroyed while a fiber is awaiting its signal, `await` immediately raises
    #   `Godot::DisposedObjectError.new(target.instance_id)`.
    # - This guarantees that awaiting fibers **never hang indefinitely** on dead objects and cannot
    #   trigger native segmentation faults.
    #
    #
    module I_CONCURRENCY_FIBERS_AND_THREAD_SAFETY
      def self.best_practices : Array(String)
        [
          "Yield cooperatively (Fiber.yield) in _process to advance background fibers",
          "Use Channel(T) to marshal data from background worker threads to the main thread",
          "Never mutate SceneTree nodes (add_child/remove_child) from background threads",
          "Use call_deferred for cross-thread method dispatch to engine objects",
          "Avoid blocking sleep in fibers; prefer Godot SceneTreeTimer or delta accumulators",
          "Use Crystal::System::Thread.sleep for true OS thread sleeps inside Thread.new",
          "Protect shared Crystal state across threads with ::Thread::Mutex or Atomic primitives",
        ]
      end
    end
  end
end

