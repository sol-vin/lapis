# Example: Concurrent Execution Context for Subsystems
# Demonstrates cooperative single-threaded concurrency without parallel data races.

require "wait_group"

# 1. Start a Concurrent execution context
# Fibers in this context run concurrently to each other, but NEVER in parallel.
subsystem = Fiber::ExecutionContext::Concurrent.new("Subsystem")

inbox = Channel(Int32).new(32)
wg = WaitGroup.new(4)

# Shared state accessed exclusively by fibers in this single-threaded context.
# Because fibers in a Concurrent context never run in parallel to each other,
# non-yielding operations on this variable do not require mutex locks.
shared_accumulator = 0

# 2. Spawn 4 worker fibers into the concurrent context
4.times do |id|
  subsystem.spawn do
    while item = inbox.receive?
      # Safe from parallel race conditions between fibers in this context:
      shared_accumulator += item
    end
  ensure
    wg.done
  end
end

# 3. Send items from the default context (runs in parallel to the subsystem)
spawn do
  50.times { |i| inbox.send(i + 1) }
  inbox.close
end

# 4. Wait for all subsystem fibers to complete
wg.wait

puts "Subsystem processed all items concurrently."
puts "Accumulator total (sum 1..50): #{shared_accumulator}"
# sum 1..50 = 50 * 51 / 2 = 1275
