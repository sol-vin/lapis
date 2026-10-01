# Example: Parallel Scaling with Execution Contexts
# Demonstrates dynamic thread scaling, work-stealing, and cross-context communication.

require "wait_group"

# 1. Start a parallel execution context with maximum 4 worker threads
workers = Fiber::ExecutionContext::Parallel.new("WorkerPool", maximum: 4)

# 2. Setup communication channels and synchronization
task_channel = Channel(Int32).new(capacity: 64)
result_channel = Channel(Int64).new(capacity: 64)
wg = WaitGroup.new(4)
counter = Atomic(Int32).new(0)

# 3. Spawn 4 worker fibers into the parallel context
4.times do |worker_id|
  workers.spawn do
    while item = task_channel.receive?
      # Simulate computation
      square = item.to_i64 * item.to_i64
      counter.add(1)
      result_channel.send(square)
    end
  ensure
    wg.done
  end
end

# 4. Feed tasks into the channel from the main context
spawn do
  100.times { |i| task_channel.send(i) }
  task_channel.close
end

# 5. Collect results
total_sum = 0_i64
100.times do
  total_sum += result_channel.receive
end

# 6. Wait for all workers to shut down cleanly
wg.wait
result_channel.close

puts "Completed 100 tasks across parallel workers."
puts "Total processed count: #{counter.get}"
puts "Total sum of squares: #{total_sum}"
