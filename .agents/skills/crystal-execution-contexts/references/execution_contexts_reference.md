# Crystal Execution Contexts: Architecture & Technical Reference

This reference document details the technical internals, scheduling mechanics, and behavioral changes introduced with Crystal's **Execution Contexts** multithreading architecture.

---

## 1. Architectural Motivation: Beyond Preview MT

### The Limits of Preview MT (Crystal 0.28 - 1.12)
Under the legacy Preview MT model:
1. **Fixed Thread Allocation**: The runtime started a static number of threads (`CRYSTAL_WORKERS`).
2. **Thread Pinning**: When a fiber spawned, it was tied to the thread on which it was created. It could never migrate to another thread.
3. **Head-of-Line Blocking**: If a fiber ran CPU-intensive calculations or executed a blocking syscall (like DNS resolution via `getaddrinfo(3)`), its host thread froze. Other runnable fibers pinned to that same thread starved, while other OS threads sat idle.
4. **No Thread Ownership**: Game loops, GUI event loops (e.g., GTK, SDL, ImGui), and thread-sensitive native bindings could not reliably own a dedicated OS thread.

### The Execution Contexts Solution
Execution Contexts introduce a decoupled interface between fibers and OS threads:
- Fibers belong to an **execution context**, which defines their scheduling rules.
- Schedulers operate on a dynamic pool of worker threads.
- Parallel contexts implement **work-stealing**: idle schedulers pull runnable fibers from busy schedulers across threads.
- Non-blocking cooperative rescheduling moves schedulers off threads when blocking syscalls occur.

---

## 2. In-Depth Context Types

### `Fiber::ExecutionContext::Parallel`
```crystal
parallel = Fiber::ExecutionContext::Parallel.new("Workers", maximum: 8)
```
- **Structure**: Maintains an internal `GlobalQueue` and an array of `Scheduler` instances backed by a shared `ThreadPool`.
- **Dynamic Thread Scaling**: Does not greedily allocate all `maximum` threads at boot. Threads scale dynamically between 0 and `maximum` based on demand.
- **Work-Stealing**: Each scheduler has a local runnable queue (`Runnables`). When a scheduler runs out of work, it attempts to steal fibers from the local queues of sibling schedulers or the global queue.
- **Resumption Semantics**: A fiber may start on OS thread 2, suspend on `channel.receive`, and be resumed on OS thread 5.

### `Fiber::ExecutionContext::Concurrent`
```crystal
concurrent = Fiber::ExecutionContext::Concurrent.new("Subsystem")
```
- **Structure**: Subclasses `Parallel` configured with a fixed capacity of 1.
- **Single-Threaded Fiber Execution**: Guarantees that fibers belonging to this context **never run in parallel to each other**.
- **Cross-Context Parallelism**: Fibers in this context run in parallel with fibers in other contexts (e.g., `default` or other `Parallel` contexts).
- **Reduced Synchronization**: Intra-context operations do not require atomic operations or mutex locks between fibers in the same context, provided they do not yield.
- **Thread Switching Caveat**: While fibers do not run in parallel, the context is **not** pinned to a fixed OS thread. If a fiber invokes a blocking syscall, the scheduler may jump to another OS thread.
- **Resize Prohibition**: Calling `concurrent.resize(N)` raises an `ArgumentError`.

### `Fiber::ExecutionContext::Isolated`
```crystal
isolated = Fiber::ExecutionContext::Isolated.new("DedicatedWorker") do
  # Dedicated loop
end
isolated.wait
```
- **Structure**: Allocates a dedicated system thread from the pool. Holds a single main fiber.
- **Thread Ownership**: The fiber **owns the thread for its entire lifetime**. Neither the fiber nor the scheduler will ever switch to another OS thread.
- **Concurrency Disabled**: Cannot spawn new fibers into the isolated context. Calls to `spawn` from within the isolated fiber automatically route to `@spawn_context` (defaulting to `ExecutionContext.default`).
- **Blocking Permitted**: The fiber can block the thread indefinitely (e.g., blocking C calls, synchronous socket I/O, OS sleeps) without impacting any other fiber or scheduler.
- **Lifecycle**: Call `isolated.wait` to join the fiber and capture/re-raise unhandled exceptions.

### `Fiber::ExecutionContext.default`
- Automatically initialized on the process main thread.
- Implemented as an instance of `Fiber::ExecutionContext::Parallel` with `maximum = 1` by default.
- Backwards-compatible: Existing single-threaded code runs unmodified without concurrency race conditions.
- Can be dynamically scaled to all CPU cores via:
  ```crystal
  Fiber::ExecutionContext.default.resize(maximum: System.cpu_count)
  ```

---

## 3. Scheduling & Preemption Mechanics

### Work-Stealing
In parallel contexts, fibers are distributed across schedulers. When a scheduler becomes idle:
1. It inspects its local queue.
2. If empty, it checks the context's `GlobalQueue`.
3. If still empty, it steals from the runnables queue of another active scheduler.
4. If no work is found, the thread parks itself (`@parked.add(1)`) until signaled by a newly enqueued fiber.

### Schedulers Switching Threads on Syscalls
Certain libc/system calls are inherently synchronous and cannot be converted to non-blocking epoll/IOCP/kqueue events (for example, `getaddrinfo(3)`).
When a fiber enters such a syscall:
1. `enter_syscall` is invoked.
2. The runtime detects that the underlying thread is about to block.
3. The scheduler unbinds from the blocking thread and spawns/checks out a fresh OS thread from the `ThreadPool`.
4. Other runnable fibers continue executing on the new thread without delay.
5. When the syscall completes, `leave_syscall?` reconciles the fiber back into the scheduler.

> [!WARNING]
> This behavior means that **even single-threaded/concurrent contexts can change OS thread IDs** when making blocking network/syscall calls. Code relying on OS Thread IDs (`GetCurrentThreadId()`, `pthread_self()`) or Thread-Local Storage (TLS) across syscalls will observe thread ID transitions.

---

## 4. Communication & Synchronization Semantics

### `Channel(T)` Across Contexts
- Channels function transparently across all execution contexts (`default`, `Concurrent`, `Parallel`, `Isolated`).
- Communicating across contexts introduces thread-level synchronization (atomic lock/unlock, cross-thread waking), which is slightly slower than intra-context fiber handoffs.
- **Channel Buffering**:
  ```crystal
  # Safe across threads and execution contexts:
  channel = Channel(MyPayload).new(capacity: 32)
  ```
  Unbuffered channels suspend fibers when no receiver is ready. On raw OS threads without an execution context, this raises `NilAssertionError: Fiber#execution_context cannot be nil`. Always use buffered channels when bridging across threads.

### Mutex Primitives: `Sync::Mutex` vs `::Thread::Mutex`
- `Sync::Mutex` (alias `Mutex.new` in modern Crystal): Suspends fibers via the `ExecutionContext`. Ideal for fiber synchronization.
- `::Thread::Mutex`: Native OS-level mutex (Windows critical section / pthread mutex). Does not interact with fiber scheduling. **Must be used when synchronizing raw `Thread.new` instances or protecting shared collections from C callbacks.**

---

## 5. Auto-Scaling ("Slow-Parallelism") and Benchmarks

The execution context runtime uses an adaptive load monitor that adjusts thread allocation at **~100 ms intervals**:
- When fiber load surges, additional threads are activated from the pool.
- When fiber queues drain, surplus worker threads spin down and park.

### Benchmarking Implications
Microbenchmarks that measure tight loops completing in less than 100 ms will often execute entirely on a single core, leading to inaccurate performance measurements.

**Benchmarking Best Practices**:
1. Run benchmarks with sufficient workload (>500 ms per iteration).
2. Explicitly warm up the parallel context prior to timing:
   ```crystal
   wg = WaitGroup.new(System.cpu_count)
   System.cpu_count.times do
     parallel.spawn do
       # Warmup work
       wg.done
     end
   end
   wg.wait
   ```

---

## 6. Migration Checklist from Preview MT

1. **Remove `same_thread: true`**:
   - Replace with a `Concurrent` execution context or use `Sync::Mutex` / `Atomic`.
2. **Update Environment Variable Handlers**:
   - Replace passive reliance on `CRYSTAL_WORKERS` with explicit `resize`:
     ```crystal
     if workers = ENV["CRYSTAL_WORKERS"]?.try(&.to_i?)
       Fiber::ExecutionContext.default.resize(workers)
     end
     ```
3. **Audit Thread-Local State**:
   - Verify that code does not assume `Thread.current` or native TLS remains identical across `yield`, `await`, or blocking I/O calls.
4. **Audit C Library Call Sites**:
   - If C libraries require main-thread execution, wrap them in `Isolated` contexts or confine them to the engine main loop.
