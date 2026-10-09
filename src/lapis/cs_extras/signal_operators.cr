# =============================================================================
# Lapis C# Extras: Signal Compound Assignment (+ / -) Operators
# =============================================================================
# Syntactic sugar mimicking C# event subscription patterns (`event += handler`
# and `event -= handler`) for Godot BoundSignal and TypedSignal instances.

module Godot
  class BoundSignal
    # Operator `+` for 1-argument typed Proc (supports `sig += ->(player : Player) { ... }`)
    def +(proc : Proc(T, R)) : self forall T, R
      sub = @target.connect(@name) do |args|
        if args.size >= 1
          raw = args[0].raw
          if raw_node = raw.as?(Godot::Node)
            if casted = Godot::Node.cast_to?(raw_node, T)
              proc.call(casted)
            end
          elsif raw.is_a?(T)
            proc.call(raw)
          elsif raw.is_a?(Int) && (num = raw.to_i32.as?(T) || raw.to_i64.as?(T))
            proc.call(num)
          elsif raw.is_a?(Float) && (flt = raw.to_f32.as?(T) || raw.to_f64.as?(T))
            proc.call(flt)
          end
        end
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      self
    end

    # Operator `+` for 2-argument typed Proc (supports `sig += ->(player : Player, sword : Sword) { ... }`)
    def +(proc : Proc(T0, T1, R)) : self forall T0, T1, R
      sub = @target.connect(@name) do |args|
        if args.size >= 2
          c0 : T0? = nil
          raw0 = args[0].raw
          if raw0.is_a?(Godot::Node)
            c0 = Godot::Node.cast_to?(raw0, T0)
          elsif raw0.is_a?(T0)
            c0 = raw0
          elsif raw0.is_a?(Int)
            c0 = raw0.to_i32.as?(T0) || raw0.to_i64.as?(T0)
          elsif raw0.is_a?(Float)
            c0 = raw0.to_f32.as?(T0) || raw0.to_f64.as?(T0)
          end

          c1 : T1? = nil
          raw1 = args[1].raw
          if raw1.is_a?(Godot::Node)
            c1 = Godot::Node.cast_to?(raw1, T1)
          elsif raw1.is_a?(T1)
            c1 = raw1
          elsif raw1.is_a?(Int)
            c1 = raw1.to_i32.as?(T1) || raw1.to_i64.as?(T1)
          elsif raw1.is_a?(Float)
            c1 = raw1.to_f32.as?(T1) || raw1.to_f64.as?(T1)
          end

          if !c0.nil? && !c1.nil?
            proc.call(c0, c1)
          end
        end
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      self
    end

    # Operator `+` syntactic sugar for `connect` with a Proc (supports `sig += ->handler`)
    def +(proc : Proc(::Array(Variant), R)) : self forall R
      sub = @target.connect(@name) do |args|
        proc.call(args)
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      self
    end

    # Operator `+` syntactic sugar for `connect` with a 0-argument Proc (supports `sig += ->handler`)
    def +(proc : Proc(R)) : self forall R
      sub = @target.connect(@name) do
        proc.call
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      self
    end

    # Operator `+` syntactic sugar accepting a SignalSubscription directly
    def +(sub : SignalSubscription) : self
      self
    end

    # Operator `-` syntactic sugar for disconnecting a Proc (supports `sig -= ->handler`)
    def -(proc : Proc) : self
      tid = target_id
      sname = @name
      key = {tid, sname}
      sub_to_unsub = nil
      Godot.signal_subs_mutex.synchronize do
        if list = Godot.signal_subs[key]?
          sub_to_unsub = list.reverse.find { |s| s.proc_pointer == proc.pointer && s.proc_closure_data == proc.closure_data && s.active? }
        end
      end
      sub_to_unsub.try(&.unsubscribe)
      self
    end

    # Operator `-` syntactic sugar for disconnecting a SignalSubscription (supports `sig -= sub`)
    def -(sub : SignalSubscription) : self
      sub.unsubscribe
      self
    end
  end

  class TypedSignal(*T) < BoundSignal
    # Operator `+` syntactic sugar for `connect` with a Proc accepting raw Variant array
    def +(proc : Proc(::Array(Variant), R)) : self forall R
      sub = @target.connect(@name) do |args|
        proc.call(args)
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      self
    end

    # Operator `+` for 1-argument typed Proc (supports exact types and downcasting)
    def +(proc : Proc(U0, R)) : self forall U0, R
      sub = @target.connect(@name) do |args|
        if args.size >= 1
          raw = args[0].raw
          if raw.is_a?(Godot::Object)
            if casted = raw.as_a?(U0)
              proc.call(casted)
            end
          elsif raw.is_a?(U0)
            proc.call(raw)
          elsif raw.is_a?(Int) && (num = raw.to_i32.as?(U0) || raw.to_i64.as?(U0))
            proc.call(num)
          elsif raw.is_a?(Float) && (flt = raw.to_f32.as?(U0) || raw.to_f64.as?(U0))
            proc.call(flt)
          end
        end
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      self
    end

    # Operator `+` for 2-argument typed Proc (supports exact types and downcasting)
    def +(proc : Proc(U0, U1, R)) : self forall U0, U1, R
      sub = @target.connect(@name) do |args|
        if args.size >= 2
          c0 : U0? = nil
          raw0 = args[0].raw
          if raw0.is_a?(Godot::Object)
            c0 = raw0.as_a?(U0)
          elsif raw0.is_a?(U0)
            c0 = raw0
          elsif raw0.is_a?(Int)
            c0 = raw0.to_i32.as?(U0) || raw0.to_i64.as?(U0)
          elsif raw0.is_a?(Float)
            c0 = raw0.to_f32.as?(U0) || raw0.to_f64.as?(U0)
          end

          c1 : U1? = nil
          raw1 = args[1].raw
          if raw1.is_a?(Godot::Object)
            c1 = raw1.as_a?(U1)
          elsif raw1.is_a?(U1)
            c1 = raw1
          elsif raw1.is_a?(Int)
            c1 = raw1.to_i32.as?(U1) || raw1.to_i64.as?(U1)
          elsif raw1.is_a?(Float)
            c1 = raw1.to_f32.as?(U1) || raw1.to_f64.as?(U1)
          end

          if !c0.nil? && !c1.nil?
            proc.call(c0, c1)
          end
        end
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      self
    end

    # Operator `+` syntactic sugar for 0-argument Proc (supports `sig += ->handler`)
    def +(proc : Proc(R)) : self forall R
      sub = @target.connect(@name) do
        proc.call
      end
      sub.proc_pointer = proc.pointer
      sub.proc_closure_data = proc.closure_data
      self
    end

    # Operator `+` syntactic sugar accepting a SignalSubscription directly
    def +(sub : SignalSubscription) : self
      self
    end

    # Operator `-` syntactic sugar for disconnecting a Proc (supports `sig -= ->handler`)
    def -(proc : Proc) : self
      tid = target_id
      sname = @name
      key = {tid, sname}
      sub_to_unsub = nil
      Godot.signal_subs_mutex.synchronize do
        if list = Godot.signal_subs[key]?
          sub_to_unsub = list.reverse.find { |s| s.proc_pointer == proc.pointer && s.proc_closure_data == proc.closure_data && s.active? }
        end
      end
      sub_to_unsub.try(&.unsubscribe)
      self
    end

    # Operator `-` syntactic sugar for disconnecting a SignalSubscription (supports `sig -= sub`)
    def -(sub : SignalSubscription) : self
      sub.unsubscribe
      self
    end
  end
end
