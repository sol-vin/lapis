module Godot
  # **LeakTracker**: Tracks all active Crystal Godot object instances for leak detection.
  #
  # Enabled via `-Dleak_tracker` or `-Dtrace_allocations` (or `--leak-tracker` in Lapis CLI).
  #
  # When active, records allocation metadata (class name, source location, timestamp)
  # upon object initialization, and unregisters upon object deallocation.
  #
  # At program exit, if any objects remain uncollected, prints a formatted report
  # showing the exact allocation callsite for every leaked object.
  module LeakTracker
    record AllocationInfo,
      instance_id : UInt64,
      class_name : String,
      file : String,
      line : Int32,
      timestamp : ::Time

    @@mutex = ::Thread::Mutex.new
    @@allocations = Hash(UInt64, AllocationInfo).new
    class_property? enabled : Bool = {% if flag?(:leak_tracker) || flag?(:trace_allocations) %} true {% else %} false {% end %}

    # Registers a newly allocated Godot object instance
    def self.register(instance_id : UInt64, class_name : String, file : String, line : Int32) : Void
      return unless @@enabled
      return if instance_id == 0_u64
      @@mutex.synchronize do
        @@allocations[instance_id] = AllocationInfo.new(
          instance_id: instance_id,
          class_name: class_name,
          file: file,
          line: line,
          timestamp: ::Time.local
        )
      end
    end

    # Unregisters a destroyed or freed object instance
    def self.unregister(instance_id : UInt64) : Void
      return unless @@enabled
      return if instance_id == 0_u64
      @@mutex.synchronize do
        @@allocations.delete(instance_id)
      end
    end

    # Returns the count of currently live tracked objects
    def self.live_count : Int32
      @@mutex.synchronize { @@allocations.size }
    end

    # Returns all currently tracked allocations
    def self.live_allocations : Array(AllocationInfo)
      @@mutex.synchronize { @@allocations.values }
    end

    # Clears all tracked allocations (useful for test isolation)
    def self.clear! : Void
      @@mutex.synchronize { @@allocations.clear }
    end

    # Dumps a formatted leak summary report to the specified IO
    def self.dump_leaks(io : IO = STDERR) : Int32
      leaks = live_allocations
      if leaks.empty?
        io.puts "[LeakTracker] Clean shutdown: 0 leaked Crystal Godot objects."
        return 0
      end

      io.puts "================================================================================"
      io.puts "[LeakTracker] WARNING: #{leaks.size} Crystal Godot object(s) were leaked!"
      io.puts "================================================================================"
      leaks.each_with_index do |info, idx|
        io.puts "  #{idx + 1}. [#{info.class_name}] Instance ID: #{info.instance_id}"
        io.puts "     Allocated at : #{info.file}:#{info.line}"
        io.puts "     Timestamp    : #{info.timestamp.to_s("%H:%M:%S.%3N")}"
      end
      io.puts "================================================================================"
      leaks.size
    end
  end
end

{% if flag?(:leak_tracker) || flag?(:trace_allocations) %}
  at_exit do
    Godot::LeakTracker.dump_leaks if Godot::LeakTracker.live_count > 0
  end
{% end %}
