# =============================================================================
# LibGodot Core Engine Classes Manifest
# =============================================================================
# Modular architecture organizing all handcrafted Godot engine base classes,
# exceptions, and signal primitives into dedicated files.

require "./types"
require "./macros/annotations"

module Godot
  # Returns true if the code is currently executing inside the Godot Editor
  def self.editor_hint? : Bool
    engine = Bridge.get_singleton("Engine")
    return false if engine.null?
    mb = Bridge.get_method_bind("Engine", "is_editor_hint", 36873697_i64)
    return false if mb.null?
    ret = 0_u8
    Bridge.ptrcall(mb, engine, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
    ret != 0_u8
  end

  # Converts any filesystem or relative path to a normalized Godot res:// path
  def self.to_godot_res_path(path : String) : String
    return "" if path.empty?
    p = path.gsub('\\', '/')
    return p if p.starts_with?("res://")

    if !Godot::ProjectSettings.singleton_ptr.null?
      ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
      localized = ps.call_str("localize_path", p)
      return localized if localized.starts_with?("res://") && localized != "res://" && localized != "res:///"
    end

    if idx = p.index("/src/")
      return "res:/" + p[idx..-1]
    elsif idx = p.index("/addons/")
      return "res:/" + p[idx..-1]
    elsif idx = p.index("/scripts/")
      return "res:/" + p[idx..-1]
    elsif p.starts_with?("src/") || p.starts_with?("addons/") || p.starts_with?("scripts/")
      return "res://#{p}"
    end

    bname = File.basename(p)
    bname.empty? ? "" : "res://#{bname}"
  end

  # Preloads/loads a resource from the given path (convenience alias to Godot.load)
  def self.preload(path : String) : Resource
    self.load(path)
  end

  # Constructs a new native Godot engine object of the given class name (e.g. "Node2D", "MeshInstance3D", "BoxMesh")
  def self.create(class_name : String) : Node?
    ptr = Bridge.construct_object(class_name)
    return nil if ptr.null?
    Node.new(ptr)
  end

  # Constructs a new native Godot engine object and wraps it in the given Crystal class
  def self.create(type : T.class) : T forall T
    class_name = {{ T.name.stringify.split("::").last }}
    ptr = Bridge.construct_object(class_name)
    if inst = Bridge.find_alive_instance(ptr)
      if casted = inst.as?(T)
        if casted.is_a?(RefCounted) && casted.get_reference_count == 0
          casted.init_ref
        end
        return casted
      end
    end
    res = T.new(ptr)
    if res.is_a?(RefCounted) && res.get_reference_count == 0
      res.init_ref
    end
    Bridge.register_alive_instance_by_ptr(ptr, res) if !ptr.null?
    res
  end

  # Constructs a new native Godot engine object, wraps it in T, and configures it in a block
  def self.create(type : T.class, &block : T ->) : T forall T
    inst = create(type)
    with inst yield inst
    inst
  end
end

# 1. Exceptions & Signal Infrastructure
require "./errors"
require "./signals"

# 2. Handcrafted Godot Classes in Inheritance Order
require "./classes/node_path"
require "./classes/object"
require "./classes/ref_counted"
require "./classes/resource"
require "./classes/texture"
require "./classes/audio_stream"
require "./classes/packed_scene"
require "./classes/main_loop"
require "./classes/scene_tree"
require "./classes/node"
require "./classes/canvas_item"
require "./classes/node2d"
require "./classes/node3d"
require "./classes/collision_object2d"
require "./classes/physics_body2d"
require "./classes/character_body2d"
require "./classes/collision_object3d"
require "./classes/physics_body3d"
require "./classes/character_body3d"
require "./classes/camera3d"
require "./classes/ray_cast3d"
require "./classes/collision_shape3d"
require "./classes/control"
require "./classes/range"
require "./classes/progress_bar"
require "./classes/slider"
require "./classes/spin_box"
require "./classes/input"
require "./classes/input_event"

# Global convenience helper to load resources from Godot VFS
def load(path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : Godot::Resource
  Godot.load(path, type_hint, cache_mode)
end

# Global convenience helper to preload resources from Godot VFS
def preload(path : String) : Godot::Resource
  Godot.preload(path)
end

alias Any = Godot::Any
