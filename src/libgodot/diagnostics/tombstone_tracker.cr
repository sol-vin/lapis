module Godot
  # **TombstoneTracker**: Maintains a history of recently freed Godot objects
  # to report rich diagnostic context whenever a dead pointer is accessed.
  #
  # Enabled via `-Dtrace_dead_pointers` (or `--trace-dead-pointers` in Lapis CLI).
  #
  # When an object is explicitly destroyed or freed, records its instance ID, class name,
  # destruction callsite (__FILE__, __LINE__), and timestamp in a fixed-size ring buffer.
  #
  # When `DisposedObjectError` is raised in `check_alive!`, looks up the tombstone
  # and formats an actionable error message explaining where the object was destroyed.
  module TombstoneTracker
    record Tombstone,
      instance_id : UInt64,
      class_name : String,
      file : String,
      line : Int32,
      timestamp : ::Time

    MAX_TOMBSTONES = 256
    @@mutex = ::Thread::Mutex.new
    @@tombstones = Hash(UInt64, Tombstone).new
    @@order = Deque(UInt64).new
    class_property? enabled : Bool = {% if flag?(:trace_dead_pointers) %} true {% else %} false {% end %}

    def self.record_freed(instance_id : UInt64, class_name : String, file : String = __FILE__, line : Int32 = __LINE__) : Void
      return unless @@enabled
      return if instance_id == 0_u64
      @@mutex.synchronize do
        if @@order.size >= MAX_TOMBSTONES
          oldest = @@order.shift
          @@tombstones.delete(oldest)
        end
        @@tombstones[instance_id] = Tombstone.new(
          instance_id: instance_id,
          class_name: class_name,
          file: file,
          line: line,
          timestamp: ::Time.local
        )
        @@order << instance_id
      end
    end

    def self.find(instance_id : UInt64) : Tombstone?
      @@mutex.synchronize { @@tombstones[instance_id]? }
    end

    def self.format_disposed_message(instance_id : UInt64) : String
      if t = find(instance_id)
        "Godot::DisposedObjectError: #{t.class_name} (Instance ID: #{instance_id}) was destroyed at #{t.file}:#{t.line} (#{t.timestamp.to_s("%H:%M:%S.%3N")}). Attempted to access dead engine pointer!"
      else
        "Godot::DisposedObjectError: Object #{instance_id} was disposed by Godot or GDScript. Attempted to access dead engine pointer!"
      end
    end

    def self.clear! : Void
      @@mutex.synchronize do
        @@tombstones.clear
        @@order.clear
      end
    end
  end
end
