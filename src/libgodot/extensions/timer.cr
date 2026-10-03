# =============================================================================
# LibGodot Ergonomic Timer & Delayed Execution Extensions
# =============================================================================

require "../timer"

module Godot
  # Returns the SceneTree if engine is currently running, or nil in headless/standalone specs
  def self.get_tree? : SceneTree?
    return nil if Bridge.api_null?
    ptr = Bridge.object_call_ret_object(Engine.instance.pointer, "get_main_loop") rescue nil
    return nil if ptr.nil? || ptr.null?
    SceneTree.new(ptr)
  end
end
