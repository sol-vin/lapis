module Godot
  # Strongly-typed signal binding offering compile-time type safety and zero-allocation
  # dispatch via `Lapis::Core::StaticSignalTable`.
  class TypedSignal(*T) < BoundSignal
    getter signal_hash : UInt64

    def initialize(@target : Godot::Object, @name : String)
      super(@target, @name)
      @signal_hash = ::Lapis::Core::StaticSignalTable.fnv1a_64(@name)
    end

    # Returns the zero-allocation `Lapis::Core::StaticSignalSlot(*T)` backing this signal.
    @[ZeroAllocation]
    @[HotPath]
    @[AlwaysInline]
    def static_slot : ::Lapis::Core::StaticSignalSlot(*T)
      ::Lapis::Core::StaticSignalSlot(*T).from_table(
        ::Lapis::Core::StaticSignalTable.global,
        target_id,
        @name,
        @signal_hash
      )
    end

    # Type-safe connect binding directly to `StaticSignalTable` for zero-allocation emission,
    # while maintaining a synchronized `SignalSubscription` for lifecycle and dynamic fallback.
    def connect(flags : ConnectFlags = ConnectFlags::None, receiver : Godot::Object? = nil, &block : *T -> Void) : SignalSubscription
      cb = block
      sub = @target.connect(@name, flags, receiver: receiver) do |args|
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
      sub.typed_fast_path = true
      sub.proc_pointer = cb.pointer
      sub.proc_closure_data = cb.closure_data
      token = ::Lapis::Core::StaticSignalTable.global.bind_by_hash(
        target_id,
        @signal_hash,
        cb,
        once: flags.includes?(ConnectFlags::OneShot),
        subscription: sub
      )
      sub.static_slot_token = token
      sub
    end

    # Overload allowing receiver as first positional argument: `sig.connect(receiver) { |args| ... }`
    def connect(receiver : Godot::Object, flags : ConnectFlags = ConnectFlags::None, &block : *T -> Void) : SignalSubscription
      connect(flags: flags, receiver: receiver, &block)
    end

    # Binds a pre-constructed `Proc(*T, R)` directly to the underlying `StaticSignalTable` slot
    # without intermediate closure wrapping on the typed fast path.
    def bind(
      proc : Proc(*T, R),
      flags : ConnectFlags = ConnectFlags::None,
      once : Bool = false,
      receiver : Godot::Object? = nil
    ) : SignalSubscription forall R
      actual_flags = once ? (flags | ConnectFlags::OneShot) : flags
      sub = @target.connect(@name, actual_flags, receiver: receiver) do |args|
        {% begin %}
          {% if T.size == 0 %}
            proc.call
          {% else %}
            proc.call(
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
      sub.typed_fast_path = true
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      token = ::Lapis::Core::StaticSignalTable.global.bind_by_hash(
        target_id,
        @signal_hash,
        proc,
        once: actual_flags.includes?(ConnectFlags::OneShot),
        subscription: sub
      )
      sub.static_slot_token = token
      sub
    end

    # Block overload for `bind` delegating to `connect` with optional `once` flag.
    def bind(
      once : Bool = false,
      flags : ConnectFlags = ConnectFlags::None,
      receiver : Godot::Object? = nil,
      &block : *T -> Void
    ) : SignalSubscription
      actual_flags = once ? (flags | ConnectFlags::OneShot) : flags
      connect(flags: actual_flags, receiver: receiver, &block)
    end

    # Binds a compile-time typed `Proc(*T, R)` directly to the `StaticSignalTable` slot
    # without allocating a `SignalSubscription`, returning the 64-bit slot token.
    @[AlwaysInline]
    def bind_slot(proc : Proc(*T, R), once : Bool = false) : UInt64 forall R
      ::Lapis::Core::StaticSignalTable.global.bind_by_hash(
        target_id,
        @signal_hash,
        proc,
        once: once
      )
    end

    # Binds a typed block directly to the `StaticSignalTable` slot, returning the 64-bit slot token.
    @[AlwaysInline]
    def bind_slot(once : Bool = false, &block : *T -> Void) : UInt64
      bind_slot(block, once: once)
    end

    # Unbinds a listener by its 64-bit `StaticSignalTable` token.
    @[AlwaysInline]
    def unbind(token : UInt64) : Bool
      ::Lapis::Core::StaticSignalTable.global.unbind(token)
    end

    # Unbinds a typed `Proc(*T, R)` from this signal.
    def unbind(proc : Proc(*T, R)) : Bool forall R
      tid = target_id
      sname = @name
      key = {tid, sname}
      sub_to_unsub = nil
      Godot.signal_subs_mutex.synchronize do
        if list = Godot.signal_subs[key]?
          sub_to_unsub = list.reverse.find { |s| s.proc_pointer == proc.pointer && s.proc_closure_data == proc.closure_data && s.active? }
        end
      end
      if sub = sub_to_unsub
        sub.unsubscribe
        true
      else
        ::Lapis::Core::StaticSignalTable.global.unbind_proc_by_hash(tid, @signal_hash, proc.pointer, proc.closure_data)
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

    # Emits this typed signal with strictly ZERO GC heap allocations on the typed hot path.
    @[ZeroAllocation]
    @[HotPath]
    def emit(*args : *T) : self
      @target.check_alive!
      ::Godot::SignalSpy.record(@target.class.name, @name, {{ T.size }})
      tid = target_id
      ::Lapis::Core::StaticSignalTable.global.emit_by_hash(tid, @signal_hash, *args)
      if Godot.has_untyped_signal_subscribers?(tid, @name)
        emit_untyped_fallback(tid, *args)
      end
      if !@target.pointer.null? && Bridge.available?
        emit_bridge_fallback(*args)
      end
      self
    end

    private def emit_untyped_fallback(tid : UInt64, *args : *T) : Void
      {% if T.size == 0 %}
        Godot.notify_untyped_signal(tid, @name, Godot::EMPTY_VARIANT_ARGS)
      {% else %}
        var_args = args.map { |a| Variant.new(a) }.to_a
        Godot.notify_untyped_signal(tid, @name, var_args)
      {% end %}
    end

    @[ZeroAllocation]
    private def emit_bridge_fallback(*args : *T) : Void
      Godot.in_typed_emit = true
      {% if T.size == 0 %}
        Bridge.emit_signal(@target.pointer, @name)
      {% else %}
        Bridge.emit_signal(@target.pointer, @name, *args)
      {% end %}
      Godot.in_typed_emit = false
    end

    def await(timeout_sec : Float64? = nil)
      status = Godot.await(@target, @name, timeout_sec)
      if status.freed?
        {% begin %}
          {% if T.size == 0 %}
            AwaitStatus(Nil).freed(status.instance_id)
          {% elsif T.size == 1 %}
            AwaitStatus({{ T[0] }}).freed(status.instance_id)
          {% else %}
            AwaitStatus(Tuple({{ T.splat }})).freed(status.instance_id)
          {% end %}
        {% end %}
      elsif status.timed_out?
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
    # or raising `Godot::DisposedObjectError` if the target is freed,
    # or `Godot::TimeoutError` if `timeout_sec` expires.
    def await!(timeout_sec : Float64? = nil)
      status = await(timeout_sec)
      if status.freed?
        {% if flag?(:trace_dead_pointers) %}
          msg = ::Godot::TombstoneTracker.format_disposed_message(status.instance_id)
          raise DisposedObjectError.new(status.instance_id, msg)
        {% else %}
          raise DisposedObjectError.new(status.instance_id, "Target object was destroyed while awaiting signal '#{@name}'")
        {% end %}
      elsif status.timed_out?
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

    # Cooperatively awaits this signal, returning the value or nil if `timeout_sec` expires or the target is freed.
    # For 0-argument signals, returns true if completed, false if timed out, or nil if the target is freed.
    def await?(timeout_sec : Float64? = nil)
      status = await(timeout_sec)
      if status.freed?
        nil
      elsif status.timed_out?
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
