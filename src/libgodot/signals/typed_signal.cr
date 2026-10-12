module Godot
  # Strongly-typed signal binding offering compile-time type safety for signal connections and await.
  class TypedSignal(*T) < BoundSignal
    # Type-safe connect with automatic unboxing into block parameters
    def connect(flags : ConnectFlags = ConnectFlags::None, receiver : Godot::Object? = nil, &block : *T -> Void) : SignalSubscription
      cb = block
      @target.connect(@name, flags, receiver: receiver) do |args|
        {% begin %}
          {% if T.size == 0 %}
            cb.call
          {% else %}
            cb.call(
              {% for i in 0...T.size %}
                (if (arg = args[{{i}}]?)
                  arg.as_t({{ T[i] }})
                else
                  Variant.default_for({{ T[i] }})
                end),
              {% end %}
            )
          {% end %}
        {% end %}
      end
    end

    # Overload allowing receiver as first positional argument: `sig.connect(receiver) { |args| ... }`
    def connect(receiver : Godot::Object, flags : ConnectFlags = ConnectFlags::None, &block : *T -> Void) : SignalSubscription
      connect(flags: flags, receiver: receiver, &block)
    end

    # Backwards-compatibility helper redirecting to ConnectFlags::OneShot
    def connect_one_shot(&block : *T -> Void) : SignalSubscription
      connect(flags: ConnectFlags::OneShot, &block)
    end

    # Idiomatic shorthand alias for `connect_one_shot`
    def once(&block : *T -> Void) : SignalSubscription
      connect(flags: ConnectFlags::OneShot, &block)
    end

    def emit(*args : *T) : self
      @target.emit_signal(@name, *args)
      self
    end

    def await(timeout_sec : Float64? = nil)
      status = Godot.await(@target, @name, timeout_sec)
      if status.timed_out?
        {% begin %}
          {% if T.size == 0 %}
            AwaitStatus(Nil).timed_out
          {% elsif T.size == 1 %}
            AwaitStatus({{ T[0] }}).timed_out
          {% else %}
            AwaitStatus(Tuple({{ T.splat }})).timed_out
          {% end %}
        {% end %}
      else
        args = status.value!
        {% begin %}
          {% if T.size == 0 %}
            AwaitStatus(Nil).completed(nil)
          {% elsif T.size == 1 %}
            val = if (arg = args[0]?)
              arg.as_t({{ T[0] }})
            else
              Variant.default_for({{ T[0] }})
            end
            AwaitStatus({{ T[0] }}).completed(val)
          {% else %}
            val = {
              {% for i in 0...T.size %}
                (if (arg = args[{{i}}]?)
                  arg.as_t({{ T[i] }})
                else
                  Variant.default_for({{ T[i] }})
                end),
              {% end %}
            }
            AwaitStatus(Tuple({{ T.splat }})).completed(val)
          {% end %}
        {% end %}
      end
    end

    def await(timeout_sec : Number)
      await(timeout_sec.to_f64)
    end

    # Cooperatively awaits this signal, returning the unwrapped value,
    # or raising Godot::TimeoutError if timeout_sec expires.
    def await!(timeout_sec : Float64? = nil)
      status = await(timeout_sec)
      if status.timed_out?
        raise TimeoutError.new("Timed out awaiting typed signal '#{@name}' on #{@target.class.name} after #{timeout_sec}s")
      end
      {% begin %}
        {% if T.size == 0 %}
          nil
        {% else %}
          status.value!
        {% end %}
      {% end %}
    end

    def await!(timeout_sec : Number)
      await!(timeout_sec.to_f64)
    end

    # Cooperatively awaits this signal, returning the value or nil if timeout_sec expires.
    # For 0-argument signals, returns true if completed or false if timed out.
    def await?(timeout_sec : Float64? = nil)
      status = await(timeout_sec)
      if status.timed_out?
        {% begin %}
          {% if T.size == 0 %}
            false
          {% else %}
            nil
          {% end %}
        {% end %}
      else
        {% begin %}
          {% if T.size == 0 %}
            true
          {% else %}
            status.value
          {% end %}
        {% end %}
      end
    end

    def await?(timeout_sec : Number)
      await?(timeout_sec.to_f64)
    end
  end

  alias Signal = BoundSignal

  # Cooperatively awaits a bound signal.
  def self.await(signal : Godot::BoundSignal, timeout_sec : Float64? = nil)
    signal.await(timeout_sec)
  end

  def self.await(signal : Godot::BoundSignal, timeout_sec : Number)
    signal.await(timeout_sec.to_f64)
  end

  def self.await!(signal : Godot::BoundSignal, timeout_sec : Float64? = nil)
    signal.await!(timeout_sec)
  end

  def self.await!(signal : Godot::BoundSignal, timeout_sec : Number)
    signal.await!(timeout_sec.to_f64)
  end

  def self.await?(signal : Godot::BoundSignal, timeout_sec : Float64? = nil)
    signal.await?(timeout_sec)
  end

  def self.await?(signal : Godot::BoundSignal, timeout_sec : Number)
    signal.await?(timeout_sec.to_f64)
  end

  # Cooperatively awaits a typed signal.
  def self.await(signal : Godot::TypedSignal(*T), timeout_sec : Float64? = nil) forall T
    signal.await(timeout_sec)
  end

  def self.await(signal : Godot::TypedSignal(*T), timeout_sec : Number) forall T
    signal.await(timeout_sec.to_f64)
  end

  def self.await!(signal : Godot::TypedSignal(*T), timeout_sec : Float64? = nil) forall T
    signal.await!(timeout_sec)
  end

  def self.await!(signal : Godot::TypedSignal(*T), timeout_sec : Number) forall T
    signal.await!(timeout_sec.to_f64)
  end

  def self.await?(signal : Godot::TypedSignal(*T), timeout_sec : Float64? = nil) forall T
    signal.await?(timeout_sec)
  end

  def self.await?(signal : Godot::TypedSignal(*T), timeout_sec : Number) forall T
    signal.await?(timeout_sec.to_f64)
  end

  # Emits a typed signal with compile-time type safety.
  def self.emit(signal : Godot::TypedSignal(*T), *args : *T) : Void forall T
    signal.emit(*args)
  end

  # Emits a bound signal dynamically on its target object.
  def self.emit(signal : Godot::BoundSignal, *args) : Void
    signal.emit(*args)
  end

end
