# =============================================================================
# LibGodot Ergonomic Timer & Delayed Execution Extensions
# =============================================================================

module Godot
  # Schedules a block to execute after the specified duration (in seconds or Time::Span).
  # Uses Godot SceneTreeTimer non-blockingly without thread stalls.
  def self.after(delay : Float64 | Int32 | Time::Span, &block : -> Void) : SceneTreeTimer?
    sec = delay.is_a?(Time::Span) ? delay.total_seconds : delay.to_f64
    if tree = Godot.get_tree?
      timer = tree.create_timer(sec)
      timer.timeout.connect(block)
      timer
    else
      # Standalone fallback: invoke asynchronously via spawn if engine tree unavailable
      spawn do
        Crystal::System::Thread.sleep(sec.seconds)
        block.call
      end
      nil
    end
  end

  # Schedules a recurring timer that fires repeatedly until stopped.
  def self.every(interval : Float64 | Int32 | Time::Span, &block : -> Void) : Timer?
    sec = interval.is_a?(Time::Span) ? interval.total_seconds : interval.to_f64
    if tree = Godot.get_tree?
      timer = Godot.create(Timer)
      timer.wait_time = sec
      timer.one_shot = false
      timer.autostart = true
      timer.timeout.connect(block)
      if scene = tree.current_scene
        scene.add_child(timer)
      else
        tree.root.add_child(timer)
      end
      timer.start
      timer
    else
      nil
    end
  end

  # Returns the SceneTree if engine is currently running, or nil in headless/standalone specs
  def self.get_tree? : SceneTree?
    return nil if Bridge.api_null?
    ptr = Bridge.object_call_ret_object(Engine.instance.pointer, "get_main_loop") rescue nil
    return nil if ptr.nil? || ptr.null?
    SceneTree.new(ptr)
  end
end

class Godot::Node
  # Delays execution of a block on this node using SceneTreeTimer
  def after(delay : Float64 | Int32 | Time::Span, &block : -> Void) : Godot::SceneTreeTimer?
    sec = delay.is_a?(Time::Span) ? delay.total_seconds : delay.to_f64
    if @pointer.null?
      spawn do
        Crystal::System::Thread.sleep(sec.seconds)
        block.call
      end
      return nil
    end
    timer = get_tree.create_timer(sec)
    timer.timeout.connect(block)
    timer
  end

  # Runs a block repeatedly on this node
  def every(interval : Float64 | Int32 | Time::Span, &block : -> Void) : Godot::Timer?
    sec = interval.is_a?(Time::Span) ? interval.total_seconds : interval.to_f64
    return nil if @pointer.null?
    timer = ::Godot.create(Godot::Timer)
    timer.wait_time = sec
    timer.one_shot = false
    timer.timeout.connect(block)
    add_child(timer)
    timer.start
    timer
  end
end
