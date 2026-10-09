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
    @timer : Godot::Timer? = nil
    @scene_tree_timer : Godot::SceneTreeTimer? = nil

    def initialize(@interval_sec : Float64, @node : Godot::Node? = nil, @timer : Godot::Timer? = nil, @scene_tree_timer : Godot::SceneTreeTimer? = nil)
    end

    # Cancels the timer immediately. No further callbacks will fire.
    def cancel : Void
      return if @cancelled
      @running = false
      @cancelled = true
      if t = @timer
        if t.active?
          t.stop rescue nil
          t.queue_free rescue nil
        end
      end
    end

    # Alias for cancel
    def stop : Void
      cancel
    end

    # Temporarily pauses tick accumulation
    def pause : Void
      @paused = true
      if t = @timer
        t.paused = true if t.active? rescue nil
      end
    end

    # Resumes tick accumulation
    def resume : Void
      @paused = false
      if t = @timer
        t.paused = false if t.active? rescue nil
      end
    end

    # Resets elapsed time and tick counter
    def reset : Void
      @elapsed_time = 0.0
      @tick_count = 0_i64
    end

    # Alias for elapsed_time
    def elapsed : Float64
      @elapsed_time
    end

    # Returns true if the timer has finished (either cancelled or stopped)
    def finished? : Bool
      @cancelled || !@running
    end

    # Returns estimated remaining time before next tick
    def time_left : Float64
      if @cancelled || !@running
        0.0
      elsif (t = @timer) && t.active?
        t.get_time_left
      elsif (st = @scene_tree_timer) && st.alive?
        st.get_time_left
      else
        Math.max(0.0, @interval_sec - @elapsed_time)
      end
    end

    # Explicitly registers a tick event and increments tick_count
    def record_tick! : Int64
      @tick_count += 1_i64
    end

    # Advances time by delta, returning true if the timer should tick
    def advance(delta : Float64) : Bool
      return false unless @running && !@paused
      if n = @node
        if !n.active?
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

    if (tree = Godot.get_tree?) && (!node || !node.pointer.null?)
      timer = Godot.create(Timer)
      timer.wait_time = interval_sec
      timer.one_shot = false
      handle = TimerHandle.new(interval_sec, node, timer: timer)
      timer.timeout.connect do
        if handle.cancelled?
          timer.stop rescue nil
          timer.queue_free rescue nil
          next
        end
        if node.is_a?(Godot::Node)
          unless node.active?
            handle.cancel
            next
          end
        end
        next if handle.paused?
        handle.record_tick!
        block.call(handle)
      end
      if node.is_a?(Godot::Node)
        node.add_child(timer)
      elsif scene = tree.current_scene
        scene.add_child(timer)
      else
        tree.get_root.add_child(timer)
      end
      timer.start
      return handle
    end

    handle = TimerHandle.new(interval_sec, node)
    spawn do
      last_tick = ::Time.instant
      while handle.running?
        if node.is_a?(Godot::Node)
          unless node.active?
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
            block.call(handle) unless handle.cancelled?
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

  # Schedules a one-shot delay that fires after `delay`.
  # If `node` is provided, automatically cancels if the node is destroyed before expiry.
  def self.after(delay : ::Time::Span | Number, node : Godot::Node? = nil, &block : TimerHandle -> Void) : TimerHandle
    delay_sec = delay.is_a?(::Time::Span) ? delay.total_seconds : delay.to_f64

    if (tree = Godot.get_tree?) && (!node || !node.pointer.null?)
      st_timer = tree.create_timer(delay_sec)
      handle = TimerHandle.new(delay_sec, node, scene_tree_timer: st_timer)
      st_timer.timeout.connect do
        next if handle.cancelled? || handle.paused?
        if node.is_a?(Godot::Node)
          next unless node.active?
        end
        handle.record_tick!
        handle.cancel
        block.call(handle)
      end
      return handle
    end

    handle = TimerHandle.new(delay_sec, node)
    spawn do
      start_time = ::Time.instant
      while handle.running?
        if node.is_a?(Godot::Node)
          unless node.active?
            handle.cancel
            break
          end
        end
        Fiber.yield
        if !handle.paused? && (::Time.instant - start_time).total_seconds >= delay_sec
          begin
            block.call(handle) unless handle.cancelled?
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
end

module Godot
  class Node
    # Schedules a recurring timer scoped to this node's lifecycle
    def every(interval : ::Time::Span | Number, &block : TimerHandle -> Void) : TimerHandle
      ::Godot.every(interval, node: self, &block)
    end

    # Schedules a one-shot delay scoped to this node's lifecycle
    def after(delay : ::Time::Span | Number, &block : TimerHandle -> Void) : TimerHandle
      ::Godot.after(delay, node: self, &block)
    end
  end
end

# Top-level gameplay convenience methods
def every(interval : ::Time::Span | Number, node : Godot::Node? = nil, &block : Godot::TimerHandle -> Void) : Godot::TimerHandle
  ::Godot.every(interval, node: node, &block)
end

def after(delay : ::Time::Span | Number, node : Godot::Node? = nil, &block : Godot::TimerHandle -> Void) : Godot::TimerHandle
  ::Godot.after(delay, node: node, &block)
end
