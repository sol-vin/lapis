module Godot
  # **DispatchProfiler**: Nanosecond execution profiler for Crystal method dispatches and virtual callbacks.
  #
  # Enabled via `-Dprofile_dispatches` (or `--profile-dispatches` in Lapis CLI).
  #
  # Tracks call counts, total elapsed nanoseconds, minimum, maximum, and average execution
  # times for exported Crystal methods, virtual lifecycle hooks (_process, _physics_process),
  # and signal callbacks.
  module DispatchProfiler
    class ProfileMetric
      property count : Int64 = 0_i64
      property total_ns : Float64 = 0.0
      property min_ns : Float64 = Float64::INFINITY
      property max_ns : Float64 = 0.0

      def avg_ns : Float64
        return 0.0 if @count == 0
        @total_ns / @count.to_f64
      end

      def avg_ms : Float64
        avg_ns / 1_000_000.0
      end

      def total_ms : Float64
        @total_ns / 1_000_000.0
      end

      def record(elapsed_ns : Float64) : Void
        @count += 1
        @total_ns += elapsed_ns
        @min_ns = elapsed_ns if elapsed_ns < @min_ns
        @max_ns = elapsed_ns if elapsed_ns > @max_ns
      end
    end

    @@mutex = ::Thread::Mutex.new
    @@metrics = Hash(String, ProfileMetric).new
    class_property? enabled : Bool = {% if flag?(:profile_dispatches) %} true {% else %} false {% end %}

    def self.record(class_name : String, method_name : String, elapsed_ns : Float64) : Void
      return unless @@enabled
      key = "#{class_name}##{method_name}"
      @@mutex.synchronize do
        metric = @@metrics[key] ||= ProfileMetric.new
        metric.record(elapsed_ns)
      end
    end

    def self.metrics : Hash(String, ProfileMetric)
      @@mutex.synchronize { @@metrics.dup }
    end

    def self.reset! : Void
      @@mutex.synchronize { @@metrics.clear }
    end

    def self.dump_profile(io : IO = STDOUT, top_n : Int32 = 20) : Void
      snapshot = metrics
      if snapshot.empty?
        io.puts "[DispatchProfiler] No dispatch metrics recorded."
        return
      end

      sorted = snapshot.to_a.sort_by { |_k, m| -m.total_ns }.first(top_n)

      io.puts "=========================================================================================="
      io.puts "[DispatchProfiler] Method Dispatch Profile (Top #{sorted.size} by Total Execution Time)"
      io.puts "=========================================================================================="
      io.printf("%-40s | %10s | %12s | %12s | %12s\n", "Method", "Calls", "Total (ms)", "Avg (ms)", "Max (ms)")
      io.puts "-----------------------------------------+------------+--------------+--------------+--------------"
      sorted.each do |key, m|
        io.printf("%-40s | %10d | %12.4f | %12.4f | %12.4f\n", key, m.count, m.total_ms, m.avg_ms, m.max_ns / 1_000_000.0)
      end
      io.puts "=========================================================================================="
    end
  end
end
