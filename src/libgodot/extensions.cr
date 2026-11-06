# =============================================================================
# LibGodot Class Extensions & Ergonomic Helpers
# =============================================================================
# Modular extensions enriching Godot Engine classes with idiomatic Crystal
# conveniences, strong typing, async fiber awaiting, and query predicates.

require "./extensions/primitives"
require "./extensions/input"
require "./extensions/packed_scene"
require "./extensions/scene_tree"
require "./extensions/node"
require "./extensions/query"
require "./extensions/node_collection"
require "./extensions/spatial"
require "./extensions/physics"
require "./extensions/resource"
require "./extensions/image"
require "./extensions/config_file"
require "./extensions/multiplayer"
require "./extensions/timer"
require "./extensions/tween"
require "./extensions/viewport"
require "./extensions/audio_server"


module Godot
  class Object
    def set_meta(name : String, value : Pointer(Void)) : Void
      check_alive!
      if !@pointer.null? && Bridge.init_done?
        if value.null?
          remove_meta(name)
        else
          call("set_meta", name, value.address.to_i64)
        end
      end
    end

    def get_meta(name : String, default : Pointer(Void)? = nil) : Pointer(Void)
      fallback = default || Pointer(Void).null
      return fallback if @pointer.null? || !Bridge.init_done?
      check_alive!
      return fallback unless has_meta(name)
      addr = call_i64("get_meta", name)
      return Pointer(Void).new(addr.to_u64) if addr != 0_i64
      ptr = Bridge.object_call_ret_object(@pointer, "get_meta", name)
      !ptr.null? ? ptr : fallback
    end
  end
end
