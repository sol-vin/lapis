module Godot
  # ===========================================================================
  # Thread Affinity & Concurrency Safety System
  # ===========================================================================
  # Godot's SceneTree is strictly single-threaded. Mutating node hierarchy
  # (add_child, remove_child, reparent, etc.) or SceneTree state off the Main
  # Thread corrupts Godot's internal child lists and causes unrecoverable crashes
  # (0xC0000005 ACCESS_VIOLATION).
  #
  # This module intercepts thread-sensitive operations, inspects native OS thread
  # IDs and Crystal Execution Contexts, and prevents illegal memory access before
  # any native C++ call occurs.

  # Exception raised whenever a thread-affinity invariant is violated.
  class ThreadAffinityError < Exception
    getter operation : String
    getter target_class : String
    getter calling_context : String
    getter target_node_name : String?
    getter? inside_tree : Bool

    def initialize(
      @operation : String,
      @target_class : String,
      @calling_context : String,
      node : Godot::Node? = nil
    )
      @inside_tree = false
      if node && node.alive?
        @target_node_name = (node.get_name rescue nil)
        @inside_tree = (node.is_inside_tree? rescue false)
      end

      msg = String.build do |sb|
        sb << "Thread Affinity Violation: Cannot execute '#{@target_class}##{@operation}' off the Main Thread.\n"
        sb << "  Calling Context : #{@calling_context}\n"
        if @target_node_name
          sb << "  Target Node     : '#{@target_node_name}' (inside SceneTree: #{@inside_tree})\n"
        end
        sb << "  Root Cause      : SceneTree hierarchy mutations are strictly single-threaded.\n"
        sb << "                    Executing SceneTree operations off-thread corrupts engine memory and child lists.\n"
        sb << "  Safe Remedies   :\n"
        sb << "    1. Defer call to the Main Thread: node.call_deferred(\"#{@operation}\", ...)\n"
        sb << "    2. Use safe helper: node.defer_#{@operation}(...)\n"
        sb << "    3. Send data across a buffered Channel(T) to be added on the Main Thread during _process(delta)\n"
        sb << "    4. Use Godot::ThreadSafety.run_on_main_thread { ... }\n"
      end
      super(msg)
    end
  end

  module ThreadSafety
    # Enforcement policy when an off-thread operation is detected:
    #   - Raise:    Immediately raise Godot::ThreadAffinityError (default, fail-fast)
    #   - Warn:     Log an error message to console/stderr, but allow execution to continue
    #   - Defer:    For supported operations, automatically dispatch via call_deferred
    #   - Disabled: Bypass checks entirely for micro-benchmarks or release builds
    enum Policy
      Raise
      Warn
      Defer
      Disabled
    end

    # Enforcement scope for hierarchy operations:
    #   - TreeOnly: (Default) Only blocks operations if the target or child is attached
    #               to the active SceneTree (is_inside_tree? == true). Allows assembling
    #               detached orphan node graphs off-thread before sending to Main Thread.
    #   - AllNodes: Strictly blocks hierarchy operations on ANY node off-thread.
    enum Scope
      TreeOnly
      AllNodes
    end

    class_property policy : Policy = Policy::Raise
    class_property scope : Scope = Scope::TreeOnly
    class_getter main_thread_id : UInt64 = 0_u64
    @@initialized : Bool = false

    # Thread-safe main thread dispatch queue
    @@main_thread_queue = Array(-> Void).new
    @@queue_mutex = ::Thread::Mutex.new

    # Records the current thread as Godot's Main Thread.
    def self.record_main_thread! : UInt64
      id = current_thread_id
      @@main_thread_id = id
      @@initialized = true
      id
    end

    # Explicitly overrides the main thread ID (for test fixtures).
    def self.main_thread_id=(id : UInt64)
      @@main_thread_id = id
      @@initialized = true
    end

    # Resets main thread tracking (primarily for isolated test fixtures).
    def self.reset! : Void
      @@main_thread_id = 0_u64
      @@initialized = false
      @@policy = Policy::Raise
      @@scope = Scope::TreeOnly
      @@queue_mutex.synchronize do
        @@main_thread_queue.clear
      end
    end

    # Fast query for native OS thread ID (~1ns, TLS segment register read)
    def self.current_thread_id : UInt64
      {% if flag?(:win32) %}
        LibC.GetCurrentThreadId.to_u64
      {% elsif flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) %}
        LibC.pthread_self.address.to_u64
      {% else %}
        LibC.pthread_self.to_u64
      {% end %}
    end

    # Returns true if current execution is on Godot's Main Thread
    def self.main_thread? : Bool
      {% if flag?(:no_thread_safety) || flag?(:disable_thread_safety) || flag?(:fast_dispatch) %}
        return true
      {% else %}
        # 1. Fast path: compare native OS thread ID against recorded Main Thread ID
        if @@initialized && @@main_thread_id > 0_u64
          return current_thread_id == @@main_thread_id
        end

        # 2. Engine query fallback if bridge is initialized
        if Godot::Bridge.init_done?
          if is_main = (Godot::Thread.is_main_thread? rescue nil)
            record_main_thread! if is_main
            return is_main
          end
        end

        # 3. Headless/spec boot default: the thread that first queries is treated as main thread
        record_main_thread!
        true
      {% end %}
    end

    # Detailed human-readable description of current thread & execution context
    def self.context_description : String
      os_id = current_thread_id
      f = Fiber.current
      ec = f.execution_context?
      ec_desc = case ec
      when nil
        "unmanaged OS thread (Thread.new, no ExecutionContext)"
      when Fiber::ExecutionContext::Parallel
        "Fiber::ExecutionContext::Parallel('#{ec.name}')"
      when Fiber::ExecutionContext::Concurrent
        "Fiber::ExecutionContext::Concurrent('#{ec.name}')"
      when Fiber::ExecutionContext::Isolated
        "Fiber::ExecutionContext::Isolated"
      else
        "#{ec.class.name}('#{ec.name}')"
      end
      "Fiber '#{f.name || "anonymous"}' in #{ec_desc} [OS Thread ID: #{os_id}]"
    end

    # Master assertion called before thread-sensitive operations
    def self.assert_main_thread!(
      operation : String,
      target_class : String,
      node : Godot::Node? = nil,
      child : Godot::Node? = nil
    ) : Void
      {% if flag?(:no_thread_safety) || flag?(:disable_thread_safety) || flag?(:fast_dispatch) %}
        # 0-cost no-op: thread safety checks bypassed for maximum speed
        return
      {% else %}
        return if @@policy.disabled?
        return if main_thread?

        # If scope is TreeOnly and a node is provided, only enforce if the target or child is attached to the active SceneTree
        if @@scope.tree_only? && node
          node_in_tree = node.alive? && (node.is_inside_tree? rescue false)
          child_in_tree = child && child.alive? && (child.is_inside_tree? rescue false)
          # If neither is in the active scene tree, this is a detached orphan graph operation (allowed)
          return unless node_in_tree || child_in_tree
        end

        case @@policy
        when .raise?
          raise ThreadAffinityError.new(operation, target_class, context_description, node)
        when .warn?
          Godot.printerr("[ThreadSafety] WARNING: '#{target_class}##{operation}' called off Main Thread!\n  Context: #{context_description}")
        when .defer?
          # Handled at call site if deferral is supported
        when .disabled?
        end
      {% end %}
    end

    # Schedules a block to execute on the Main Thread.
    # If already on the Main Thread, executes immediately.
    # If on a background thread, enqueues to the thread-safe dispatch queue.
    def self.run_on_main_thread(&block : -> Void) : Void
      if main_thread?
        block.call
      else
        @@queue_mutex.synchronize do
          @@main_thread_queue << block
        end
      end
    end

    # Flushes and executes all enqueued main thread actions.
    # Called by the main loop during frame updates.
    def self.flush_main_thread_queue! : Void
      return if @@main_thread_queue.empty?
      actions = nil
      @@queue_mutex.synchronize do
        return if @@main_thread_queue.empty?
        actions = @@main_thread_queue.dup
        @@main_thread_queue.clear
      end
      actions.try(&.each do |act|
        begin
          act.call
        rescue ex
          Godot.printerr("[ThreadSafety] Error in main thread queued action: #{ex.message}")
        end
      end)
    end
  end

  # Global convenience delegator
  def self.on_main_thread(&block : -> Void) : Void
    ThreadSafety.run_on_main_thread(&block)
  end
end
