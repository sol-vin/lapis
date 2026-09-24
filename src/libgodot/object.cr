require "./types"

module Godot
  # Returns true if the code is currently executing inside the Godot Editor
  def self.editor_hint? : Bool
    engine = Bridge.get_singleton("Engine")
    return false if engine.null?
    mb = Bridge.get_method_bind("Engine", "is_editor_hint", 36873697_i64)
    return false if mb.null?
    ret = 0_u8
    Bridge.ptrcall(mb, engine, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
    ret != 0_u8
  end

  # Converts any filesystem or relative path to a normalized Godot res:// path
  def self.to_godot_res_path(path : String) : String
    return "" if path.empty?
    p = path.gsub('\\', '/')
    return p if p.starts_with?("res://")

    if !Godot::ProjectSettings.singleton_ptr.null?
      ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
      localized = ps.call_str("localize_path", p)
      return localized if localized.starts_with?("res://") && localized != "res://" && localized != "res:///"
    end

    if idx = p.index("/src/")
      return "res:/" + p[idx..-1]
    elsif idx = p.index("/addons/")
      return "res:/" + p[idx..-1]
    elsif idx = p.index("/scripts/")
      return "res:/" + p[idx..-1]
    elsif p.starts_with?("src/") || p.starts_with?("addons/") || p.starts_with?("scripts/")
      return "res://#{p}"
    end

    bname = File.basename(p)
    bname.empty? ? "" : "res://#{bname}"
  end

  # Preloads/loads a resource from the given path (convenience alias to Godot.load)
  def self.preload(path : String) : Resource
    self.load(path)
  end

  # Constructs a new native Godot engine object of the given class name (e.g. "Node2D", "MeshInstance3D", "BoxMesh")
  def self.create(class_name : String) : Node?
    ptr = Bridge.construct_object(class_name)
    return nil if ptr.null?
    Node.new(ptr)
  end

  # Constructs a new native Godot engine object and wraps it in the given Crystal class
  def self.create(type : T.class) : T forall T
    class_name = {{ T.name.stringify.split("::").last }}
    ptr = Bridge.construct_object(class_name)
    if inst = Bridge.find_alive_instance(ptr)
      if casted = inst.as?(T)
        if casted.is_a?(RefCounted) && casted.get_reference_count == 0
          casted.init_ref
        end
        return casted
      end
    end
    res = T.new(ptr)
    if res.is_a?(RefCounted) && res.get_reference_count == 0
      res.init_ref
    end
    res
  end

  # Raised when an operation is attempted on a Godot Object that has been deleted or freed.
  class DisposedObjectError < Exception
    getter instance_id : UInt64

    def initialize(@instance_id : UInt64 = 0_u64, msg : String? = nil)
      message = msg || "Attempted to operate on a deleted or freed Godot Object (instance ID: #{@instance_id})\n💡 Hint: Check '#alive?' or '#if_alive' before accessing transient nodes, or use 'node.queue_free' instead of manual free."
      super(message)
    end
  end

  # Raised when an asynchronous operation or await condition exceeds its configured timeout duration.
  class TimeoutError < Exception
  end

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

    def initialize(
      @target_id : UInt64,
      @signal_name : String,
      @flags : ConnectFlags = ConnectFlags::None,
      @callback : Proc(::Array(Variant), Void)? = nil,
    )
    end

    def trigger(signal_args : ::Array(Variant)) : Void
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
  ) : SignalSubscription
    sub = SignalSubscription.new(target_id, signal_name, flags, callback)
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

  # Cleans up all signal subscriptions associated with a target instance ID
  def self.clear_signal_subscriptions(target_id : UInt64) : Void
    return if target_id == 0
    signal_subs_mutex.synchronize do
      signal_subs.reject! { |(tid, _), _| tid == target_id }
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
        if !target.alive?
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
  def self.next_frame : Void
    start_frame = process_frame_count
    if start_frame > 0
      while process_frame_count == start_frame
        Fiber.yield
      end
    else
      Fiber.yield
    end
  end

  # Cooperatively yields until the next physics process frame has completed.
  def self.physics_frame : Void
    start_frame = physics_frame_count
    if start_frame > 0
      while physics_frame_count == start_frame
        Fiber.yield
      end
    else
      Fiber.yield
    end
  end

  # Represents a signal bound to a specific Godot object instance.
  # Enables first-class signal handling, inspection, connection, emission, and non-blocking `await`.
  #
  # Examples:
  # ```
  # await(enemy.died)
  # await(enemy.died, timeout_sec: 2.0)
  # enemy.died.await
  # enemy.health_changed.connect { |cur, max| puts "Health: #{cur}/#{max}" }
  # ```
  class BoundSignal
    getter target : Godot::Object
    getter name : String

    def initialize(@target : Godot::Object, @name : String)
    end

    # Returns the target's 64-bit instance ID (or Crystal object_id for unparented Crystal nodes)
    def target_id : UInt64
      @target.signal_target_id
    end

    # Returns true if the bound object is still alive in ObjectDB
    def alive? : Bool
      @target.alive?
    end

    # Cooperatively awaits this signal without blocking the engine main loop.
    # Returns the emitted arguments as an Array(Variant).
    def await(timeout_sec : Float64? = nil) : ::Array(Variant)
      Godot.await(@target, @name, timeout_sec)
    end

    # Cooperatively awaits this signal with timeout in seconds
    def await(timeout_sec : Number) : ::Array(Variant)
      Godot.await(@target, @name, timeout_sec.to_f64)
    end

    # Connects a callback proc to this signal
    def connect(flags : ConnectFlags = ConnectFlags::None, callback : Proc(::Array(Variant), Void)? = nil) : SignalSubscription
      @target.connect(@name, flags, callback)
    end

    # Connects a callback block to this signal (supports 1-arg `|args|` and 0-arg blocks)
    def connect(flags : ConnectFlags = ConnectFlags::None, &block : ::Array(Variant) -> Void) : SignalSubscription
      @target.connect(@name, flags, &block)
    end

    # Backwards-compatibility helper redirecting to ConnectFlags::OneShot
    def connect_one_shot(&block : ::Array(Variant) -> Void) : SignalSubscription
      connect(flags: ConnectFlags::OneShot, &block)
    end

    # Idiomatic shorthand alias for `connect_one_shot`
    def once(&block : ::Array(Variant) -> Void) : SignalSubscription
      connect(flags: ConnectFlags::OneShot, &block)
    end

    # Operator `<<` syntactic sugar for `connect` with a block
    def <<(&block : ::Array(Variant) -> Void) : SignalSubscription
      connect(&block)
    end

    # Operator `<<` syntactic sugar for `connect` with a Proc
    def <<(proc : Proc(::Array(Variant), R)) : SignalSubscription forall R
      connect do |args|
        proc.call(args)
      end
    end

    # Operator `<<` syntactic sugar for `connect` with a 0-argument Proc
    def <<(proc : Proc(R)) : SignalSubscription forall R
      connect do
        proc.call
      end
    end

    # Connects this signal to a method call on a target object by symbol name
    def connect(listener_target : Godot::Object, method_name : Symbol, flags : ConnectFlags = ConnectFlags::None) : SignalSubscription
      @target.connect(@name, flags) do |_args|
        listener_target.call(method_name.to_s)
      end
    end

    # Disconnects all active subscriptions for this signal on the target
    def disconnect : Void
      @target.disconnect(@name)
    end

    # Emits this signal on the target object
    def emit(*args) : Void
      @target.emit_signal(@name, *args)
    end

    # Returns the count of active subscriptions for this signal
    def connection_count : Int32
      @target.signal_connection_count(@name)
    end

    # Returns true if this signal currently has any active subscribers
    def connected? : Bool
      connection_count > 0
    end

    # Alias to `connected?`
    def has_connections? : Bool
      connected?
    end

    def to_s(io : IO) : Void
      io << "#<Godot::BoundSignal @" << @name << " on " << @target.class.name << " (id: " << target_id << ")>"
    end
  end

  # Strongly-typed signal binding offering compile-time type safety for signal connections and await.
  class TypedSignal(*T) < BoundSignal
    # Type-safe connect with automatic unboxing into block parameters
    def connect(flags : ConnectFlags = ConnectFlags::None, &block : *T -> Void) : SignalSubscription
      cb = block
      @target.connect(@name, flags) do |args|
        {% begin %}
          {% if T.size == 0 %}
            cb.call
          {% else %}
            cb.call(
              {% for i in 0...T.size %}
                (if (arg = args[{{i}}]?)
                  arg.as_t(T[{{i}}])
                else
                  Variant.default_for(T[{{i}}])
                end),
              {% end %}
            )
          {% end %}
        {% end %}
      end
    end

    # Backwards-compatibility helper redirecting to ConnectFlags::OneShot
    def connect_one_shot(&block : *T -> Void) : SignalSubscription
      connect(flags: ConnectFlags::OneShot, &block)
    end

    # Idiomatic shorthand alias for `connect_one_shot`
    def once(&block : *T -> Void) : SignalSubscription
      connect(flags: ConnectFlags::OneShot, &block)
    end

    # Operator `<<` syntactic sugar for type-safe connect with a block
    def <<(&block : *T -> Void) : SignalSubscription
      connect(&block)
    end

    # Operator `<<` syntactic sugar for type-safe connect with a Proc
    def <<(proc : Proc(*T, R)) : SignalSubscription forall R
      connect do |*args|
        proc.call(*args)
      end
    end

    # Operator `<<` syntactic sugar for 0-argument Proc
    def <<(proc : Proc(R)) : SignalSubscription forall R
      connect do
        proc.call
      end
    end

    # Emits this typed signal with compile-time type safety matching the signal declaration
    def emit(*args : *T) : Void
      @target.emit_signal(@name, *args)
    end

    # Cooperatively awaits this typed signal returning unboxed values or tuple
    def await(timeout_sec : Float64? = nil)
      args = Godot.await(@target, @name, timeout_sec)
      {% begin %}
        {% if T.size == 0 %}
          nil
        {% elsif T.size == 1 %}
          if (arg = args[0]?)
            arg.as_t(T[0])
          else
            Variant.default_for(T[0])
          end
        {% else %}
          {
            {% for i in 0...T.size %}
              (if (arg = args[{{i}}]?)
                arg.as_t(T[{{i}}])
              else
                Variant.default_for(T[{{i}}])
              end),
            {% end %}
          }
        {% end %}
      {% end %}
    end

    def await(timeout_sec : Number)
      await(timeout_sec.to_f64)
    end
  end

  alias Signal = BoundSignal

  # Cooperatively awaits a bound signal.
  # Usage:
  #   args = Godot.await(enemy.died)
  #   args = Godot.await(enemy.died, timeout_sec: 3.0)
  def self.await(signal : Godot::BoundSignal, timeout_sec : Float64? = nil)
    signal.await(timeout_sec)
  end

  # Cooperatively awaits a bound signal with timeout.
  def self.await(signal : Godot::BoundSignal, timeout_sec : Number)
    signal.await(timeout_sec.to_f64)
  end

  # Cooperatively awaits a signal on a target object with numeric timeout.
  def self.await(target : Godot::Object, signal_name : String, timeout_sec : Number) : ::Array(Variant)
    await(target, signal_name, timeout_sec.to_f64)
  end

  # Emits a typed signal with compile-time type safety.
  def self.emit(signal : Godot::TypedSignal(*T), *args : *T) : Void forall T
    signal.emit(*args)
  end

  # Emits a bound signal dynamically on its target object.
  def self.emit(signal : Godot::BoundSignal, *args) : Void
    signal.emit(*args)
  end

  # Base class for all Godot engine objects and extension classes.
  # Provides identity, lifecycle dispatch hooks, and signal emission functionality.
  class Object
    property pointer : Void* = Pointer(Void).null
    getter instance_id : UInt64 = 0_u64
    getter? destroyed : Bool = false

    def initialize(@pointer : Void* = Pointer(Void).null)
      if !@pointer.null?
        @instance_id = Bridge.object_get_instance_id(@pointer)
      end
    end

    def pointer=(val : Void*)
      @pointer = val
      if !@pointer.null?
        @instance_id = Bridge.object_get_instance_id(@pointer)
      else
        @instance_id = 0_u64
      end
    end

    # Idiomatic Crystal pointer conversion
    def to_unsafe : Void*
      @pointer
    end

    # Identifier used for signal routing and lifecycle tracking (engine instance ID or Crystal object_id)
    def signal_target_id : UInt64
      @instance_id > 0 ? @instance_id : object_id.to_u64
    end

    # Value equality based on Godot engine identity (instance ID, underlying pointer, or reference identity)
    def ==(other : Godot::Object) : Bool
      if @instance_id > 0 && other.instance_id > 0
        @instance_id == other.instance_id
      elsif !@pointer.null? || !other.pointer.null?
        @pointer == other.pointer
      else
        same?(other)
      end
    end

    def ==(other : Nil) : Bool
      @pointer.null?
    end

    # Hashing based on engine instance ID for use in Sets and Hash keys
    def hash(hasher)
      if @instance_id > 0
        @instance_id.hash(hasher)
      else
        @pointer.address.hash(hasher)
      end
    end

    # Returns true if this object instance has a valid engine pointer and is alive in Godot's ObjectDB
    def alive? : Bool
      return false if @destroyed || @pointer.null? || @instance_id == 0_u64
      Bridge.is_instance_valid(@instance_id)
    end

    def is_valid? : Bool
      alive?
    end

    # Convenient nil-coalescing helper: returns self if alive, otherwise nil
    def if_alive : self?
      alive? ? self : nil
    end

    def destroyed? : Bool
      @destroyed || !alive?
    end

    def explicitly_freed? : Bool
      @destroyed
    end

    # Returns true if running inside the Godot Editor
    def editor_hint? : Bool
      Godot.editor_hint?
    end

    # Validates that the underlying engine object is still alive before executing bridge calls.
    # Raises `DisposedObjectError` if the object was destroyed by GDScript, engine, or Crystal.
    def check_alive! : Void
      if @destroyed || (@instance_id > 0 && !Bridge.is_instance_valid(@instance_id))
        @pointer = Pointer(Void).null
        raise DisposedObjectError.new(@instance_id)
      end
    end

    # Destroys this Object in the Godot engine and invalidates the Crystal pointer.
    def destroy : Void
      return if @destroyed
      @destroyed = true
      Godot.clear_signal_subscriptions(signal_target_id)
      if !@pointer.null?
        target_ptr = @pointer
        inst_id = @instance_id
        @pointer = Pointer(Void).null
        Bridge.unregister_alive_instance_by_ptr(target_ptr)
        if self.is_a?(RefCounted)
          # RefCounted instances are managed by Godot's atomic reference counter;
          # calling memdelete directly corrupts engine memory and causes heap corruption.
          return
        end
        if inst_id == 0 || Bridge.is_instance_valid(inst_id)
          Bridge.object_destroy(target_ptr)
        end
      end
    end

    # Destroys this Object in the Godot engine (alias to #destroy).
    def free : Void
      destroy
    end

    # Checks if a 64-bit instance ID is currently valid in Godot's ObjectDB
    def self.is_instance_id_valid(id : Int | UInt64) : Bool
      Bridge.is_instance_valid(id.to_u64)
    end

    # Automatically links this node's registered CrystalScript resource if running inside the Godot Editor
    def link_class_script : Void
      return unless Godot.editor_hint?
      return if @pointer.null?
      return if self.is_a?(Godot::Script) || self.class.name.includes?("Script") || self.class.name.includes?("Plugin")

      # Guard against linking script to nodes that are not inside the active scene tree (prevents 'Cannot get path of node' error)
      is_node = self.call_bool("is_class", "Node") rescue false
      if is_node
        return unless (self.call_bool("is_inside_tree") rescue false)
      end

      curr_script = self.get_script
      return if !curr_script.null?

      c_name = self.class.name.split("::").last
      entry = ClassRegistry.find(c_name)
      if !entry
        godot_cls = self.call_str("get_class") rescue ""
        entry = ClassRegistry.find(godot_cls) unless godot_cls.empty?
      end
      return unless entry
      return if entry.class_name.includes?("Script") || entry.class_name.includes?("Plugin")
      path = entry.script_path
      return if path.empty? || path == "res://" || path == "res:///"

      if script = ClassRegistry.get_or_load_script(path, entry.class_name, entry.parent_name, entry.is_tool)
        self.call("set_script", script)
      end
    rescue ex
      Godot.print("[LibGodot] Notice: could not link script for #{self.class.name}: #{ex.message}")
    end

    # Virtual method and property dispatch hooks overridden by class registration macros.
    # Delta timestep is received with 64-bit precision (`Float64`).
    def _godot_call_virtual(method_name : String, delta : Float64) : Void
    end

    # Invoked by the GDExtension bridge when setting an exposed `@export` property.
    def _godot_set_property(prop_name : String, val_ptr : Void*) : Void
    end

    # Invoked by the GDExtension bridge when retrieving an exposed `@export` property.
    def _godot_get_property(prop_name : String, ret_ptr : Void*) : Void
    end

    # Checks if this object class overrides a generic virtual method.
    def self._godot_has_virtual_method(method_name : String) : Bool
      false
    end

    # Dispatches generic virtual methods with raw arguments and return buffer.
    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
    end

    # Dispatches inspector tool button clicks on this object.
    def _godot_call_tool_button(button_name : String) : Void
    end

    # Emits a parameterless signal on this Godot object.
    def emit_signal(name : String) : Void
      check_alive!
      if !@pointer.null? && Bridge.available?
        Bridge.emit_signal(@pointer, name)
      else
        Godot.notify_signal(signal_target_id, name, [] of Variant)
      end
    end

    # Emits a signal with variable arguments on this Godot object.
    def emit_signal(name : String, *args) : Void
      check_alive!
      if !@pointer.null? && Bridge.available?
        Bridge.emit_signal(@pointer, name, *args)
      else
        var_args = args.map { |a| Variant.new(a) }.to_a
        Godot.notify_signal(signal_target_id, name, var_args)
      end
    end

    # Cooperatively awaits a signal emitted on this object.
    def await_signal(signal_name : String, timeout_sec : Float64? = nil) : ::Array(Variant)
      Godot.await(self, signal_name, timeout_sec)
    end

    # Returns a bound signal representation for the named signal.
    # Enables idiomatic usage: `enemy.signal("died").await` or `button.signal("pressed").connect { ... }`.
    def signal(name : String) : Godot::BoundSignal
      Godot::BoundSignal.new(self, name)
    end

    # Calls the named method on the object during idle time.
    def call_deferred(method : String, *args) : Void*
      check_alive!
      Bridge.object_call_deferred(@pointer, method, *args)
      Pointer(Void).null
    end

    # Calls the named method on the object with variable arguments.
    def call(method : String, *args) : Void*
      check_alive!
      Bridge.object_call(@pointer, method, *args)
      Pointer(Void).null
    end

    # Calls the named method and returns an Object/Node (or nil if null)
    def call_obj(method : String, *args) : Node?
      check_alive!
      ptr = Bridge.object_call_ret_object(@pointer, method, *args)
      ptr.null? ? nil : Node.new(ptr)
    end

    # Calls the named method and returns the result cast to T (or nil if null)
    def call_obj_as(type : T.class, method : String, *args) : T? forall T
      check_alive!
      ptr = Bridge.object_call_ret_object(@pointer, method, *args)
      return nil if ptr.null?
      if inst = Bridge.find_alive_instance(ptr)
        if casted = inst.as?(T)
          return casted
        end
      end
      T.new(ptr)
    end

    # Calls the named method and returns the result as Int64
    def call_i64(method : String, *args) : Int64
      check_alive!
      Bridge.object_call_ret_int(@pointer, method, *args)
    end

    # Calls the named method and returns the result as Float64
    def call_f64(method : String, *args) : Float64
      check_alive!
      Bridge.object_call_ret_float(@pointer, method, *args)
    end

    # Calls the named method and returns the result as Bool
    def call_bool(method : String, *args) : Bool
      check_alive!
      Bridge.object_call_ret_bool(@pointer, method, *args)
    end

    # Calls the named method and returns the result as String
    def call_str(method : String, *args) : String
      check_alive!
      Bridge.object_call_ret_string(@pointer, method, *args)
    end

    # Connects a callback proc to the named signal.
    def connect(signal_name : String, flags : ::Godot::ConnectFlags = ::Godot::ConnectFlags::None, callback : Proc(::Array(Variant), Void)? = nil) : SignalSubscription
      check_alive!
      sub = Godot.subscribe_signal(signal_target_id, signal_name, flags, callback)
      if !@pointer.null? && @instance_id > 0
        Bridge.object_connect_signal(@pointer, signal_name, flags.value)
      end
      sub
    end

    # Connects a callback block accepting Array(Variant) to the named signal.
    def connect(signal_name : String, flags : ::Godot::ConnectFlags = ::Godot::ConnectFlags::None, &block : ::Array(Variant) -> Void) : SignalSubscription
      check_alive!
      sub = Godot.subscribe_signal(signal_target_id, signal_name, flags, block)
      if !@pointer.null? && @instance_id > 0
        Bridge.object_connect_signal(@pointer, signal_name, flags.value)
      end
      sub
    end

    # Connects a one-shot callback block to the named signal (backwards compatibility).
    def connect_one_shot(signal_name : String, &block : ::Array(Variant) -> Void) : SignalSubscription
      connect(signal_name, flags: ::Godot::ConnectFlags::OneShot, &block)
    end

    # Connects the named signal to a method call on a listener target by symbol name.
    def connect(signal_name : String, listener_target : Godot::Object, method_name : Symbol, flags : ::Godot::ConnectFlags = ::Godot::ConnectFlags::None) : SignalSubscription
      signal(signal_name).connect(listener_target, method_name, flags)
    end

    # Disconnects all signal subscriptions for the named signal on this object.
    def disconnect(signal_name : String) : Void
      key = {signal_target_id, signal_name}
      Godot.signal_subs_mutex.synchronize do
        Godot.signal_subs.delete(key)
      end
      if !@pointer.null? && @instance_id > 0
        Bridge.object_disconnect_signal(@pointer, signal_name)
      end
    end

    # Returns true if this object or its registered class defines the given signal.
    def has_signal?(signal_name : String) : Bool
      check_alive!
      if !@pointer.null? && @instance_id > 0
        return true if has_signal(signal_name)
      end
      class_name = self.class.name.split("::").last
      if entry = Godot::ClassRegistry.find(class_name)
        return true if entry.signals.any? { |s| s.name == signal_name }
      end
      key = {signal_target_id, signal_name}
      Godot.signal_subs_mutex.synchronize do
        return true if Godot.signal_subs.has_key?(key)
      end
      false
    end

    # Returns the count of active subscriptions for the given signal on this object.
    def signal_connection_count(signal_name : String) : Int32
      key = {signal_target_id, signal_name}
      Godot.signal_subs_mutex.synchronize do
        if list = Godot.signal_subs[key]?
          list.size
        else
          0
        end
      end
    end

    # Prints a message to Godot's debug console.
    def print(*args)
      Godot.print(*args)
    end

    # Prints an error message to Godot's error console.
    def printerr(*args)
      Godot.printerr(*args)
    end

    # Prints a message to Godot's debug console.
    def puts(*args)
      Godot.print(*args)
    end

    def to_s(io : IO) : Void
      io << "<Godot::" << self.class.name << " #" << @instance_id << " @" << @pointer << ">"
    end
  end

  # Base class for reference-counted engine objects.
  class RefCounted < Object
    @@mb_ref_init_ref : Void* = Pointer(Void).null
    @@mb_ref_reference : Void* = Pointer(Void).null
    @@mb_ref_unreference : Void* = Pointer(Void).null
    @@mb_ref_get_reference_count : Void* = Pointer(Void).null

    def init_ref : Bool
      check_alive!
      godot_bind(@@mb_ref_init_ref, "RefCounted", "init_ref", 2240911060_i64)
      godot_ptrcall_bool(@@mb_ref_init_ref, @pointer, Pointer(Pointer(Void)).null)
    end

    def reference : Bool
      check_alive!
      godot_bind(@@mb_ref_reference, "RefCounted", "reference", 2240911060_i64)
      godot_ptrcall_bool(@@mb_ref_reference, @pointer, Pointer(Pointer(Void)).null)
    end

    def unreference : Bool
      return false if !alive?
      godot_bind(@@mb_ref_unreference, "RefCounted", "unreference", 2240911060_i64)
      target_ptr = @pointer
      target_id = signal_target_id
      should_free = godot_ptrcall_bool(@@mb_ref_unreference, target_ptr, Pointer(Pointer(Void)).null)
      if should_free
        inst_id = @instance_id
        @destroyed = true
        @pointer = Pointer(Void).null
        Godot.clear_signal_subscriptions(target_id)
        if Bridge.is_instance_valid(inst_id)
          Bridge.object_destroy(target_ptr)
        end
      end
      should_free
    end

    def get_reference_count : Int64
      check_alive!
      godot_bind(@@mb_ref_get_reference_count, "RefCounted", "get_reference_count", 3905245786_i64)
      godot_ptrcall_int(@@mb_ref_get_reference_count, @pointer, Pointer(Pointer(Void)).null)
    end

    # Safely destroys or unreferences this RefCounted object.
    def destroy : Void
      return if @destroyed
      target_ptr = @pointer
      inst_id = @instance_id
      target_id = signal_target_id
      @destroyed = true
      @pointer = Pointer(Void).null
      Godot.clear_signal_subscriptions(target_id)
      if !target_ptr.null?
        Bridge.unregister_alive_instance_by_ptr(target_ptr)
        is_alive = inst_id > 0 ? Bridge.is_instance_valid(inst_id) : true
        if is_alive
          if @@mb_ref_unreference.null?
            @@mb_ref_unreference = Bridge.get_method_bind("RefCounted", "unreference", 2240911060_i64)
          end
          if !@@mb_ref_unreference.null?
            # Unreference repeatedly until Godot frees the object or refcount reaches 0
            10.times do |iter|
              should_free = 0_u8
              Bridge.ptrcall(@@mb_ref_unreference, target_ptr, Pointer(Pointer(Void)).null, pointerof(should_free).as(Void*))
              valid = inst_id > 0 ? Bridge.is_instance_valid(inst_id) : false
              if should_free != 0_u8
                if valid
                  Bridge.object_destroy(target_ptr)
                end
                break
              end
              if !valid
                break
              end
              if @@mb_ref_get_reference_count.null?
                @@mb_ref_get_reference_count = Bridge.get_method_bind("RefCounted", "get_reference_count", 3905245786_i64)
              end
              rc = 0_i64
              if !@@mb_ref_get_reference_count.null?
                Bridge.ptrcall(@@mb_ref_get_reference_count, target_ptr, Pointer(Pointer(Void)).null, pointerof(rc).as(Void*))
              end
              if rc <= 0
                if inst_id == 0 || Bridge.is_instance_valid(inst_id)
                  Bridge.object_destroy(target_ptr)
                end
                break
              end
            end
          else
            if inst_id == 0 || Bridge.is_instance_valid(inst_id)
              Bridge.object_destroy(target_ptr)
            end
          end
        end
      end
    end
  end

  struct ::Nil
    def ==(other : Godot::Object) : Bool
      other.pointer.null?
    end
  end

  class Resource < RefCounted
  end

  class Texture < Resource
  end

  class Texture2D < Texture
  end

  class AudioStream < Resource
  end

  class PackedScene < Resource
    # Instantiates the scene's node hierarchy.
    def instantiate(edit_state : Int64 = 0_i64) : Node
      ptr = Bridge.packed_scene_instantiate(@pointer, edit_state)
      Node.new(ptr)
    end
  end

  class MainLoop < Object
  end

  # Manages the hierarchy of scene nodes and execution loops.
  class SceneTree < MainLoop
    property current_scene : Node = Node.new
    property root : Node = Node.new
  end

  # Base class for all scene tree nodes in Godot.
  # Provides hierarchy management, node traversal, and lifecycle hooks (`_ready`, `_process`, `_physics_process`).
  class Node < Object
    @name : String = "Node"

    def name : String
      if @pointer.null?
        @name
      else
        godot_name = Bridge.node_get_name(@pointer)
        godot_name.empty? ? @name : godot_name
      end
    end

    # Returns the node name
    def get_name : String
      name
    end

    def name=(val : String)
      @name = val
      if !@pointer.null?
        self.call("set_name", val)
      end
    end

    # Sets the name of the node safely via dynamic reflection
    def set_name(val : String) : Void
      self.name = val
    end

    # Returns the scene owner node responsible for serialization packing.
    def owner : Node?
      if !@pointer.null?
        n = get_owner
        n.pointer.null? ? nil : n
      else
        nil
      end
    end

    # Sets the scene owner node for serialization packing.
    def owner=(o : Node?)
      if !@pointer.null? && o
        set_owner(o)
      end
    end

    # Returns the SceneTree containing this node.
    def get_tree : SceneTree
      SceneTree.new
    end

    # Retrieves a child or sibling node by NodePath string.
    # Returns the Node if found, or produces an error if the node does not exist.
    def get_node(path : String) : Node
      ptr = Bridge.node_get_node(@pointer, path)
      if ptr.null?
        child_names = [] of String
        if !@pointer.null?
          child_count = Bridge.object_call_ret_int(@pointer, "get_child_count") rescue 0_i64
          child_count.times do |i|
            child_ptr = Bridge.object_call_ret_object(@pointer, "get_child", i) rescue nil
            if child_ptr && !child_ptr.null?
              cname = Bridge.node_get_name(child_ptr) rescue ""
              child_names << cname unless cname.empty?
            end
          end
        end
        hint = if child_names.empty?
                 "Node '#{self.name}' has no direct children."
               else
                 "Direct children: #{child_names.inspect}."
               end
        raise "Node not found: '#{path}' (relative to '#{self.name}'). #{hint} 💡 Tip: To search anywhere in the subtree, use find_child('#{path}') or scene unique name '%#{path}'."
      end
      Node.new(ptr)
    end

    # Retrieves a child or sibling node by NodePath string, or returns nil if not found.
    def get_node?(path : String) : Node?
      if @pointer.null?
        if self.is_a?(Node)
          return self.as(Node).children.find { |c| c.name == path }
        end
        return nil
      end
      ptr = Bridge.node_get_node(@pointer, path)
      ptr.null? ? nil : Node.new(ptr)
    end

    # Fetches a node by String path. Similar to `#get_node`, but returns nil if `path` does not point to a valid node.
    def get_node_or_null(path : String) : Node?
      get_node?(path)
    end

    # Retrieves a child node cast to the specified Crystal class type `T`.
    # Returns the node cast to `T`, or produces an error if the node does not exist.
    def get_node_as(type : T.class, path : String) : T forall T
      node = get_node(path)
      if alive = Bridge.find_alive_instance(node.pointer)
        if typed = alive.as?(T)
          return typed
        end
      end
      if node.is_a?(T)
        return node
      elsif !node.pointer.null? && Bridge.object_is_class(node.pointer, T.name.split("::").last)
        return T.new(node.pointer)
      end
      T.new(node.pointer)
    end

    # Retrieves a child node cast to the specified Crystal class type `T`, or nil if not found.
    def get_node_as?(type : T.class, path : String) : T? forall T
      if node = get_node?(path)
        if alive = Bridge.find_alive_instance(node.pointer)
          if typed = alive.as?(T)
            return typed
          end
        end
        if node.is_a?(T)
          return node
        elsif !node.pointer.null? && Bridge.object_is_class(node.pointer, T.name.split("::").last)
          return T.new(node.pointer)
        end
      end
    end

    # Indexer syntactic sugar for retrieving a child node by path (e.g. self["Camera3D"])
    def [](path : String) : Node
      get_node(path)
    end

    # Safe indexer returning nil if node not found (e.g. self["Camera3D"]?)
    def []?(path : String) : Node?
      get_node?(path)
    end

    # Shorthand for get_node_as
    def node_as(type : T.class, path : String) : T forall T
      get_node_as(type, path)
    end

    # Shorthand for get_node_as?
    def node_as?(type : T.class, path : String) : T? forall T
      get_node_as?(type, path)
    end

    # Finds an existing child node matching `pattern`.
    def find_child(pattern : String, recursive : Bool = true, owned : Bool = false) : Node?
      ptr = Bridge.node_find_child(@pointer, pattern, recursive, owned)
      ptr.null? ? nil : Node.new(ptr)
    end

    # Lifecycle callback called when the node enters the active scene tree.
    def _ready : Void
    end

    # Per-frame process callback receiving delta timestep in seconds (`Float64`).
    def _process(delta : Float64) : Void
    end

    # Fixed-rate physics process callback receiving delta timestep in seconds (`Float64`).
    def _physics_process(delta : Float64) : Void
    end
  end

  # Base class for all 2D canvas items, UI elements, and 2D nodes.
  class CanvasItem < Node
  end

  # A 2D game object with position, rotation, and scale transform.
  class Node2D < CanvasItem
    @position : Vector2 = Vector2.new
    @global_position : Vector2 = Vector2.new
    @rotation : Float32 = 0.0_f32
    @rotation_degrees : Float32 = 0.0_f32
    @global_rotation : Float32 = 0.0_f32
    @global_rotation_degrees : Float32 = 0.0_f32
    @scale : Vector2 = Vector2.new(1.0_f32, 1.0_f32)
    @global_scale : Vector2 = Vector2.new(1.0_f32, 1.0_f32)
    @skew : Float32 = 0.0_f32
    @global_skew : Float32 = 0.0_f32
    @transform : Transform2D = Transform2D.new
    @global_transform : Transform2D = Transform2D.new
    @visible : Bool = true

    def position : Vector2
      if !@pointer.null?
        get_position
      else
        @position
      end
    end

    def position=(v : Vector2)
      @position = v
      if !@pointer.null?
        set_position(v)
      end
    end

    def global_position : Vector2
      if !@pointer.null?
        get_global_position
      else
        @global_position
      end
    end

    def global_position=(v : Vector2)
      @global_position = v
      if !@pointer.null?
        set_global_position(v)
      end
    end

    def rotation : Float32
      if !@pointer.null?
        get_rotation.to_f32
      else
        @rotation
      end
    end

    def rotation=(v : Float32)
      @rotation = v
      if !@pointer.null?
        set_rotation(v.to_f64)
      end
    end

    def rotation_degrees : Float32
      if !@pointer.null?
        get_rotation_degrees.to_f32
      else
        @rotation_degrees
      end
    end

    def rotation_degrees=(v : Float32)
      @rotation_degrees = v
      if !@pointer.null?
        set_rotation_degrees(v.to_f64)
      end
    end

    def global_rotation : Float32
      if !@pointer.null?
        get_global_rotation.to_f32
      else
        @global_rotation
      end
    end

    def global_rotation=(v : Float32)
      @global_rotation = v
      if !@pointer.null?
        set_global_rotation(v.to_f64)
      end
    end

    def global_rotation_degrees : Float32
      if !@pointer.null?
        get_global_rotation_degrees.to_f32
      else
        @global_rotation_degrees
      end
    end

    def global_rotation_degrees=(v : Float32)
      @global_rotation_degrees = v
      if !@pointer.null?
        set_global_rotation_degrees(v.to_f64)
      end
    end

    def scale : Vector2
      if !@pointer.null?
        get_scale
      else
        @scale
      end
    end

    def scale=(v : Vector2)
      @scale = v
      if !@pointer.null?
        set_scale(v)
      end
    end

    def global_scale : Vector2
      if !@pointer.null?
        get_global_scale
      else
        @global_scale
      end
    end

    def global_scale=(v : Vector2)
      @global_scale = v
      if !@pointer.null?
        set_global_scale(v)
      end
    end

    def skew : Float32
      if !@pointer.null?
        get_skew.to_f32
      else
        @skew
      end
    end

    def skew=(v : Float32)
      @skew = v
      if !@pointer.null?
        set_skew(v.to_f64)
      end
    end

    def global_skew : Float32
      if !@pointer.null?
        get_global_skew.to_f32
      else
        @global_skew
      end
    end

    def global_skew=(v : Float32)
      @global_skew = v
      if !@pointer.null?
        set_global_skew(v.to_f64)
      end
    end

    def transform : Transform2D
      if !@pointer.null?
        get_transform
      else
        @transform
      end
    end

    def transform=(v : Transform2D)
      @transform = v
      if !@pointer.null?
        set_transform(v)
      end
    end

    def global_transform : Transform2D
      if !@pointer.null?
        get_global_transform
      else
        @global_transform
      end
    end

    def global_transform=(v : Transform2D)
      @global_transform = v
      if !@pointer.null?
        set_global_transform(v)
      end
    end

    def visible : Bool
      if !@pointer.null?
        is_visible
      else
        @visible
      end
    end

    def visible=(v : Bool)
      @visible = v
      if !@pointer.null?
        set_visible(v)
      end
    end

    def visible? : Bool
      visible
    end
  end

  # A 3D game object with spatial position, rotation, scale, and transform matrix.
  class Node3D < Node
    @position : Vector3 = Vector3.new
    @global_position : Vector3 = Vector3.new
    @rotation : Vector3 = Vector3.new
    @rotation_degrees : Vector3 = Vector3.new
    @global_rotation : Vector3 = Vector3.new
    @global_rotation_degrees : Vector3 = Vector3.new
    @scale : Vector3 = Vector3.new(1.0_f32, 1.0_f32, 1.0_f32)
    @transform : Transform3D = Transform3D.new
    @global_transform : Transform3D = Transform3D.new
    @basis : Basis = Basis.new
    @global_basis : Basis = Basis.new
    @visible : Bool = true
    @top_level : Bool = false

    def position : Vector3
      if !@pointer.null?
        get_position
      else
        @position
      end
    end

    def position=(v : Vector3)
      @position = v
      if !@pointer.null?
        set_position(v)
      end
    end

    def global_position : Vector3
      if !@pointer.null?
        get_global_position
      else
        @global_position
      end
    end

    def global_position=(v : Vector3)
      @global_position = v
      if !@pointer.null?
        set_global_position(v)
      end
    end

    def rotation : Vector3
      if !@pointer.null?
        get_rotation
      else
        @rotation
      end
    end

    def rotation=(v : Vector3)
      @rotation = v
      if !@pointer.null?
        set_rotation(v)
      end
    end

    def rotation_degrees : Vector3
      if !@pointer.null?
        get_rotation_degrees
      else
        @rotation_degrees
      end
    end

    def rotation_degrees=(v : Vector3)
      @rotation_degrees = v
      if !@pointer.null?
        set_rotation_degrees(v)
      end
    end

    def global_rotation : Vector3
      if !@pointer.null?
        get_global_rotation
      else
        @global_rotation
      end
    end

    def global_rotation=(v : Vector3)
      @global_rotation = v
      if !@pointer.null?
        set_global_rotation(v)
      end
    end

    def global_rotation_degrees : Vector3
      if !@pointer.null?
        get_global_rotation_degrees
      else
        @global_rotation_degrees
      end
    end

    def global_rotation_degrees=(v : Vector3)
      @global_rotation_degrees = v
      if !@pointer.null?
        set_global_rotation_degrees(v)
      end
    end

    def scale : Vector3
      if !@pointer.null?
        get_scale
      else
        @scale
      end
    end

    def scale=(v : Vector3)
      @scale = v
      if !@pointer.null?
        set_scale(v)
      end
    end

    def transform : Transform3D
      if !@pointer.null?
        get_transform
      else
        @transform
      end
    end

    def transform=(v : Transform3D)
      @transform = v
      if !@pointer.null?
        set_transform(v)
      end
    end

    def global_transform : Transform3D
      if !@pointer.null?
        get_global_transform
      else
        @global_transform
      end
    end

    def global_transform=(v : Transform3D)
      @global_transform = v
      if !@pointer.null?
        set_global_transform(v)
      end
    end

    def basis : Basis
      if !@pointer.null?
        get_basis
      else
        @basis
      end
    end

    def basis=(v : Basis)
      @basis = v
      if !@pointer.null?
        set_basis(v)
      end
    end

    def global_basis : Basis
      if !@pointer.null?
        get_global_basis
      else
        @global_basis
      end
    end

    def global_basis=(v : Basis)
      @global_basis = v
      if !@pointer.null?
        set_global_basis(v)
      end
    end

    def visible : Bool
      if !@pointer.null?
        is_visible
      else
        @visible
      end
    end

    def visible=(v : Bool)
      @visible = v
      if !@pointer.null?
        set_visible(v)
      end
    end

    def visible? : Bool
      visible
    end

    def top_level : Bool
      if !@pointer.null?
        is_set_as_top_level
      else
        @top_level
      end
    end

    def top_level=(v : Bool)
      @top_level = v
      if !@pointer.null?
        set_as_top_level(v)
      end
    end
  end

  # Base class for all 2D collision and physics objects.
  class CollisionObject2D < Node2D
  end

  # Base class for all 2D physics bodies.
  class PhysicsBody2D < CollisionObject2D
  end

  # Specialized 2D physics body for character movement, kinematic platforming, and gravity.
  class CharacterBody2D < PhysicsBody2D
    @velocity : Vector2 = Vector2.new
    @up_direction : Vector2 = Vector2.new(0.0_f32, -1.0_f32)
    @floor_snap_length : Float64 = 0.1
    @floor_max_angle : Float64 = 0.785398
    @floor_stop_on_slope : Bool = true
    @floor_constant_speed : Bool = false
    @max_slides : Int64 = 4_i64

    def velocity : Vector2
      if !@pointer.null?
        get_velocity
      else
        @velocity
      end
    end

    def velocity=(v : Vector2)
      @velocity = v
      if !@pointer.null?
        set_velocity(v)
      end
    end

    def up_direction : Vector2
      if !@pointer.null?
        get_up_direction
      else
        @up_direction
      end
    end

    def up_direction=(v : Vector2)
      @up_direction = v
      if !@pointer.null?
        set_up_direction(v)
      end
    end

    def floor_normal : Vector2
      if !@pointer.null?
        get_floor_normal
      else
        Vector2::UP
      end
    end

    def real_velocity : Vector2
      if !@pointer.null?
        get_real_velocity
      else
        @velocity
      end
    end

    def is_on_floor : Bool
      if !@pointer.null?
        begin
          res = 0_u8
          mb = Bridge.get_method_bind("CharacterBody2D", "is_on_floor", 36873697_i64)
          Bridge.ptrcall(mb, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          true
        end
      else
        true
      end
    end

    def on_floor? : Bool
      is_on_floor
    end

    def on_wall? : Bool
      if !@pointer.null?
        begin
          res = 0_u8
          mb = Bridge.get_method_bind("CharacterBody2D", "is_on_wall", 36873697_i64)
          Bridge.ptrcall(mb, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          false
        end
      else
        false
      end
    end

    def on_ceiling? : Bool
      if !@pointer.null?
        begin
          res = 0_u8
          mb = Bridge.get_method_bind("CharacterBody2D", "is_on_ceiling", 36873697_i64)
          Bridge.ptrcall(mb, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          false
        end
      else
        false
      end
    end

    def move_and_slide : Bool
      if !@pointer.null?
        begin
          res = 0_u8
          mb = Bridge.get_method_bind("CharacterBody2D", "move_and_slide", 2240911060_i64)
          Bridge.ptrcall(mb, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          true
        end
      else
        true
      end
    end
  end

  # Base class for all 3D collision and physics objects.
  class CollisionObject3D < Node3D
  end

  # Base class for all 3D physics bodies.
  class PhysicsBody3D < CollisionObject3D
  end

  # Specialized 3D physics body for characters, kinematic controllers, and navigation.
  class CharacterBody3D < PhysicsBody3D
    @velocity : Vector3 = Vector3.new
    @up_direction : Vector3 = Vector3.new(0.0_f32, 1.0_f32, 0.0_f32)
    @floor_snap_length : Float64 = 0.1
    @floor_max_angle : Float64 = 0.785398
    @floor_stop_on_slope : Bool = true
    @floor_constant_speed : Bool = false
    @max_slides : Int64 = 4_i64

    # Returns true if the body is currently resting on a floor collider.
    def is_on_floor : Bool
      if !@pointer.null?
        Bridge.is_on_floor(@pointer)
      else
        true
      end
    end

    def on_floor? : Bool
      is_on_floor
    end

    def on_wall? : Bool
      if !@pointer.null?
        begin
          res = 0_u8
          mb = Bridge.get_method_bind("CharacterBody3D", "is_on_wall", 36873697_i64)
          Bridge.ptrcall(mb, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          false
        end
      else
        false
      end
    end

    def on_ceiling? : Bool
      if !@pointer.null?
        begin
          res = 0_u8
          mb = Bridge.get_method_bind("CharacterBody3D", "is_on_ceiling", 36873697_i64)
          Bridge.ptrcall(mb, @pointer, Pointer(Pointer(Void)).null, pointerof(res).as(Void*))
          res != 0_u8
        rescue
          false
        end
      else
        false
      end
    end

    # Current linear velocity of the character body.
    def velocity : Vector3
      if !@pointer.null?
        get_velocity
      else
        @velocity
      end
    end

    def velocity=(v : Vector3)
      @velocity = v
      if !@pointer.null?
        set_velocity(v)
      end
    end

    def up_direction : Vector3
      if !@pointer.null?
        get_up_direction
      else
        @up_direction
      end
    end

    def up_direction=(v : Vector3)
      @up_direction = v
      if !@pointer.null?
        set_up_direction(v)
      end
    end

    def floor_normal : Vector3
      if !@pointer.null?
        get_floor_normal
      else
        Vector3::UP
      end
    end

    def real_velocity : Vector3
      if !@pointer.null?
        get_real_velocity
      else
        @velocity
      end
    end

    def max_slides : Int64
      if !@pointer.null?
        get_max_slides
      else
        @max_slides
      end
    end

    def max_slides=(v : Int64)
      @max_slides = v
      if !@pointer.null?
        set_max_slides(v)
      end
    end

    def floor_snap_length : Float64
      if !@pointer.null?
        get_floor_snap_length
      else
        @floor_snap_length
      end
    end

    def floor_snap_length=(v : Float64)
      @floor_snap_length = v
      if !@pointer.null?
        set_floor_snap_length(v)
      end
    end

    def floor_max_angle : Float64
      if !@pointer.null?
        get_floor_max_angle
      else
        @floor_max_angle
      end
    end

    def floor_max_angle=(v : Float64)
      @floor_max_angle = v
      if !@pointer.null?
        set_floor_max_angle(v)
      end
    end

    def floor_stop_on_slope : Bool
      if !@pointer.null?
        is_floor_stop_on_slope_enabled
      else
        @floor_stop_on_slope
      end
    end

    def floor_stop_on_slope=(v : Bool)
      @floor_stop_on_slope = v
      if !@pointer.null?
        set_floor_stop_on_slope_enabled(v)
      end
    end

    def floor_constant_speed : Bool
      if !@pointer.null?
        is_floor_constant_speed_enabled
      else
        @floor_constant_speed
      end
    end

    def floor_constant_speed=(v : Bool)
      @floor_constant_speed = v
      if !@pointer.null?
        set_floor_constant_speed_enabled(v)
      end
    end

    def slide_collision_count : Int64
      if !@pointer.null?
        get_slide_collision_count
      else
        0_i64
      end
    end

    # Moves the body along its velocity vector and handles collisions/sliding.
    def move_and_slide : Bool
      if !@pointer.null?
        Bridge.move_and_slide(@pointer)
      else
        true
      end
    end
  end

  # Camera node for 3D scenes.
  class Camera3D < Node3D
    @fov : Float64 = 75.0
    @near : Float64 = 0.05
    @far : Float64 = 4000.0
    @current : Bool = false

    def fov : Float64
      if !@pointer.null?
        get_fov
      else
        @fov
      end
    end

    def fov=(v : Number)
      @fov = v.to_f64
      if !@pointer.null?
        set_fov(v.to_f64)
      end
    end

    def current : Bool
      if !@pointer.null?
        is_current
      else
        @current
      end
    end

    def current=(v : Bool)
      @current = v
      if !@pointer.null?
        set_current(v)
      end
    end

    def current? : Bool
      current
    end

    def near : Float64
      if !@pointer.null?
        get_near
      else
        @near
      end
    end

    def near=(v : Number)
      @near = v.to_f64
      if !@pointer.null?
        set_near(v.to_f64)
      end
    end

    def far : Float64
      if !@pointer.null?
        get_far
      else
        @far
      end
    end

    def far=(v : Number)
      @far = v.to_f64
      if !@pointer.null?
        set_far(v.to_f64)
      end
    end
  end

  # Ray casting node for 3D physics ray intersection queries.
  class RayCast3D < Node3D
    @target_position : Vector3 = Vector3.new(0.0_f32, -1.0_f32, 0.0_f32)
    @enabled : Bool = true

    def target_position : Vector3
      if !@pointer.null?
        get_target_position
      else
        @target_position
      end
    end

    def target_position=(v : Vector3)
      @target_position = v
      if !@pointer.null?
        set_target_position(v)
      end
    end

    def enabled : Bool
      if !@pointer.null?
        is_enabled
      else
        @enabled
      end
    end

    def enabled=(v : Bool)
      @enabled = v
      if !@pointer.null?
        set_enabled(v)
      end
    end

    def enabled? : Bool
      enabled
    end

    def colliding? : Bool
      if !@pointer.null?
        is_colliding
      else
        false
      end
    end

    def collision_point : Vector3
      if !@pointer.null?
        get_collision_point
      else
        Vector3.new
      end
    end

    def collision_normal : Vector3
      if !@pointer.null?
        get_collision_normal
      else
        Vector3::UP
      end
    end
  end

  # Node that provides a collision shape to a CollisionObject3D.
  class CollisionShape3D < Node3D
    @disabled : Bool = false

    def disabled : Bool
      if !@pointer.null?
        is_disabled
      else
        @disabled
      end
    end

    def disabled=(v : Bool)
      @disabled = v
      if !@pointer.null?
        set_disabled(v)
      end
    end

    def disabled? : Bool
      disabled
    end
  end

  # Base class for all GUI and user interface controls.
  class Control < CanvasItem
    @size : Vector2 = Vector2.new
    @position : Vector2 = Vector2.new
    @global_position : Vector2 = Vector2.new
    @rotation : Float32 = 0.0_f32
    @scale : Vector2 = Vector2.new(1.0_f32, 1.0_f32)
    @visible : Bool = true

    def size : Vector2
      if !@pointer.null?
        get_size
      else
        @size
      end
    end

    def size=(v : Vector2)
      @size = v
      if !@pointer.null?
        set_size(v, false)
      end
    end

    def set_size(size : Vector2) : Void
      if !@pointer.null?
        set_size(size, false)
      else
        @size = size
      end
    end

    def position : Vector2
      if !@pointer.null?
        get_position
      else
        @position
      end
    end

    def position=(v : Vector2)
      @position = v
      if !@pointer.null?
        set_position(v, false)
      end
    end

    def set_position(position : Vector2) : Void
      if !@pointer.null?
        set_position(position, false)
      else
        @position = position
      end
    end

    def global_position : Vector2
      if !@pointer.null?
        get_global_position
      else
        @global_position
      end
    end

    def global_position=(v : Vector2)
      @global_position = v
      if !@pointer.null?
        set_global_position(v, false)
      end
    end

    def set_global_position(position : Vector2) : Void
      if !@pointer.null?
        set_global_position(position, false)
      else
        @global_position = position
      end
    end

    def rotation : Float32
      if !@pointer.null?
        get_rotation.to_f32
      else
        @rotation
      end
    end

    def rotation=(v : Float32)
      @rotation = v
      if !@pointer.null?
        set_rotation(v.to_f64)
      end
    end

    def scale : Vector2
      if !@pointer.null?
        get_scale
      else
        @scale
      end
    end

    def scale=(v : Vector2)
      @scale = v
      if !@pointer.null?
        set_scale(v)
      end
    end

    def visible : Bool
      if !@pointer.null?
        is_visible
      else
        @visible
      end
    end

    def visible=(v : Bool)
      @visible = v
      if !@pointer.null?
        set_visible(v)
      end
    end

    def visible? : Bool
      visible
    end
  end

  # Base class for numeric control elements (sliders, progress bars, spinboxes).
  class Range < Control
    property min_value : Float64 = 0.0
    property max_value : Float64 = 100.0
    property step : Float64 = 1.0
    property page : Float64 = 0.0
    property value : Float64 = 0.0

    def initialize(min : Number = 0.0, max : Number = 100.0, @step : Float64 = 1.0)
      super()
      @min_value = min.to_f64
      @max_value = max.to_f64
    end

    def value=(val : Number)
      @value = val.to_f64
      Bridge.range_set_value(@pointer, @value) unless @pointer.null?
    end

    def set_value(val : Number) : Void
      self.value = val
    end

    # Type cohesion: Initialize from a Crystal Range
    def self.new(crystal_range : ::Range(Number, Number), step : Number = 1.0)
      new(crystal_range.begin, crystal_range.end, step.to_f64)
    end

    # Type cohesion: Set bounds using a Crystal Range (e.g. control.range = 0..100)
    def range=(crystal_range : ::Range(Number, Number))
      @min_value = crystal_range.begin.to_f64
      @max_value = crystal_range.end.to_f64
    end

    # Type cohesion: Read bounds as a Crystal Range
    def to_range : ::Range(Float64, Float64)
      @min_value..@max_value
    end

    # Type cohesion: Check if a value falls within the Range bounds
    def includes?(val : Number) : Bool
      to_range.includes?(val.to_f64)
    end

    def in_range?(val : Number) : Bool
      includes?(val)
    end

    def ratio : Float64
      span = @max_value - @min_value
      span > 0 ? (@value - @min_value) / span : 0.0
    end
  end

  # Visual progress bar control displaying completion ratio.
  class ProgressBar < Range
  end

  # Base class for slider controls.
  class Slider < Range
  end

  # Horizontal slider control.
  class HSlider < Slider
  end

  # Vertical slider control.
  class VSlider < Slider
  end

  # Numeric entry spinbox control with up/down adjusters.
  class SpinBox < Range
  end

  # Singleton interface for handling keyboard, mouse, gamepad, and mapped input actions.
  class Input < Object
    def self.is_action_pressed(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_pressed(action, exact_match)
    end

    def self.is_action_just_pressed(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_pressed(action, exact_match)
    end

    def self.is_action_just_released(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_released(action, exact_match)
    end

    def self.action_pressed?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_pressed(action, exact_match)
    end

    def self.action_just_pressed?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_pressed(action, exact_match)
    end

    def self.action_just_released?(action : String, exact_match : Bool = false) : Bool
      Bridge.is_action_just_released(action, exact_match)
    end

    def self.is_key_pressed(key : Key | Int32 | Int64) : Bool
      Bridge.is_key_pressed(key.to_i32) || Bridge.is_physical_key_pressed(key.to_i32)
    end

    def self.is_physical_key_pressed(key : Key | Int32 | Int64) : Bool
      Bridge.is_physical_key_pressed(key.to_i32)
    end

    def self.is_mouse_button_pressed(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def self.mouse_button_pressed?(button : MouseButton | Int32 | Int64) : Bool
      Bridge.is_mouse_button_pressed(button.to_i64)
    end

    def self.axis(negative_action : String, positive_action : String) : Float32
      Bridge.get_axis(negative_action, positive_action)
    end

    def self.get_vector(negative_x : String, positive_x : String, negative_y : String, positive_y : String, deadzone : Float64 = -1.0_f64) : Vector2
      Bridge.get_vector(negative_x, positive_x, negative_y, positive_y, deadzone)
    end

    def self.use_accumulated_input : Bool
      Bridge.use_accumulated_input
    end

    def self.use_accumulated_input=(enable : Bool) : Void
      Bridge.use_accumulated_input = enable
    end
  end

  class InputEvent < Resource
    def self.wrap(ptr : Void*) : Godot::InputEvent
      return Godot::InputEvent.new(ptr) if ptr.null?
      cls = Bridge.object_class_name(ptr)
      if cls.empty?
        if Bridge.object_is_class(ptr, "InputEventMouseMotion")
          return Godot::InputEventMouseMotion.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventMouseButton")
          return Godot::InputEventMouseButton.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventKey")
          return Godot::InputEventKey.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventJoypadButton")
          return Godot::InputEventJoypadButton.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventJoypadMotion")
          return Godot::InputEventJoypadMotion.new(ptr)
        elsif Bridge.object_is_class(ptr, "InputEventAction")
          return Godot::InputEventAction.new(ptr)
        end
      end

      case cls
      when "InputEventMouseMotion"
        Godot::InputEventMouseMotion.new(ptr)
      when "InputEventMouseButton"
        Godot::InputEventMouseButton.new(ptr)
      when "InputEventKey"
        Godot::InputEventKey.new(ptr)
      when "InputEventJoypadButton"
        Godot::InputEventJoypadButton.new(ptr)
      when "InputEventJoypadMotion"
        Godot::InputEventJoypadMotion.new(ptr)
      when "InputEventAction"
        Godot::InputEventAction.new(ptr)
      when "InputEventScreenDrag"
        Godot::InputEventScreenDrag.new(ptr)
      when "InputEventScreenTouch"
        Godot::InputEventScreenTouch.new(ptr)
      when "InputEventShortcut"
        Godot::InputEventShortcut.new(ptr)
      when "InputEventMagnifyGesture"
        Godot::InputEventMagnifyGesture.new(ptr)
      when "InputEventPanGesture"
        Godot::InputEventPanGesture.new(ptr)
      when "InputEventMIDI"
        Godot::InputEventMIDI.new(ptr)
      else
        Godot::InputEvent.new(ptr)
      end
    end
  end

  # Represents a path to a node or property in the Godot scene tree.
  struct NodePath
    property path : String

    def initialize(@path : String = "")
    end

    def initialize(pointer : Void*)
      @path = ""
    end

    def to_s(io : IO) : Void
      io << @path
    end

    def to_s : String
      @path
    end

    def ==(other : NodePath) : Bool
      @path == other.@path
    end

    def ==(other : String) : Bool
      @path == other
    end

    def empty? : Bool
      @path.empty?
    end

    # Returns the subname count (number of colon-separated property paths after node)
    def get_subname_count : Int64
      parts = @path.split(':')
      parts.size > 1 ? (parts.size - 1).to_i64 : 0_i64
    end

    # Returns the subname at the given index
    def get_subname(idx : Int64) : String
      parts = @path.split(':')
      idx + 1 < parts.size ? parts[idx + 1] : ""
    end
  end
end

# Crystal Standard Library Extension: Type cohesion for Crystal Range <-> Godot
struct Range(B, E)
  # Converts Crystal range into a Godot::Range control node
  def to_godot_range(step : Number = 1.0) : Godot::Range
    Godot::Range.new(self, step)
  end

  # Converts Crystal range to a Godot PROPERTY_HINT_RANGE hint string (e.g. "0,100" or "0,100,0.5")
  def to_godot_hint_string(step : Number? = nil) : String
    if s = step
      "#{self.begin},#{self.end},#{s}"
    else
      "#{self.begin},#{self.end}"
    end
  end

  # Converts to float tuple for engine interop
  def to_godot_bounds : Tuple(Float64, Float64)
    {self.begin.to_f64, self.end.to_f64}
  end
end

# Global convenience helper to load resources from Godot VFS
def load(path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : Godot::Resource
  Godot.load(path, type_hint, cache_mode)
end

# Global convenience helper to preload resources from Godot VFS
def preload(path : String) : Godot::Resource
  Godot.preload(path)
end
