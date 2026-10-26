module Godot
  @[Flags]
  enum ConnectFlags : UInt32
    None             = 0_u32
    Deferred         = 1_u32
    Persist          = 2_u32
    OneShot          = 4_u32
    ReferenceCounted = 8_u32
  end

  # Pre-allocated empty Variant array for zero-allocation parameterless signal dispatch.
  EMPTY_VARIANT_ARGS = [] of Variant

  # Re-entrancy guard when TypedSignal#emit dispatches through C++ Bridge.emit_signal.
  class_property? in_typed_emit : Bool = false

  # Represents an active signal subscription or awaiter
  class SignalSubscription
    getter target_id : UInt64
    getter signal_name : String
    getter flags : ConnectFlags
    getter? completed : Bool = false
    getter args : ::Array(Variant) = EMPTY_VARIANT_ARGS
    getter callback : Proc(::Array(Variant), Void)?
    property proc_pointer : Void* = Pointer(Void).null
    property proc_closure_data : Void* = Pointer(Void).null
    property? typed_fast_path : Bool = false
    property static_slot_token : UInt64 = 0_u64
    getter receiver : Godot::Object? = nil
    getter receiver_id : UInt64? = nil

    def initialize(
      @target_id : UInt64,
      @signal_name : String,
      @flags : ConnectFlags = ConnectFlags::None,
      @callback : Proc(::Array(Variant), Void)? = nil,
      @receiver : Godot::Object? = nil,
    )
      if recv = @receiver
        @receiver_id = recv.signal_target_id
      end
    end

    def trigger(signal_args : ::Array(Variant)) : Void
      if recv = @receiver
        unless recv.active?
          unsubscribe
          return
        end
      end
      @completed = true
      @args = signal_args
      if cb = @callback
        begin
          cb.call(signal_args)
        rescue ex
          Godot.printerr("[CrystalSignal] Error executing callback for '#{@signal_name}' on #{target_id}: #{ex.message}\n#{ex.backtrace.join("\n")}")
        ensure
          if @flags.includes?(ConnectFlags::OneShot)
            unsubscribe
          end
        end
      elsif @flags.includes?(ConnectFlags::OneShot)
        unsubscribe
      end
    end

    def string_args : ::Array(String)
      @args.map(&.to_s)
    end

    getter? unsubscribed : Bool = false
    getter? freed : Bool = false
    property waiting_fiber : Fiber? = nil

    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def mark_unsubscribed! : Void
      @unsubscribed = true
      @static_slot_token = 0_u64
    end

    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def mark_freed! : Void
      @freed = true
      @unsubscribed = true
      @static_slot_token = 0_u64
    end

    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def mark_completed! : Void
      @completed = true
    end

    def unsubscribe : Void
      return if @unsubscribed
      @unsubscribed = true
      if @static_slot_token != 0_u64
        tok = @static_slot_token
        @static_slot_token = 0_u64
        ::Lapis::Core::StaticSignalTable.global.unbind(tok)
      end
      Godot.unsubscribe_signal(self)
    end

    # Idiomatic alias for `unsubscribe`
    def disconnect : Void
      unsubscribe
    end

    # Returns true if this subscription is still active and listening
    @[ZeroAllocation]
    @[HotPath]
    def active? : Bool
      return false if @unsubscribed
      if recv = @receiver
        return false unless recv.active?
      end
      if @flags.includes?(ConnectFlags::OneShot)
        !@completed
      else
        true
      end
    end

    # Idiomatic alias for `active?`
    @[ZeroAllocation]
    @[HotPath]
    def connected? : Bool
      active?
    end
  end

  class_getter signal_subs = ::Hash(Tuple(UInt64, String), ::Array(SignalSubscription)).new
  class_getter signal_subs_mutex = ::Thread::Mutex.new
  class_property awaiting_fiber_count : Int32 = 0
  @@last_await_pump_frame : Int64 = -1_i64
  @@pending_freed_wait_subs = ::Array(SignalSubscription).new

  # Yields on the Main Thread until all recently freed awaiting subscriptions have woken up and exited `await`.
  def self.wake_freed_awaiters! : Void
    return if @@in_typed_emit
    cur_fiber = Fiber.current
    return unless Godot::ThreadSafety.main_thread? && cur_fiber.execution_context?
    wait_subs : ::Array(SignalSubscription)? = nil
    signal_subs_mutex.synchronize do
      unless @@pending_freed_wait_subs.empty?
        wait_subs = @@pending_freed_wait_subs.dup
        @@pending_freed_wait_subs.clear
      end
    end
    return unless subs = wait_subs
    spins = 0
    while spins < 128 && subs.any? { |s| (wf = s.waiting_fiber) && wf != cur_fiber && !wf.dead? }
      Fiber.yield
      spins += 1
    end
    3.times { Fiber.yield }
  end

  # Cooperatively yields once per engine process frame if any fibers are actively awaiting signals.
  def self.pump_awaiting_fibers_once_per_frame! : Void
    return if @@awaiting_fiber_count <= 0 && @@pending_freed_wait_subs.empty?
    return if @@in_typed_emit
    return unless Godot::ThreadSafety.main_thread? && Fiber.current.execution_context?
    unless @@pending_freed_wait_subs.empty?
      wake_freed_awaiters!
      return
    end
    frame = process_frame_count
    if frame <= 0_i64 || frame != @@last_await_pump_frame
      @@last_await_pump_frame = frame if frame > 0_i64
      Fiber.yield
    end
  end

  # Subscribes an awaiter or callback to a signal on a target object instance ID
  def self.subscribe_signal(
    target_id : UInt64,
    signal_name : String,
    flags : ConnectFlags = ConnectFlags::None,
    callback : Proc(::Array(Variant), Void)? = nil,
    receiver : Godot::Object? = nil,
  ) : SignalSubscription
    sub = SignalSubscription.new(target_id, signal_name, flags, callback, receiver)
    key = {target_id, signal_name}
    signal_subs_mutex.synchronize do
      list = signal_subs[key] ||= ::Array(SignalSubscription).new
      list << sub
    end
    sub
  end

  # Unsubscribes a signal subscription
  def self.unsubscribe_signal(sub : SignalSubscription) : Void
    key = {sub.target_id, sub.signal_name}
    signal_subs_mutex.synchronize do
      if list = signal_subs[key]?
        list.delete(sub)
        signal_subs.delete(key) if list.empty?
      end
    end
  end

  # Cleans up all signal subscriptions associated with a target instance ID (as emitter or receiver).
  # Marks emitter subscriptions as freed and optionally yields on the Main Thread so awaiting fibers unblock immediately.
  def self.clear_signal_subscriptions(target_id : UInt64, yield_awaiters : Bool = true) : Void
    return if target_id == 0
    ::Lapis::Core::StaticSignalTable.global.clear_emitter(target_id)
    cur_fiber = Fiber.current
    signal_subs_mutex.synchronize do
      signal_subs.each_value do |list|
        list.reject! do |sub|
          if sub.receiver_id == target_id
            sub.mark_unsubscribed!
            true
          else
            false
          end
        end
      end
      signal_subs.reject! do |(tid, _), list|
        if tid == target_id
          list.each do |sub|
            if (wf = sub.waiting_fiber) && wf != cur_fiber && !wf.dead?
              @@pending_freed_wait_subs << sub
            end
            sub.mark_freed!
          end
          true
        else
          list.empty?
        end
      end
    end
    if yield_awaiters
      wake_freed_awaiters!
    end
  end

  # Marks all non-teardown signal subscriptions on a node queued for deletion (`queue_free`) as freed
  # and yields on the Main Thread so awaiting fibers unblock immediately without waiting for frame end.
  def self.notify_object_queued_for_deletion(target_id : UInt64, yield_awaiters : Bool = true) : Void
    return if target_id == 0
    cur_fiber = Fiber.current
    signal_subs_mutex.synchronize do
      signal_subs.reject! do |(tid, sig_name), list|
        if tid == target_id && sig_name != "tree_exiting" && sig_name != "tree_exited"
          list.each do |sub|
            if (wf = sub.waiting_fiber) && wf != cur_fiber && !wf.dead?
              @@pending_freed_wait_subs << sub
            end
            sub.mark_freed!
          end
          true
        else
          list.empty?
        end
      end
    end
    if yield_awaiters
      wake_freed_awaiters!
    end
  end

  # Returns true if `(target_id, signal_name)` has any active `SignalSubscription` listeners.
  @[ZeroAllocation]
  @[HotPath]
  def self.has_signal_subscribers?(target_id : UInt64, signal_name : String) : Bool
    return false if target_id == 0_u64 || @@signal_subs.empty?
    key = {target_id, signal_name}
    if list = @@signal_subs[key]?
      i = 0
      n = list.size
      while i < n
        return true if list.unsafe_fetch(i).active?
        i += 1
      end
    end
    false
  end

  # Returns true if `(target_id, signal_name)` has any active untyped `BoundSignal` / `await` listeners.
  @[ZeroAllocation]
  @[HotPath]
  def self.has_untyped_signal_subscribers?(target_id : UInt64, signal_name : String) : Bool
    return false if target_id == 0_u64 || @@signal_subs.empty?
    key = {target_id, signal_name}
    if list = @@signal_subs[key]?
      i = 0
      n = list.size
      while i < n
        sub = list.unsafe_fetch(i)
        return true if !sub.typed_fast_path? && sub.active?
        i += 1
      end
    end
    false
  end

  # Notifies active subscribers that a signal has fired on an object.
  # Uses a stack-allocated StaticArray snapshot for <= 64 listeners (zero heap allocations).
  def self.notify_signal(target_id : UInt64, signal_name : String, args : ::Array(Variant) = EMPTY_VARIANT_ARGS) : Void
    return if target_id == 0_u64 || @@signal_subs.empty?
    key = {target_id, signal_name}
    snap = uninitialized StaticArray(SignalSubscription, 64)
    snap_count = 0
    overflow = nil
    signal_subs_mutex.synchronize do
      if list = signal_subs[key]?
        n = list.size
        if n <= 64
          i = 0
          while i < n
            s = list.unsafe_fetch(i)
            if s.active?
              snap.to_unsafe[snap_count] = s
              snap_count += 1
            end
            i += 1
          end
        else
          overflow = list.dup
        end
      end
    end
    if ov = overflow
      ov.each(&.trigger(args))
    else
      idx = 0
      while idx < snap_count
        snap.to_unsafe[idx].trigger(args)
        idx += 1
      end
    end
  end

  # Notifies only untyped `BoundSignal` / `await` subscribers when a `TypedSignal` has already
  # dispatched all typed fast-path subscribers through `StaticSignalTable`.
  def self.notify_untyped_signal(target_id : UInt64, signal_name : String, args : ::Array(Variant) = EMPTY_VARIANT_ARGS) : Void
    return if target_id == 0_u64 || @@signal_subs.empty?
    key = {target_id, signal_name}
    snap = uninitialized StaticArray(SignalSubscription, 64)
    snap_count = 0
    overflow = nil
    signal_subs_mutex.synchronize do
      if list = signal_subs[key]?
        n = list.size
        if n <= 64
          i = 0
          while i < n
            s = list.unsafe_fetch(i)
            if !s.typed_fast_path? && s.active?
              snap.to_unsafe[snap_count] = s
              snap_count += 1
            end
            i += 1
          end
        else
          overflow = list.reject(&.typed_fast_path?)
        end
      end
    end
    if ov = overflow
      ov.each(&.trigger(args))
    else
      idx = 0
      while idx < snap_count
        snap.to_unsafe[idx].trigger(args)
        idx += 1
      end
    end
  end

  # Status enum representing the completion outcome of an asynchronous await operation.
  enum AwaitState
    Completed
    TimedOut
    Freed

    # Returns true if the operation completed successfully without timing out or being freed.
    def completed? : Bool
      self == Completed
    end

    # Returns true if the operation timed out.
    def timed_out? : Bool
      self == TimedOut
    end

    # Returns true if the target object was freed/disposed before or during the wait.
    def freed? : Bool
      self == Freed
    end

    # Alias to `freed?`.
    def disposed? : Bool
      self == Freed
    end

    # Alias to `completed?`.
    def ok? : Bool
      self == Completed
    end
  end

  # Zero-allocation status wrapper carrying completion state and optional unboxed value.
  # Provides `.completed?`, `.timed_out?`, `.freed?`, `.disposed?`, `.ok?`, `.status`, `.value`, `.value!`, `.value?`,
  # and delegates element access and methods to the underlying value.
  struct AwaitStatus(T)
    getter status : AwaitState
    getter value : T?
    getter instance_id : UInt64

    def initialize(@status : AwaitState, @value : T? = nil, @instance_id : UInt64 = 0_u64)
    end

    # Returns true if the operation completed successfully without timing out or being freed.
    def completed? : Bool
      @status.completed?
    end

    # Returns true if the operation timed out.
    def timed_out? : Bool
      @status.timed_out?
    end

    # Returns true if the target object was freed/disposed before or during the wait.
    def freed? : Bool
      @status.freed?
    end

    # Alias to `freed?`.
    def disposed? : Bool
      @status.disposed?
    end

    # Alias to `completed?`.
    def ok? : Bool
      @status.completed?
    end

    # Returns the unwrapped value of type T if completed, or raises `Godot::DisposedObjectError` if freed
    # or `Godot::TimeoutError` if timed out.
    def value! : T
      if freed?
        {% if flag?(:trace_dead_pointers) %}
          msg = ::Godot::TombstoneTracker.format_disposed_message(@instance_id)
          raise DisposedObjectError.new(@instance_id, msg)
        {% else %}
          raise DisposedObjectError.new(@instance_id, "Target object was destroyed while awaiting signal or timer")
        {% end %}
      elsif timed_out?
        raise TimeoutError.new("Timed out while awaiting signal or timer")
      end
      @value.as(T)
    end

    # Returns the value if completed, or nil if timed out or freed.
    def value? : T?
      @value
    end

    # Factory constructors
    def self.completed(value : T? = nil) : self
      new(AwaitState::Completed, value)
    end

    def self.timed_out : self
      new(AwaitState::TimedOut, nil)
    end

    def self.freed(instance_id : UInt64 = 0_u64) : self
      new(AwaitState::Freed, nil, instance_id)
    end

    def self.disposed(instance_id : UInt64 = 0_u64) : self
      new(AwaitState::Freed, nil, instance_id)
    end

    # Equality comparisons for state, symbols, and values
    def ==(other : AwaitState) : Bool
      @status == other
    end

    def ==(other : Symbol) : Bool
      case other
      when :completed        then completed?
      when :timed_out        then timed_out?
      when :freed, :disposed then freed?
      else                        false
      end
    end

    def ==(other : T) : Bool
      @value == other
    end

    # Index delegation for Tuple / Array destructuring:
    # Allows `a, b = status` when T is an Indexable or Tuple!
    def [](index : Int)
      val = value!
      if val.is_a?(Indexable) || val.is_a?(Tuple)
        val[index]
      else
        raise IndexError.new("Cannot index #{T} in AwaitStatus")
      end
    end

    def to_s(io : IO) : Void
      io << "AwaitStatus(" << @status << ", value: " << @value.inspect << ")"
    end

    forward_missing_to value!
  end

  # Cooperatively awaits until the named signal is emitted on the target object.
  # Returns an `AwaitStatus(Array(Variant))` indicating completion, timeout, or object disposal (`freed?`).
  def self.await(target : Godot::Object, signal_name : String, timeout_sec : Float64? = nil) : AwaitStatus(::Array(Variant))
    target_id = target.signal_target_id
    check_queued_delete = (signal_name != "tree_exiting" && signal_name != "tree_exited")
    if !target.active? || (check_queued_delete && target.queued_for_deletion_fast?)
      return AwaitStatus(::Array(Variant)).freed(target_id)
    end
    sub = subscribe_signal(target_id, signal_name)
    sub.waiting_fiber = Fiber.current
    @@awaiting_fiber_count += 1
    if !target.pointer.null? && target.instance_id > 0
      Bridge.object_connect_signal(target.pointer, signal_name)
    end
    start_time = ::Time.instant
    timed_out = false
    freed = false
    begin
      while !sub.completed? && !sub.freed?
        # Dead-pointer and queue_free validation: unblock immediately if target was destroyed or queued for deletion
        if !target.active? || (check_queued_delete && Godot::ThreadSafety.main_thread? && target.queued_for_deletion_fast?)
          freed = true
          break
        end
        if timeout = timeout_sec
          if (::Time.instant - start_time).total_seconds >= timeout
            timed_out = true
            break
          end
        end
        Fiber.yield
      end
      if sub.completed?
        AwaitStatus(::Array(Variant)).completed(sub.args)
      elsif freed || sub.freed? || !target.active?
        AwaitStatus(::Array(Variant)).freed(target_id)
      elsif timed_out
        AwaitStatus(::Array(Variant)).timed_out
      else
        AwaitStatus(::Array(Variant)).completed(sub.args)
      end
    ensure
      unsubscribe_signal(sub)
      @@awaiting_fiber_count -= 1 if @@awaiting_fiber_count > 0
      sub.waiting_fiber = nil
    end
  end

  def self.await(target : Godot::Object, signal_name : String, timeout_sec : Number) : AwaitStatus(::Array(Variant))
    await(target, signal_name, timeout_sec.to_f64)
  end

  # Cooperatively awaits until the named signal is emitted on the target object.
  # Returns the emitted arguments as `Array(Variant)`, or raises `Godot::DisposedObjectError` if the target is freed,
  # or `Godot::TimeoutError` if `timeout_sec` expires.
  def self.await!(target : Godot::Object, signal_name : String, timeout_sec : Float64? = nil) : ::Array(Variant)
    status = await(target, signal_name, timeout_sec)
    if status.freed?
      {% if flag?(:trace_dead_pointers) %}
        msg = ::Godot::TombstoneTracker.format_disposed_message(status.instance_id)
        raise DisposedObjectError.new(status.instance_id, msg)
      {% else %}
        raise DisposedObjectError.new(status.instance_id, "Target object was destroyed while awaiting signal '#{signal_name}'")
      {% end %}
    elsif status.timed_out?
      raise TimeoutError.new("Timed out awaiting signal '#{signal_name}' on #{target.class.name} after #{timeout_sec}s")
    end
    status.value!
  end

  def self.await!(target : Godot::Object, signal_name : String, timeout_sec : Number) : ::Array(Variant)
    await!(target, signal_name, timeout_sec.to_f64)
  end

  # Cooperatively awaits until the named signal is emitted on the target object.
  # Returns the emitted arguments as `Array(Variant)?`, or `nil` if `timeout_sec` expires or the target is freed.
  def self.await?(target : Godot::Object, signal_name : String, timeout_sec : Float64? = nil) : ::Array(Variant)?
    status = await(target, signal_name, timeout_sec)
    status.value?
  end

  def self.await?(target : Godot::Object, signal_name : String, timeout_sec : Number) : ::Array(Variant)?
    await?(target, signal_name, timeout_sec.to_f64)
  end

  # Cooperatively pauses execution for the given duration in seconds.
  # Returns `AwaitStatus(Nil)` indicating completion or timeout.
  # Safe for use in cooperative fibers without blocking the Godot main loop.
  def self.await(seconds : Number, timeout_sec : Float64? = nil) : AwaitStatus(Nil)
    start_time = ::Time.instant
    target_sec = seconds.to_f64
    timed_out = false
    while (elapsed = (::Time.instant - start_time).total_seconds) < target_sec
      if timeout = timeout_sec
        if elapsed >= timeout
          timed_out = true
          break
        end
      end
      Fiber.yield
    end
    timed_out ? AwaitStatus(Nil).timed_out : AwaitStatus(Nil).completed
  end

  def self.await(seconds : Number, timeout_sec : Number) : AwaitStatus(Nil)
    await(seconds, timeout_sec.to_f64)
  end

  # Cooperatively pauses execution for the given duration in seconds.
  # Raises `Godot::TimeoutError` if `timeout_sec` expires before the delay completes.
  def self.await!(seconds : Number, timeout_sec : Float64? = nil) : Void
    status = await(seconds, timeout_sec)
    if status.timed_out?
      raise TimeoutError.new("Timed out after #{timeout_sec}s awaiting delay of #{seconds}s")
    end
  end

  def self.await!(seconds : Number, timeout_sec : Number) : Void
    await!(seconds, timeout_sec.to_f64)
  end

  # Cooperatively pauses execution for the given duration in seconds.
  # Returns `true` if the delay completed, or `false` if `timeout_sec` expired.
  def self.await?(seconds : Number, timeout_sec : Float64? = nil) : Bool
    status = await(seconds, timeout_sec)
    status.completed?
  end

  def self.await?(seconds : Number, timeout_sec : Number) : Bool
    await?(seconds, timeout_sec.to_f64)
  end

  # Cooperatively pauses execution for the given Time::Span duration.
  def self.await(span : ::Time::Span, timeout_sec : Float64? = nil) : AwaitStatus(Nil)
    await(span.total_seconds, timeout_sec)
  end

  def self.await(span : ::Time::Span, timeout_sec : Number) : AwaitStatus(Nil)
    await(span.total_seconds, timeout_sec.to_f64)
  end

  def self.await!(span : ::Time::Span, timeout_sec : Float64? = nil) : Void
    await!(span.total_seconds, timeout_sec)
  end

  def self.await!(span : ::Time::Span, timeout_sec : Number) : Void
    await!(span.total_seconds, timeout_sec.to_f64)
  end

  def self.await?(span : ::Time::Span, timeout_sec : Float64? = nil) : Bool
    await?(span.total_seconds, timeout_sec)
  end

  def self.await?(span : ::Time::Span, timeout_sec : Number) : Bool
    await?(span.total_seconds, timeout_sec.to_f64)
  end

  # Cooperatively pauses execution for the given duration in seconds.
  # Alias to `Godot.await(seconds)`.
  def self.delay(seconds : Number, timeout_sec : Float64? = nil) : AwaitStatus(Nil)
    await(seconds, timeout_sec)
  end

  def self.delay(seconds : Number, timeout_sec : Number) : AwaitStatus(Nil)
    await(seconds, timeout_sec.to_f64)
  end

  def self.delay!(seconds : Number, timeout_sec : Float64? = nil) : Void
    await!(seconds, timeout_sec)
  end

  def self.delay!(seconds : Number, timeout_sec : Number) : Void
    await!(seconds, timeout_sec.to_f64)
  end

  def self.delay?(seconds : Number, timeout_sec : Float64? = nil) : Bool
    await?(seconds, timeout_sec)
  end

  def self.delay?(seconds : Number, timeout_sec : Number) : Bool
    await?(seconds, timeout_sec.to_f64)
  end

  # Cooperatively pauses execution for the given Time::Span duration.
  def self.delay(span : ::Time::Span, timeout_sec : Float64? = nil) : AwaitStatus(Nil)
    await(span.total_seconds, timeout_sec)
  end

  def self.delay(span : ::Time::Span, timeout_sec : Number) : AwaitStatus(Nil)
    await(span.total_seconds, timeout_sec.to_f64)
  end

  def self.delay!(span : ::Time::Span, timeout_sec : Float64? = nil) : Void
    await!(span.total_seconds, timeout_sec)
  end

  def self.delay!(span : ::Time::Span, timeout_sec : Number) : Void
    await!(span.total_seconds, timeout_sec.to_f64)
  end

  def self.delay?(span : ::Time::Span, timeout_sec : Float64? = nil) : Bool
    await?(span.total_seconds, timeout_sec)
  end

  def self.delay?(span : ::Time::Span, timeout_sec : Number) : Bool
    await?(span.total_seconds, timeout_sec.to_f64)
  end

  # Spawns a cooperative gameplay fiber with managed exception logging.
  def self.spawn(&block : -> Void) : Fiber
    ::spawn do
      begin
        block.call
      rescue ex
        Godot.printerr("[LibGodot Fiber Error] #{ex.message}\n#{ex.backtrace.join("\n")}")
      end
    end
  end

  @@mb_engine_get_process_frames : Void* = Pointer(Void).null
  @@mb_engine_get_physics_frames : Void* = Pointer(Void).null

  # Returns the total number of frames rendered since the engine started.
  def self.process_frame_count : Int64
    engine = Bridge.get_singleton("Engine")
    return 0_i64 if engine.null?
    if @@mb_engine_get_process_frames.null?
      @@mb_engine_get_process_frames = Bridge.get_method_bind("Engine", "get_process_frames", 3905245786_i64)
    end
    ret = 0_i64
    Bridge.ptrcall(@@mb_engine_get_process_frames, engine, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
    ret
  end

  # Returns the total number of physics process steps executed since the engine started.
  def self.physics_frame_count : Int64
    engine = Bridge.get_singleton("Engine")
    return 0_i64 if engine.null?
    if @@mb_engine_get_physics_frames.null?
      @@mb_engine_get_physics_frames = Bridge.get_method_bind("Engine", "get_physics_frames", 3905245786_i64)
    end
    ret = 0_i64
    Bridge.ptrcall(@@mb_engine_get_physics_frames, engine, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
    ret
  end

  # Cooperatively yields until the next process (render/idle) frame has completed.
  # Includes an optional timeout (default: 5.0s) to prevent deadlock if frames are not advancing.
  def self.next_frame(timeout_sec : Float64? = 5.0) : Void
    start_frame = process_frame_count
    start_time = ::Time.instant
    if start_frame > 0
      while process_frame_count == start_frame
        if timeout = timeout_sec
          if (::Time.instant - start_time).total_seconds >= timeout
            break
          end
        end
        Fiber.yield
      end
    else
      Fiber.yield
    end
  end

  # Cooperatively yields until the next physics process frame has completed.
  # Includes an optional timeout (default: 5.0s) to prevent deadlock if physics frames are not advancing.
  def self.physics_frame(timeout_sec : Float64? = 5.0) : Void
    start_frame = physics_frame_count
    start_time = ::Time.instant
    if start_frame > 0
      while physics_frame_count == start_frame
        if timeout = timeout_sec
          if (::Time.instant - start_time).total_seconds >= timeout
            break
          end
        end
        Fiber.yield
      end
    else
      Fiber.yield
    end
  end

  # Wildcard type filter for signal connections and type queries
  alias Any = VariantValue
end
