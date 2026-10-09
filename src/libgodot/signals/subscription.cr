module Godot
  @[Flags]
  enum ConnectFlags : UInt32
    None             = 0_u32
    Deferred         = 1_u32
    Persist          = 2_u32
    OneShot          = 4_u32
    ReferenceCounted = 8_u32
  end

  # Represents an active signal subscription or awaiter
  class SignalSubscription
    getter target_id : UInt64
    getter signal_name : String
    getter flags : ConnectFlags
    getter? completed : Bool = false
    getter args : ::Array(Variant) = ::Array(Variant).new
    getter callback : Proc(::Array(Variant), Void)?
    property proc_pointer : Void* = Pointer(Void).null
    property proc_closure_data : Void* = Pointer(Void).null
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

    def unsubscribe : Void
      return if @unsubscribed
      @unsubscribed = true
      Godot.unsubscribe_signal(self)
    end

    # Idiomatic alias for `unsubscribe`
    def disconnect : Void
      unsubscribe
    end

    # Returns true if this subscription is still active and listening
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
    def connected? : Bool
      active?
    end
  end

  class_getter signal_subs = ::Hash(Tuple(UInt64, String), ::Array(SignalSubscription)).new
  class_getter signal_subs_mutex = ::Thread::Mutex.new

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

  # Cleans up all signal subscriptions associated with a target instance ID (as emitter or receiver)
  def self.clear_signal_subscriptions(target_id : UInt64) : Void
    return if target_id == 0
    signal_subs_mutex.synchronize do
      signal_subs.each_value do |list|
        list.reject! { |sub| sub.receiver_id == target_id }
      end
      signal_subs.reject! { |(tid, _), list| tid == target_id || list.empty? }
    end
  end

  # Notifies active subscribers that a signal has fired on an object
  def self.notify_signal(target_id : UInt64, signal_name : String, args : ::Array(Variant)) : Void
    return if target_id == 0
    key = {target_id, signal_name}
    subs_to_notify = nil
    signal_subs_mutex.synchronize do
      if list = signal_subs[key]?
        subs_to_notify = list.dup
      end
    end
    subs_to_notify.try(&.each(&.trigger(args)))
  end

  # Cooperatively awaits until the named signal is emitted on the target object.
  # Returns the emitted arguments as an Array(Variant).
  # If the target object is freed while awaiting, raises Godot::DisposedObjectError.
  def self.await(target : Godot::Object, signal_name : String, timeout_sec : Float64? = nil) : ::Array(Variant)
    target.check_alive!
    target_id = target.signal_target_id
    sub = subscribe_signal(target_id, signal_name)
    if !target.pointer.null? && target.instance_id > 0
      Bridge.object_connect_signal(target.pointer, signal_name)
    end
    start_time = ::Time.instant
    begin
      while !sub.completed?
        # Dead-pointer validation: fail fast if target was destroyed
        if !target.active?
          raise DisposedObjectError.new(target_id, "Target object was destroyed while awaiting signal '#{signal_name}'")
        end
        if timeout = timeout_sec
          if (::Time.instant - start_time).total_seconds >= timeout
            break
          end
        end
        Fiber.yield
      end
      sub.args
    ensure
      unsubscribe_signal(sub)
    end
  end

  # Cooperatively pauses execution for the given duration in seconds.
  # Safe for use in cooperative fibers without blocking the Godot main loop.
  def self.await(seconds : Number) : Void
    start_time = ::Time.instant
    target_sec = seconds.to_f64
    while (::Time.instant - start_time).total_seconds < target_sec
      Fiber.yield
    end
  end

  # Cooperatively pauses execution for the given Time::Span duration.
  def self.await(span : ::Time::Span) : Void
    await(span.total_seconds)
  end

  # Cooperatively pauses execution for the given duration in seconds.
  # Alias to `Godot.await(seconds)`.
  def self.delay(seconds : Number) : Void
    await(seconds)
  end

  # Cooperatively pauses execution for the given Time::Span duration.
  def self.delay(span : ::Time::Span) : Void
    await(span.total_seconds)
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
