module Godot
  # ===========================================================================
  # Resource & Scene Loading Helpers
  # ===========================================================================
  def self.load(path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : Resource
    ptr = Bridge.resource_loader_load(path, type_hint, cache_mode)
    Resource.new(ptr)
  end

  def self.load(path : String, as type : T.class, type_hint : String = "", cache_mode : Int64 = 0_i64) : T forall T
    res = load(path, type_hint, cache_mode)
    if res.pointer.null?
      raise NilAssertionError.new("Failed to load resource at '#{path}' as #{T}")
    end
    if res.is_a?(T)
      return res
    elsif alive = Bridge.find_alive_instance(res.pointer)
      if typed = alive.as?(T)
        return typed
      end
    end
    if !res.pointer.null? && Bridge.object_is_class(res.pointer, T.name.split("::").last)
      return T.new(res.pointer)
    end
    T.new(res.pointer)
  end

  def self.load_as(type : T.class, path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : T forall T
    load(path, as: type, type_hint: type_hint, cache_mode: cache_mode)
  end

  def self.load_scene(path : String) : PackedScene
    load(path, as: PackedScene)
  end

  def self.instantiate_scene(path : String, type : T.class) : T forall T
    load_scene(path).instantiate_as(type)
  end

  class ResourceSaver
    # Saves a resource to disk using dynamic reflection to ensure valid Ref<Resource> and string marshalling.
    def save(resource : Resource, path : String = "", flags : SaverFlags | Int = 0) : Godot::Error
      flag_val = flags.is_a?(Int) ? flags.to_i64 : flags.value.to_i64
      err_code = call_i64("save", resource, path, flag_val)
      godot_return_enum(Godot::Error, err_code)
    end
  end
end
