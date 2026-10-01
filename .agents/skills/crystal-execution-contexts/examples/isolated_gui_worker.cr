# Example: Isolated Execution Context for Blocking Native Tasks / Event Loops
# Demonstrates how a single fiber can own an OS thread for its lifetime.

# 1. Channels for cross-thread messaging
inbound = Channel(String).new(8)
outbound = Channel(String).new(8)

# 2. Start an isolated execution context
# The fiber passed in the block owns the OS thread until it returns.
worker = Fiber::ExecutionContext::Isolated.new("DedicatedWorker") do
  # Inside isolated context: blocking I/O, C event loops, or system calls
  # will never block any other fiber in the application.
  puts "[Worker] Running on dedicated OS thread: #{Thread.current}"

  while message = inbound.receive?
    break if message == "STOP"
    puts "[Worker] Received: #{message}"
    outbound.send("Processed: #{message.upcase}")
  end

  puts "[Worker] Terminating dedicated thread."
end

# 3. Main context sends commands and reads responses
["hello", "game_event", "STOP"].each do |msg|
  inbound.send(msg)
  if msg != "STOP"
    reply = outbound.receive
    puts "[Main] Got reply: #{reply}"
  end
end

# 4. Await clean termination of the isolated context
worker.wait
puts "[Main] Dedicated worker joined successfully."
