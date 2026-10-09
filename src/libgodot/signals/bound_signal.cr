module Godot
  # Represents a signal bound to a specific Godot object instance.
  # Enables first-class signal handling, inspection, connection, emission, and non-blocking `await`.
  #
  # Examples:
  # ```crystal
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

    # Returns true if the bound object is active and not destroyed
    def active? : Bool
      @target.active?
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
    def connect(flags : ConnectFlags = ConnectFlags::None, callback : Proc(::Array(Variant), Void)? = nil, receiver : Godot::Object? = nil) : SignalSubscription
      @target.connect(@name, flags, callback, receiver)
    end

    # Connects a callback block to this signal (supports 1-arg `|args|` and 0-arg blocks)
    def connect(flags : ConnectFlags = ConnectFlags::None, receiver : Godot::Object? = nil, &block : ::Array(Variant) -> Void) : SignalSubscription
      @target.connect(@name, flags, receiver, &block)
    end

    # Connects a callback block to this signal with explicit receiver tracking as first positional argument
    def connect(receiver : Godot::Object, flags : ConnectFlags = ConnectFlags::None, &block : ::Array(Variant) -> Void) : SignalSubscription
      @target.connect(@name, flags, receiver, &block)
    end

    # Backwards-compatibility helper redirecting to ConnectFlags::OneShot
    def connect_one_shot(&block : ::Array(Variant) -> Void) : SignalSubscription
      connect(flags: ConnectFlags::OneShot, &block)
    end

    # Idiomatic shorthand alias for `connect_one_shot`
    def once(&block : ::Array(Variant) -> Void) : SignalSubscription
      connect(flags: ConnectFlags::OneShot, &block)
    end

    # Connects with 1 positional type filter
    def connect(type0 : T0.class, flags : ConnectFlags = ConnectFlags::None, &block : T0 -> Void) : SignalSubscription forall T0
      @target.connect(@name, flags) do |args|
        if args.size >= 1
          raw = args[0].raw
          {% if T0 == Godot::Any %}
            block.call(raw)
          {% else %}
            if raw_node = raw.as?(Godot::Node)
              if casted = Godot::Node.cast_to?(raw_node, T0)
                block.call(casted)
              end
            elsif raw.is_a?(T0)
              block.call(raw)
            end
          {% end %}
        end
      end
    end

    # Connects with 2 positional type filters
    def connect(type0 : T0.class, type1 : T1.class, flags : ConnectFlags = ConnectFlags::None, &block : (T0, T1) -> Void) : SignalSubscription forall T0, T1
      @target.connect(@name, flags) do |args|
        if args.size >= 2
          c0 : T0? = nil
          raw0 = args[0].raw
          {% if T0 == Godot::Any %}
            c0 = raw0
          {% else %}
            if raw0.is_a?(Godot::Node)
              c0 = Godot::Node.cast_to?(raw0, T0)
            elsif raw0.is_a?(T0)
              c0 = raw0
            end
          {% end %}

          c1 : T1? = nil
          raw1 = args[1].raw
          {% if T1 == Godot::Any %}
            c1 = raw1
          {% else %}
            if raw1.is_a?(Godot::Node)
              c1 = Godot::Node.cast_to?(raw1, T1)
            elsif raw1.is_a?(T1)
              c1 = raw1
            end
          {% end %}

          if !c0.nil? && !c1.nil?
            block.call(c0, c1)
          end
        end
      end
    end

    # One-shot listener with 1 positional type filter
    def once(type0 : T0.class, &block : T0 -> Void) : SignalSubscription forall T0
      connect(type0, flags: ConnectFlags::OneShot, &block)
    end

    # One-shot listener with 2 positional type filters
    def once(type0 : T0.class, type1 : T1.class, &block : (T0, T1) -> Void) : SignalSubscription forall T0, T1
      connect(type0, type1, flags: ConnectFlags::OneShot, &block)
    end

    # Connects this signal to a method call on a target object by symbol name
    def connect(listener_target : Godot::Object, method_name : Symbol, flags : ConnectFlags = ConnectFlags::None) : SignalSubscription
      @target.connect(@name, flags, receiver: listener_target) do |args|
        if listener_target.active?
          listener_target.call(method_name.to_s, args)
        end
      end
    end

    # Disconnects all active subscriptions for this signal on the target
    def disconnect : self
      @target.disconnect(@name)
      self
    end

    # Disconnects all active subscriptions for this signal on the target (alias)
    def disconnect_all : self
      disconnect
    end

    # Fluent alias for disconnect_all
    def clear : self
      disconnect_all
    end

    # Emits this signal on the target object
    def emit(*args) : self
      @target.emit_signal(@name, *args)
      self
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

    # Pipes this signal to target signal
    def pipe_to(target_signal : BoundSignal, strict : Bool = false) : SignalSubscription
      target_obj = target_signal.target
      target_name = target_signal.name
      connect(receiver: target_obj) do |args|
        if target_obj.active?
          target_obj.emit_signal(target_name, *args.map(&.raw))
        end
      end
    end

    def to_s(io : IO) : Void
      io << "#<Godot::BoundSignal @" << @name << " on " << @target.class.name << " (id: " << target_id << ")>"
    end
  end
end
