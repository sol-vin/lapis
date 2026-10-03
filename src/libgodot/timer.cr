# =============================================================================
# LibGodot - Lifecycle-Safe Cancellable Timers & Coroutine Sugar
# =============================================================================

module Godot
  # A handle representing an active recurring or delayed timer.
  # Provides inspection and early cancellation/pausing capabilities.
  class TimerHandle
    getter? running : Bool = true
    getter? paused : Bool = false
    getter? cancelled : Bool = false
    getter elapsed_time : Float64 = 0.0
    getter tick_count : Int64 = 0_i64
    getter interval_sec : Float64
    getter node : Godot::Node?

    def initialize(@interval_sec : Float64, @node : Godot::Node? = nil)
    end

    # Cancels the timer immediately. No further callbacks will fire.
    def cancel : Void
      @running = false
      @cancelled = true
    end

    # Alias for cancel
    def stop : Void
      cancel
    end

    # Temporarily pauses tick accumulation
    def pause : Void
      @paused = true
    end

    # Resumes tick accumulation
    def resume : Void
      @paused = false
    end

    # Resets elapsed time and tick counter
    def reset : Void
      @elapsed_time = 0.0
      @tick_count = 0_i64
    end

    # Advances time by delta, returning true if the timer should tick
    def advance(delta : Float64) : Bool
      return false unless @running && !@paused
      if n = @node
        if !n.alive?
          cancel
          return false
        end
      end
      @elapsed_time += delta
      if @elapsed_time >= @interval_sec
        @elapsed_time -= @interval_sec
        @tick_count += 1_i64
        true
      else
        false
      end
    end
  end

  # Schedules a recurring timer that fires every `interval`.
  # If `node` is provided, automatically cancels when the node is destroyed.
  def self.every(interval : ::Time::Span | Number, node : Godot::Node? = nil, &block : TimerHandle -> Void) : TimerHandle
    interval_sec = interval.is_a?(::Time::Span) ? interval.total_seconds : interval.to_f64
    handle = TimerHandle.new(interval_sec, node)
    spawn do
      last_tick = ::Time.instant
      while handle.running?
        if n = node
          unless n.alive?
            handle.cancel
            break
          end
        end
        Fiber.yield
        now = ::Time.instant
        dt = (now - last_tick).total_seconds
        last_tick = now
        if handle.advance(dt)
          begin
            block.call(handle)
          rescue ex
            Godot.printerr("[TimerHandle] Unhandled exception in timer block: #{ex.message}")
            handle.cancel
            break
          end
        end
      end
    end
    handle
  end

  # Zero-argument block overload for `every`
  def self.every(interval : ::Time::Span | Number, node : Godot::Node? = nil, &block : -> Void) : TimerHandle
    every(interval, node: node) { |_handle| block.call }
  end

  # Schedules a one-shot delay that fires after `delay`.
  # If `node` is provided, automatically cancels if the node is destroyed before expiry.
  def self.after(delay : ::Time::Span | Number, node : Godot::Node? = nil, &block : TimerHandle -> Void) : TimerHandle
    delay_sec = delay.is_a?(::Time::Span) ? delay.total_seconds : delay.to_f64
    handle = TimerHandle.new(delay_sec, node)
    spawn do
      start_time = ::Time.instant
      while handle.running?
        if n = node
          unless n.alive?
            handle.cancel
            break
          end
        end
        Fiber.yield
        if !handle.paused? && (::Time.instant - start_time).total_seconds >= delay_sec
          begin
            block.call(handle)
          rescue ex
            Godot.printerr("[TimerHandle] Unhandled exception in after block: #{ex.message}")
          ensure
            handle.cancel
          end
          break
        end
      end
    end
    handle
  end

  # Zero-argument block overload for `after`
  def self.after(delay : ::Time::Span | Number, node : Godot::Node? = nil, &block : -> Void) : TimerHandle
    after(delay, node: node) { |_handle| block.call }
  end
end

module Godot
  class Node
    # Schedules a recurring timer scoped to this node's lifecycle
    def every(interval : ::Time::Span | Number, &block : TimerHandle -> Void) : TimerHandle
      ::Godot.every(interval, node: self, &block)
    end

    def every(interval : ::Time::Span | Number, &block : -> Void) : TimerHandle
      ::Godot.every(interval, node: self, &block)
    end

    # Schedules a one-shot delay scoped to this node's lifecycle
    def after(delay : ::Time::Span | Number, &block : TimerHandle -> Void) : TimerHandle
      ::Godot.after(delay, node: self, &block)
    end

    def after(delay : ::Time::Span | Number, &block : -> Void) : TimerHandle
      ::Godot.after(delay, node: self, &block)
    end
  end
end

# Top-level gameplay convenience methods
def every(interval : ::Time::Span | Number, node : Godot::Node? = nil, &block : Godot::TimerHandle -> Void) : Godot::TimerHandle
  ::Godot.every(interval, node: node, &block)
end

def every(interval : ::Time::Span | Number, node : Godot::Node? = nil, &block : -> Void) : Godot::TimerHandle
  ::Godot.every(interval, node: node, &block)
end

def after(delay : ::Time::Span | Number, node : Godot::Node? = nil, &block : Godot::TimerHandle -> Void) : Godot::TimerHandle
  ::Godot.after(delay, node: node, &block)
end

def after(delay : ::Time::Span | Number, node : Godot::Node? = nil, &block : -> Void) : Godot::TimerHandle
  ::Godot.after(delay, node: node, &block)
end
