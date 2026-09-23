module Godot
  # ===========================================================================
  # SceneTree Ergonomic Extensions
  # ===========================================================================
  class SceneTree
    # Creates a SceneTreeTimer with integer seconds
    def create_timer(time_sec : Int, process_always : Bool = true, process_in_physics : Bool = false, ignore_time_scale : Bool = false) : SceneTreeTimer
      create_timer(time_sec.to_f64, process_always, process_in_physics, ignore_time_scale)
    end

    # Retrieves the first node in a group cast to wrapper type T
    def get_first_node_in_group_as(type : T.class, group_name : String) : T? forall T
      return nil if @pointer.null?
      node = get_first_node_in_group(group_name)
      return nil if node.nil? || node.pointer.null?
      if node.is_a?(T)
        return node
      elsif alive = Bridge.find_alive_instance(node.pointer)
        if typed = alive.as?(T)
          return typed
        end
      end
      if Bridge.object_is_class(node.pointer, T.name.split("::").last)
        return T.new(node.pointer)
      end
      nil
    end

    # Cooperatively awaits the next idle frame without halting the engine loop
    def await_process_frame : Void
      await_signal("process_frame")
    end

    # Cooperatively awaits the next physics frame without halting the engine loop
    def await_physics_frame : Void
      await_signal("physics_frame")
    end
  end

  # ===========================================================================
  # SceneTreeTimer Cooperative Await
  # ===========================================================================
  # Cooperatively awaits a SceneTreeTimer until its countdown expires
  def self.await(timer : SceneTreeTimer) : Void
    while timer.alive? && timer.get_time_left > 0.0
      Fiber.yield
    end
  end
end
