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
      args = Godot.await(@target, @name, timeout_sec)
      {% begin %}
        {% if T.size == 0 %}
          nil
        {% elsif T.size == 1 %}
          if (arg = args[0]?)
            arg.as_t({{ T[0] }})
          else
            Variant.default_for({{ T[0] }})
          end
        {% else %}
          {
            {% for i in 0...T.size %}
              (if (arg = args[{{i}}]?)
                arg.as_t({{ T[i] }})
              else
                Variant.default_for({{ T[i] }})
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

end
