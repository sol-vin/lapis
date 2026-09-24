require "./object"
require "./types"

module Godot
  alias ChannelItem = Nil | Bool | Int32 | Int64 | Float32 | Float64 | String | Godot::Object | Godot::Vector2 | Godot::Vector3 | Godot::Color

  # A thread-safe, actor-style communication channel bridging Crystal OS threads,
  # cooperative gameplay fibers, Godot C++ threads, and GDScript coroutines.
  #
  # Inherits from `Godot::RefCounted` and registers with `ClassDB` as `GodotChannel`.
  #
  # Concurrency Invariant:
  # In Crystal 1.20+, raw OS threads (`Thread.new`) do not possess a fiber execution context
  # (`Fiber#execution_context` is `nil`). Attempting to suspend an empty unbuffered Crystal
  # `Channel(T)` on an OS thread raises `NilAssertionError`. `Godot::Channel` guarantees
  # safety across all threads by utilizing native OS synchronization (`Thread::Mutex` +
  # `Thread::ConditionVariable`) and cooperative yielding (`Fiber.yield`) on the Main Thread.
  class Channel < RefCounted
    getter? closed : Bool = false
    @capacity : Int32
    @buffer : Deque(ChannelItem)
    @mutex : ::Thread::Mutex = ::Thread::Mutex.new
    @not_empty : ::Thread::ConditionVariable = ::Thread::ConditionVariable.new
    @not_full : ::Thread::ConditionVariable = ::Thread::ConditionVariable.new
    @last_received_cache : String? = nil

    def capacity : Int32
      @capacity
    end

    def capacity=(val : Int32)
      @capacity = [val, 1].max
    end

    def initialize(capacity : Int32 = 16)
      @capacity = [capacity, 1].max
      super()
      @buffer = Deque(ChannelItem).new
    end

    def initialize(pointer : Void*, capacity : Int32 = 16)
      @capacity = [capacity, 1].max
      super(pointer)
      @buffer = Deque(ChannelItem).new
    end

    def self.new(capacity : Int32 = 16) : Channel
      ptr = Bridge.construct_object("GodotChannel")
      if !ptr.null?
        if inst = Bridge.find_alive_instance(ptr)
          if ch = inst.as?(Channel)
            ch.init_ref if ch.get_reference_count == 0
            ch.capacity = capacity
            return ch
          end
        end
        inst = allocate
        inst.initialize(ptr, capacity)
        inst.init_ref if inst.get_reference_count == 0
        return inst
      end
      inst = allocate
      inst.initialize(capacity)
      inst
    end

    def self.new(pointer : Void*) : Channel
      inst = allocate
      inst.initialize(pointer)
      inst
    end

    # Returns the current number of queued items
    def size : Int32
      @mutex.synchronize { @buffer.size }
    end

    # Returns true if the channel currently holds no items
    def empty? : Bool
      @mutex.synchronize { @buffer.empty? }
    end

    def is_empty : Bool
      empty?
    end

    # Returns true if the channel buffer is at full capacity
    def full? : Bool
      @mutex.synchronize { @buffer.size >= @capacity }
    end

    def is_full : Bool
      full?
    end

    def is_closed : Bool
      @mutex.synchronize { @closed }
    end

    # Sends an item into the channel, blocking if the channel is full until space becomes available.
    # Returns true on success, or false if the channel was closed.
    # Automatically dispatches `signal received` on Godot's Main Thread via `call_deferred`.
    def send(val : ChannelItem) : Bool
      @mutex.synchronize do
        return false if @closed
        while @buffer.size >= @capacity
          @not_full.wait(@mutex)
          return false if @closed
        end
        @buffer.push(val)
        @not_empty.signal
      end
      notify_received(val)
      true
    end

    # Sends an item into the channel without blocking.
    # Returns true if successfully enqueued, or false if full or closed.
    def try_send(val : ChannelItem) : Bool
      enqueued = false
      @mutex.synchronize do
        return false if @closed || @buffer.size >= @capacity
        @buffer.push(val)
        @not_empty.signal
        enqueued = true
      end
      notify_received(val) if enqueued
      enqueued
    end

    # Receives an item from the channel, blocking the calling thread until an item is available.
    # Safe for background OS worker threads (`Thread.new`, `WorkerThreadPool`).
    # Do NOT call this on Godot's Main Thread; use `#try_receive` or `#await_receive` instead!
    def receive(timeout_sec : Float64? = nil) : ChannelItem?
      start_time = ::Time.instant
      @mutex.synchronize do
        while @buffer.empty?
          return nil if @closed
          if timeout = timeout_sec
            elapsed = (::Time.instant - start_time).total_seconds
            rem = timeout - elapsed
            return nil if rem <= 0.0
            # Wait bounded slice to re-evaluate timeout
            slice = rem < 0.05 ? rem : 0.05
            is_timed_out = false
            @not_empty.wait(@mutex, slice.seconds) { is_timed_out = true }
            return nil if is_timed_out && (::Time.instant - start_time).total_seconds >= timeout
          else
            @not_empty.wait(@mutex)
          end
        end
        item = @buffer.shift
        @not_full.signal
        item
      end
    end

    # Non-blocking receive operation.
    # Returns the next queued item, or nil if the channel is empty.
    # Safe to call anywhere, including in `_process` or timer callbacks on the Main Thread.
    def try_receive : ChannelItem?
      @mutex.synchronize do
        return nil if @buffer.empty?
        item = @buffer.shift
        @not_full.signal
        item
      end
    end

    # Cooperatively awaits an item from the channel inside a Crystal gameplay fiber.
    # Yields execution slices via `Fiber.yield` each frame, preventing engine starvation.
    def await_receive(timeout_sec : Float64? = nil) : ChannelItem?
      start_time = ::Time.instant
      loop do
        if item = try_receive
          return item
        end
        return nil if is_closed
        if timeout = timeout_sec
          if (::Time.instant - start_time).total_seconds >= timeout
            return nil
          end
        end
        Fiber.yield
      end
    end

    # Non-blockingly yields all currently available items in the channel.
    # Returns the number of items drained.
    def drain(&block : ChannelItem -> Void) : Int32
      count = 0
      while item = try_receive
        block.call(item)
        count += 1
      end
      count
    end

    # Non-blockingly drains and returns all currently available items as an Array.
    def drain_all : Array(ChannelItem)
      items = [] of ChannelItem
      drain { |item| items << item }
      items
    end

    # Non-blocking multi-channel multiplexer (select_any).
    # Returns the first channel that has an available item and the item itself,
    # or nil if all provided channels are empty.
    def self.select_any(*channels : Channel) : Tuple(Channel, ChannelItem)?
      select_any(channels.to_a)
    end

    def self.select_any(channels : Array(Channel)) : Tuple(Channel, ChannelItem)?
      channels.each do |ch|
        if item = ch.try_receive
          return {ch, item}
        end
      end
      nil
    end

    # Cooperative multi-channel await multiplexer for gameplay fibers on the Main Thread.
    # Polls channels with fair round-robin scheduling and yields execution slices
    # with Fiber.yield every frame, returning as soon as any channel delivers data or timeout expires.
    def self.await_select(*channels : Channel, timeout_sec : Float64? = nil) : Tuple(Channel, ChannelItem)?
      await_select(channels.to_a, timeout_sec: timeout_sec)
    end

    def self.await_select(channels : Array(Channel), timeout_sec : Float64? = nil) : Tuple(Channel, ChannelItem)?
      return nil if channels.empty?
      start_time = ::Time.instant
      offset = 0
      loop do
        count = channels.size
        count.times do |i|
          idx = (offset + i) % count
          ch = channels[idx]
          if item = ch.try_receive
            return {ch, item}
          end
        end
        offset = (offset + 1) % count

        # If all channels are closed, return nil
        if channels.all?(&.is_closed)
          return nil
        end

        if timeout = timeout_sec
          if (::Time.instant - start_time).total_seconds >= timeout
            return nil
          end
        end
        Fiber.yield
      end
    end

    # Declarative CSP-style select DSL block
    def self.select_any(&block : ChannelSelect -> Void) : Bool
      cs = ChannelSelect.new
      block.call(cs)
      cs.execute
    end

    # Closes the channel. Unblocks all waiting senders and receivers and emits `signal closed`.
    def close : Void
      @mutex.synchronize do
        return if @closed
        @closed = true
        @not_empty.broadcast
        @not_full.broadcast
      end
      if alive? && !@pointer.null?
        call_deferred("emit_signal", "closed")
      else
        Godot.notify_signal(signal_target_id, "closed", [] of Variant)
      end
    end

    # Dispatches the `received` signal to Godot listeners (GDScript, BoundSignals)
    private def notify_received(val : ChannelItem) : Void
      val_str = val.is_a?(Godot::Object) ? (val.alive? ? "<Godot::Object #{val.instance_id}>" : "<DeadObject>") : val.to_s
      if alive? && !@pointer.null?
        call_deferred("emit_signal", "received", val_str)
      else
        Godot.notify_signal(signal_target_id, "received", [Variant.new(val_str)])
      end
    end

    # Dispatches generic virtual methods and ClassDB method calls with raw arguments and return buffer
    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      case method_name
      when "send"
        if args && !args[0].null?
          str = String.new(args[0].as(LibC::Char*))
          success = send(str)
          if ret
            ret.as(UInt8*).value = success ? 1_u8 : 0_u8
          end
        end
      when "try_send"
        if args && !args[0].null?
          str = String.new(args[0].as(LibC::Char*))
          success = try_send(str)
          if ret
            ret.as(UInt8*).value = success ? 1_u8 : 0_u8
          end
        end
      when "receive"
        item = try_receive
        if ret
          if item
            @last_received_cache = item.to_s
            ret.as(LibC::Char**).value = @last_received_cache.not_nil!.to_unsafe
          else
            ret.as(LibC::Char**).value = Pointer(LibC::Char).null
          end
        end
      when "try_receive"
        item = try_receive
        if ret
          if item
            @last_received_cache = item.to_s
            ret.as(LibC::Char**).value = @last_received_cache.not_nil!.to_unsafe
          else
            ret.as(LibC::Char**).value = Pointer(LibC::Char).null
          end
        end
      when "close"
        close
      when "size"
        if ret
          ret.as(Int32*).value = size
        end
      when "is_empty"
        if ret
          ret.as(UInt8*).value = empty? ? 1_u8 : 0_u8
        end
      when "is_full"
        if ret
          ret.as(UInt8*).value = full? ? 1_u8 : 0_u8
        end
      when "is_closed"
        if ret
          ret.as(UInt8*).value = is_closed ? 1_u8 : 0_u8
        end
      else
        super
      end
    end

    # Dynamic method dispatch for GDScript invocation
    def call(method : String, *args) : Void*
      case method
      when "send"
        if args.size > 0
          arg_val = args[0].to_s
          send(arg_val)
        end
        Pointer(Void).null
      when "try_send"
        if args.size > 0
          arg_val = args[0].to_s
          try_send(arg_val)
        end
        Pointer(Void).null
      when "receive"
        item = receive
        item ? Pointer(Void).new(1_u64) : Pointer(Void).null
      when "try_receive"
        item = try_receive
        item ? Pointer(Void).new(1_u64) : Pointer(Void).null
      when "close"
        close
        Pointer(Void).null
      when "size"
        Pointer(Void).new(size.to_u64)
      when "is_empty"
        Pointer(Void).new(empty? ? 1_u64 : 0_u64)
      when "is_full"
        Pointer(Void).new(full? ? 1_u64 : 0_u64)
      when "is_closed"
        Pointer(Void).new(is_closed ? 1_u64 : 0_u64)
      else
        super
      end
    end
  end

  # Strongly-typed generic wrapper around `Godot::Channel` for type-safe Crystal gameplay code.
  #
  # ```
  # channel = Godot::TypedChannel(Godot::Vector3).new(16)
  # channel.send(Godot::Vector3.new(1.0, 2.0, 3.0))
  #
  # spawn do
  #   if pos = channel.await_receive
  #     player.position = pos
  #   end
  # end
  # ```
  class TypedChannel(T)
    getter channel : Godot::Channel

    def initialize(capacity : Int32 = 16)
      @channel = Godot::Channel.new(capacity)
    end

    def capacity : Int32
      @channel.capacity
    end

    def size : Int32
      @channel.size
    end

    def empty? : Bool
      @channel.empty?
    end

    def full? : Bool
      @channel.full?
    end

    def closed? : Bool
      @channel.closed?
    end

    def send(val : T) : Bool
      {% if T < Godot::Object %}
        @channel.send(val.as(Godot::Object))
      {% else %}
        @channel.send(val.as(ChannelItem))
      {% end %}
    end

    def try_send(val : T) : Bool
      {% if T < Godot::Object %}
        @channel.try_send(val.as(Godot::Object))
      {% else %}
        @channel.try_send(val.as(ChannelItem))
      {% end %}
    end

    def receive(timeout_sec : Float64? = nil) : T?
      if item = @channel.receive(timeout_sec)
        {% if T < Godot::Object %}
          if obj = item.as?(Godot::Object)
            obj.as?(T)
          end
        {% else %}
          item.as?(T)
        {% end %}
      end
    end

    def try_receive : T?
      if item = @channel.try_receive
        {% if T < Godot::Object %}
          if obj = item.as?(Godot::Object)
            obj.as?(T)
          end
        {% else %}
          item.as?(T)
        {% end %}
      end
    end

    def await_receive(timeout_sec : Float64? = nil) : T?
      if item = @channel.await_receive(timeout_sec)
        {% if T < Godot::Object %}
          if obj = item.as?(Godot::Object)
            obj.as?(T)
          end
        {% else %}
          item.as?(T)
        {% end %}
      end
    end

    def close : Void
      @channel.close
    end

    def destroy : Void
      close
    end

    def is_empty : Bool
      @channel.is_empty
    end

    def is_full : Bool
      @channel.is_full
    end

    def is_closed : Bool
      @channel.is_closed
    end

    def drain(&block : T -> Void) : Int32
      count = 0
      while item = try_receive
        block.call(item)
        count += 1
      end
      count
    end

    def drain_all : Array(T)
      items = [] of T
      drain { |item| items << item }
      items
    end
  end

  # CSP-style declarative multiplexing helper for `Godot::Channel.select_any`
  class ChannelSelect
    alias ClauseProc = Proc(ChannelItem, Nil)
    @clauses : Array(Tuple(Channel, ClauseProc))
    @else_block : Proc(Nil)?

    def initialize
      @clauses = Array(Tuple(Channel, ClauseProc)).new
      @else_block = nil
    end

    def receive(channel : Channel, &block : ChannelItem ->)
      cb = Proc(ChannelItem, Nil).new do |item|
        block.call(item)
        nil
      end
      @clauses << {channel, cb}
    end

    def receive(typed_channel : TypedChannel(T), &block : T ->) forall T
      ch = typed_channel.channel
      cb = Proc(ChannelItem, Nil).new do |item|
        if casted = item.as?(T)
          block.call(casted)
        end
        nil
      end
      @clauses << {ch, cb}
    end

    def else(&block : ->)
      @else_block = Proc(Nil).new do
        block.call
        nil
      end
    end

    def execute : Bool
      @clauses.each do |ch, callback|
        if item = ch.try_receive
          callback.call(item)
          return true
        end
      end
      if eb = @else_block
        eb.call
        return true
      end
      false
    end
  end
end

{% unless flag?(:libgodot_addon) %}
  # Register GodotChannel with LibGodot ClassRegistry so Godot discovers it in ClassDB
  ::Godot::ClassRegistry.register(
    ::Godot::ClassRegistry::Entry.new(
      "GodotChannel",
      "RefCounted",
      ->(godot_ptr : Void*) {
        inst = ::Godot::Channel.new(godot_ptr)
        inst.as(::Godot::Object)
      },
      false, # is_tool
      false, # has_ready
      false, # has_process
      false, # has_physics_process
      false, # has_enter_tree
      false, # has_exit_tree
      false, # has_input
      false, # has_unhandled_input
      false, # has_unhandled_key_input
      false, # has_shortcut_input
      false, # has_gui_input
      [
      ::Godot::PropertyInfo.new("capacity", "Int32", 2, 0_u32, "", 6_u32),
    ],
      [
        ::Godot::SignalInfo.new("received", [::Godot::SignalArgInfo.new("value", 4)]),
        ::Godot::SignalInfo.new("closed", [] of ::Godot::SignalArgInfo),
      ],
      "",    # icon_path
      false, # is_abstract
      [] of NamedTuple(name: String, rpc_mode: Int32, transfer_mode: Int32, call_local: Bool, channel: Int32)
    )
  )
{% end %}
