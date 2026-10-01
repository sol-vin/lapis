module Godot
  # **SignalSpy**: Live tracing and diagnostics for signal emissions across Godot nodes.
  #
  # Enabled via `-Dtrace_signals` or `-Dsignal_spy` (or `--trace-signals` in Lapis CLI).
  #
  # Records signal emissions, emitters, argument counts, and timestamps.
  # Automatically emits debug logs to the DiagnosticLogger on the `SignalSpy` channel.
  module SignalSpy
    record SignalEvent,
      emitter_class : String,
      signal_name : String,
      arg_count : Int32,
      timestamp : ::Time

    @@mutex = ::Thread::Mutex.new
    @@events = Array(SignalEvent).new
    class_property? enabled : Bool = {% if flag?(:trace_signals) || flag?(:signal_spy) %} true {% else %} false {% end %}

    def self.record(emitter_class : String, signal_name : String, arg_count : Int32 = 0) : Void
      return unless @@enabled
      @@mutex.synchronize do
        @@events << SignalEvent.new(emitter_class, signal_name, arg_count, ::Time.local)
      end
      ::Godot.log_debug("SignalSpy", "[Signal:Emit] #{emitter_class}##{signal_name} (#{arg_count} args)")
    end

    def self.events : Array(SignalEvent)
      @@mutex.synchronize { @@events.dup }
    end

    def self.event_count : Int32
      @@mutex.synchronize { @@events.size }
    end

    def self.clear! : Void
      @@mutex.synchronize { @@events.clear }
    end
  end
end
