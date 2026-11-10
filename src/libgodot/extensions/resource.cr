module Godot
  # ===========================================================================
  # Resource & Scene Loading Helpers
  # ===========================================================================
  def self.load(path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : Resource
    ptr = Bridge.resource_loader_load(path, type_hint, cache_mode)
    Resource.new(ptr)
  end

  def self.load(path : String, type : T.class, type_hint : String = "", cache_mode : Int64 = 0_i64) : T forall T
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

  # Safe nil-returning resource loader (get_or_null parity)
  def self.load?(path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : Resource?
    ptr = Bridge.resource_loader_load(path, type_hint, cache_mode)
    return nil if ptr.null?
    res = Resource.new(ptr)
    res.pointer.null? ? nil : res
  end

  # Safe nil-returning typed resource loader
  def self.load?(path : String, type : T.class, type_hint : String = "", cache_mode : Int64 = 0_i64) : T? forall T
    res = load?(path, type_hint, cache_mode)
    return nil unless res
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
    nil
  end

  # Named argument variant for `as:` (e.g. `Godot.load("res://...", as: PackedScene)`)
  def self.load(path : String, *, as type : T.class, type_hint : String = "", cache_mode : Int64 = 0_i64) : T forall T
    load(path, type, type_hint: type_hint, cache_mode: cache_mode)
  end

  def self.load_as(type : T.class, path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : T forall T
    load(path, as: type, type_hint: type_hint, cache_mode: cache_mode)
  end

  def self.load_scene(path : String) : PackedScene
    load(path, as: PackedScene)
  end

  def self.load_scene?(path : String) : PackedScene?
    load?(path, PackedScene)
  end

  def self.instantiate_scene(path : String) : Godot::Node
    instantiate_scene(path, Godot::Node)
  end

  def self.instantiate_scene(path : String, type : T.class) : T forall T
    load_scene(path).instantiate_as(type)
  end

  def self.instantiate_scene?(path : String) : Godot::Node?
    instantiate_scene?(path, Godot::Node)
  end

  def self.instantiate_scene?(path : String, type : T.class) : T? forall T
    scene = load_scene?(path)
    return nil unless scene
    scene.instantiate_as?(type)
  end

  # In-memory thread-safe cache for preloaded resources
  module PreloadCache
    @@cache = Hash(String, Resource).new
    @@mutex = ::Thread::Mutex.new

    def self.get_or_load(path : String, type : T.class) : T forall T
      @@mutex.synchronize do
        if res = @@cache[path]?
          if res.active?
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
          end
        end

        loaded = ::Godot.load(path, as: T)
        @@cache[path] = loaded.as(Resource)
        loaded
      end
    end

    def self.get_or_load?(path : String, type : T.class) : T? forall T
      @@mutex.synchronize do
        if res = @@cache[path]?
          if res.active?
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
          end
        end

        if loaded = ::Godot.load?(path, type)
          @@cache[path] = loaded.as(Resource)
          loaded
        else
          nil
        end
      end
    end

    def self.clear : Void
      @@mutex.synchronize { @@cache.clear }
    end

    def self.has?(path : String) : Bool
      @@mutex.synchronize { @@cache.has_key?(path) }
    end

    # Directly inserts or overrides a resource in the preloaded cache
    def self.[]=(path : String, resource : Resource) : Void
      @@mutex.synchronize { @@cache[path] = resource }
    end

    # Directly inserts or overrides a resource in the preloaded cache
    def self.set(path : String, resource : Resource) : Void
      @@mutex.synchronize { @@cache[path] = resource }
    end

    # Returns the count of resources currently cached in memory
    def self.size : Int32
      @@mutex.synchronize { @@cache.size }
    end

    # Removes a cached resource from memory, returning it if present
    def self.delete(path : String) : Resource?
      @@mutex.synchronize { @@cache.delete(path) }
    end
  end

  def self.preload(path : String) : Resource
    preload(path, Resource)
  end

  def self.preload(path : String, type : T.class) : T forall T
    PreloadCache.get_or_load(path, type)
  end

  def self.preload(path : String, as type : T.class) : T forall T
    PreloadCache.get_or_load(path, type)
  end

  def self.preload?(path : String) : Resource?
    preload?(path, Resource)
  end

  def self.preload?(path : String, type : T.class) : T? forall T
    PreloadCache.get_or_load?(path, type)
  end

  def self.preload?(path : String, as type : T.class) : T? forall T
    PreloadCache.get_or_load?(path, type)
  end

  class ResourceSaver
    # Saves a resource to disk using dynamic reflection to ensure valid Ref<Resource> and string marshalling.
    def save(resource : Resource, path : String = "", flags : SaverFlags | Int = 0) : Godot::Error
      flag_val = flags.is_a?(Int) ? flags.to_i64 : flags.value.to_i64
      err_code = call_i64("save", resource, path, flag_val)
      godot_return_enum(Godot::Error, err_code)
    end
  end

  # Exception raised when a Resource fails to save to disk
  class ResourceSaveError < Exception
  end

  class Resource < RefCounted
    # Loads a resource directly from path, typed as the receiving Resource subclass:
    # `scene = PackedScene.load("res://scenes/player.tscn")`
    # `config = CustomConfig.load("res://data/config.tres")`
    def self.load(path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : self
      ::Godot.load(path, as: self, type_hint: type_hint, cache_mode: cache_mode)
    end

    # Saves this resource to disk, raising ResourceSaveError if saving fails
    def save!(path : String = "", flags : ResourceSaver::SaverFlags | Int = 0) : Nil
      return if @pointer.null?
      saver = ::Godot::ResourceSaver.new(::Godot::ResourceSaver.singleton_ptr) rescue nil
      if saver && !saver.pointer.null?
        err = saver.save(self, path, flags)
        if err != Godot::Error::Ok
          raise ResourceSaveError.new("Failed to save resource to '#{path}': Error #{err}")
        end
      end
    end

    # Duplicates this resource with subresources optionally duplicated.
    # Uses Bridge.object_call_ret_object to ensure safe Ref<Resource> lifecycle
    # management across the GDExtension boundary without ABI ptrcall corruption.
    def duplicate(deep : Bool = false) : Resource
      check_alive!
      ptr = Bridge.object_call_ret_object(@pointer, "duplicate", deep)
      return self if ptr.null?
      if inst = Bridge.find_alive_instance(ptr)
        if casted = inst.as?(Resource)
          return casted
        end
      end
      res = Resource.new(ptr)
      Bridge.register_alive_instance_by_ptr(ptr, res)
      res
    end

    # Returns a duplicate of this resource downcast to requested type T
    def duplicate(deep : Bool = false, *, as type : T.class) : T forall T
      check_alive!
      ptr = Bridge.object_call_ret_object(@pointer, "duplicate", deep)
      return self.as(T) if ptr.null?
      T.new(ptr)
    end
  end

  class StandardMaterial3D < BaseMaterial3D
    # Duplicates this material directly returning typed StandardMaterial3D
    def duplicate(deep : Bool = false) : StandardMaterial3D
      if @pointer.null?
        clone = StandardMaterial3D.new
        clone.albedo_color = @local_albedo
        clone.roughness = @local_roughness
        clone.metallic = @local_metallic
        clone.emission_enabled = @local_emission_enabled
        clone.emission = @local_emission
        return clone
      end
      check_alive!
      ptr = Bridge.object_call_ret_object(@pointer, "duplicate", deep)
      return self if ptr.null?
      StandardMaterial3D.new(ptr)
    end

    @local_albedo : Color = Color.new(1.0, 1.0, 1.0, 1.0)
    @local_roughness : Float32 = 1.0_f32
    @local_metallic : Float32 = 0.0_f32
    @local_emission_enabled : Bool = false
    @local_emission : Color = Color.new(0.0, 0.0, 0.0, 1.0)

    def albedo_color : Color
      @pointer.null? ? @local_albedo : get_albedo
    end

    def albedo_color=(c : Color)
      @local_albedo = c
      set_albedo(c) unless @pointer.null?
    end

    def roughness : Float32
      @pointer.null? ? @local_roughness : get_roughness.to_f32
    end

    def roughness=(r : Number)
      @local_roughness = r.to_f32
      set_roughness(r.to_f64) unless @pointer.null?
    end

    def metallic : Float32
      @pointer.null? ? @local_metallic : get_metallic.to_f32
    end

    def metallic=(m : Number)
      @local_metallic = m.to_f32
      set_metallic(m.to_f64) unless @pointer.null?
    end

    def emission_enabled? : Bool
      @pointer.null? ? @local_emission_enabled : get_feature(BaseMaterial3D::Feature::FeatureEmission)
    end

    def emission_enabled=(e : Bool)
      @local_emission_enabled = e
      set_feature(BaseMaterial3D::Feature::FeatureEmission, e) unless @pointer.null?
    end

    def emission : Color
      @pointer.null? ? @local_emission : get_emission
    end

    def emission=(c : Color)
      @local_emission = c
      set_emission(c) unless @pointer.null?
    end
  end

  class Mesh < Resource
    # Returns the material for the given surface index, downcast to target type T.
    def surface_get_material(surf_idx : Int, *, as type : T.class) : T forall T
      surface_get_material(surf_idx.to_i64).as_a(T)
    end

    # Returns the material for the given surface index, downcast to target type T (or nil if invalid/incompatible).
    def surface_get_material?(surf_idx : Int, *, as type : T.class) : T? forall T
      surface_get_material(surf_idx.to_i64).as_a?(T)
    end

    def surface_get_material(surf_idx : Int, type : T.class) : T forall T
      surface_get_material(surf_idx.to_i64).as_a(T)
    end

    def surface_get_material?(surf_idx : Int, type : T.class) : T? forall T
      surface_get_material(surf_idx.to_i64).as_a?(T)
    end
  end

  class PrimitiveMesh < Mesh
    # Returns the material assigned to this primitive mesh.
    def material : Godot::Material?
      get_material
    end

    def material=(val : Godot::Material?) : Void
      set_material(val)
    end

    # Returns the material of this primitive mesh, downcast to target type T.
    def material(*, as type : T.class) : T forall T
      get_material.as_a(T)
    end

    # Returns the material of this primitive mesh, downcast to target type T (or nil if invalid/incompatible).
    def material?(*, as type : T.class) : T? forall T
      get_material.as_a?(T)
    end

    def material(type : T.class) : T forall T
      get_material.as_a(T)
    end

    def material?(type : T.class) : T? forall T
      get_material.as_a?(T)
    end
  end

  module ResourcePath
    # Resolves a Godot virtual path (`res://...` or `uid://...`) to a filesystem path.
    # Works seamlessly both inside the running Godot engine and in standalone headless Crystal specs.
    def self.resolve(path : String) : String
      return path if path.empty?
      resolved = path
      if resolved.starts_with?("uid://") && Bridge.init_done?
        uid_id = ResourceUID.text_to_id(resolved)
        if uid_id != -1_i64 && ResourceUID.has_id(uid_id)
          uid_path = ResourceUID.id_to_path(uid_id)
          resolved = uid_path unless uid_path.empty?
        end
      end
      if resolved.starts_with?("res://")
        if Bridge.init_done?
          glob = ProjectSettings.globalize_path(resolved)
          return glob if !glob.empty? && !glob.starts_with?("res://")
        end
        rel = resolved.lchop("res://")
        return ::File.expand_path(rel, ::Dir.current)
      elsif resolved.starts_with?("user://") && Bridge.init_done?
        glob = ProjectSettings.globalize_path(resolved)
        return glob unless glob.empty?
      end
      resolved
    end
  end

  def self.resolve_path(path : String) : String
    ResourcePath.resolve(path)
  end

  alias ShaderParameterValue = String | Symbol | Int32 | Int64 | UInt32 | UInt64 | Float32 | Float64 | Bool | Vector2 | Vector2i | Vector3 | Vector3i | Vector4 | Vector4i | Color | Rect2 | Rect2i | Transform2D | Transform3D | Basis | Quaternion | Plane | AABB | Object | Variant | PackedByteArray | PackedInt32Array | PackedInt64Array | PackedFloat32Array | PackedFloat64Array | PackedStringArray | PackedVector2Array | PackedVector3Array | PackedColorArray | Nil

  # Internal helper to unpack a 24-byte Godot Variant buffer into target Crystal type T
  protected def self._unpack_variant_buf(ret_var : StaticArray(UInt8, 24), type : T.class, default : T? = nil) : T forall T
    {% if T == Bool %}
      val = 0_u8
      Bridge.type_from_variant(1, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val != 0_u8
    {% elsif T == Int64 %}
      val = default || 0_i64
      Bridge.type_from_variant(2, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Int32 %}
      val = (default || 0_i32).to_i64
      Bridge.type_from_variant(2, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val.to_i32
    {% elsif T == Float64 %}
      val = default || 0.0_f64
      Bridge.type_from_variant(3, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Float32 %}
      val = (default || 0.0_f32).to_f64
      Bridge.type_from_variant(3, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val.to_f32
    {% elsif T == Vector2 %}
      val = default || Vector2.zero
      Bridge.type_from_variant(5, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Vector2i %}
      val = default || Vector2i.new(0, 0)
      Bridge.type_from_variant(6, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Rect2 %}
      val = default || Rect2.new
      Bridge.type_from_variant(7, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Rect2i %}
      val = default || Rect2i.new
      Bridge.type_from_variant(8, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Vector3 %}
      val = default || Vector3.zero
      Bridge.type_from_variant(9, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Vector3i %}
      val = default || Vector3i.new(0, 0, 0)
      Bridge.type_from_variant(10, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Transform2D %}
      val = default || Transform2D.new
      Bridge.type_from_variant(11, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Vector4 %}
      val = default || Vector4.new(0.0_f32, 0.0_f32, 0.0_f32, 0.0_f32)
      Bridge.type_from_variant(12, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Vector4i %}
      val = default || Vector4i.new(0, 0, 0, 0)
      Bridge.type_from_variant(13, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Plane %}
      val = default || Plane.new
      Bridge.type_from_variant(14, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Quaternion %}
      val = default || Quaternion.identity
      Bridge.type_from_variant(15, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == AABB %}
      val = default || AABB.new
      Bridge.type_from_variant(16, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Basis %}
      val = default || Basis.identity
      Bridge.type_from_variant(17, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Transform3D %}
      val = default || Transform3D.identity
      Bridge.type_from_variant(18, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T == Color %}
      val = default || Color::WHITE
      Bridge.type_from_variant(20, pointerof(val).as(Void*), ret_var.to_unsafe.as(Void*))
      val
    {% elsif T <= Godot::Object %}
      ret_ptr = Pointer(Void).null
      Bridge.type_from_variant(24, pointerof(ret_ptr).as(Void*), ret_var.to_unsafe.as(Void*))
      if !ret_ptr.null?
        if alive = Bridge.find_alive_instance(ret_ptr)
          if typed = alive.as?(T)
            return typed
          end
        end
      end
      T.new(ret_ptr)
    {% else %}
      raise ArgumentError.new("Unsupported Variant unpack target type: #{T}")
    {% end %}
  end

  class CanvasItem < Node
    def set_instance_shader_parameter(name : String | Symbol, value : ShaderParameterValue) : Void
      return if @pointer.null? || !Bridge.init_done?
      call("set_instance_shader_parameter", name.to_s, value)
    end

    def get_instance_shader_parameter(name : String | Symbol, as type : T.class, default : T? = nil) : T forall T
      if @pointer.null? || !Bridge.init_done?
        return default || Variant.default_for(T)
      end
      {% if T == String %}
        return call_str("get_instance_shader_parameter", name.to_s)
      {% else %}
        godot_bind(@@mb_get_instance_shader_parameter, "CanvasItem", "get_instance_shader_parameter", 2760726917_i64)
        sn_0 = Bridge.make_string_name(name.to_s)
        args = StaticArray[sn_0]
        ret_var = StaticArray(UInt8, 24).new(0_u8)
        godot_ptrcall(@@mb_get_instance_shader_parameter, @pointer, args.to_unsafe.as(Void**), ret_var.to_unsafe.as(Void*))
        Godot._unpack_variant_buf(ret_var, T, default)
      ensure
        Bridge.free_string_name(sn_0) if sn_0
      {% end %}
    end
  end

  class GeometryInstance3D < VisualInstance3D
    def set_instance_shader_parameter(name : String | Symbol, value : ShaderParameterValue) : Void
      return if @pointer.null? || !Bridge.init_done?
      call("set_instance_shader_parameter", name.to_s, value)
    end

    def get_instance_shader_parameter(name : String | Symbol, as type : T.class, default : T? = nil) : T forall T
      if @pointer.null? || !Bridge.init_done?
        return default || Variant.default_for(T)
      end
      {% if T == String %}
        return call_str("get_instance_shader_parameter", name.to_s)
      {% else %}
        godot_bind(@@mb_get_instance_shader_parameter, "GeometryInstance3D", "get_instance_shader_parameter", 2760726917_i64)
        sn_0 = Bridge.make_string_name(name.to_s)
        args = StaticArray[sn_0]
        ret_var = StaticArray(UInt8, 24).new(0_u8)
        godot_ptrcall(@@mb_get_instance_shader_parameter, @pointer, args.to_unsafe.as(Void**), ret_var.to_unsafe.as(Void*))
        Godot._unpack_variant_buf(ret_var, T, default)
      ensure
        Bridge.free_string_name(sn_0) if sn_0
      {% end %}
    end
  end

  class ArrayMesh < Mesh
    def surface_set_material(surf_idx : Int, material : Material?) : Void
      surface_set_material(surf_idx.to_i64, material)
    end

    def add_surface_from_arrays(primitive : Mesh::PrimitiveType | Int, arrays : Pointer(Void)) : Void
      add_surface_from_arrays(primitive, arrays, Pointer(Void).null, Pointer(Void).null, 0)
    end
  end

  class ConvexPolygonShape3D < Shape3D
    def set_points(points : PackedVector3Array) : Void
      return if @pointer.null? || !Bridge.init_done?
      call("set_points", points)
    end
  end

  class EditorNode3DGizmo < Node3DGizmo
    def add_mesh(mesh : Mesh, material : Material?, transform : Transform3D, skeleton : Nil) : Void
      add_mesh(mesh, material, transform, nil)
    end
  end

  class OptionButton < Button
    def selected : Int64
      get_selected
    end

    def selected=(idx : Int) : Void
      select_val(idx.to_i64)
    end
  end

  class ShaderMaterial < Material
    def set_shader_parameter(param : String | Symbol, value : ShaderParameterValue) : Void
      return if @pointer.null? || !Bridge.init_done?
      call("set_shader_parameter", param.to_s, value)
    end

    def get_shader_parameter(param : String | Symbol, as type : T.class, default : T? = nil) : T forall T
      if @pointer.null? || !Bridge.init_done?
        return default || Variant.default_for(T)
      end
      {% if T == String %}
        return call_str("get_shader_parameter", param.to_s)
      {% else %}
        godot_bind(@@mb_get_shader_parameter, "ShaderMaterial", "get_shader_parameter", 2760726917_i64)
        sn_0 = Bridge.make_string_name(param.to_s)
        args = StaticArray[sn_0]
        ret_var = StaticArray(UInt8, 24).new(0_u8)
        godot_ptrcall(@@mb_get_shader_parameter, @pointer, args.to_unsafe.as(Void**), ret_var.to_unsafe.as(Void*))
        Godot._unpack_variant_buf(ret_var, T, default)
      ensure
        Bridge.free_string_name(sn_0) if sn_0
      {% end %}
    end

    def get_shader_parameter(param : String | Symbol, type : T.class) : T forall T
      get_shader_parameter(param, as: T)
    end

    def get_shader_parameter_bool(param : String | Symbol, default : Bool = false) : Bool
      get_shader_parameter(param, as: Bool, default: default)
    end

    def get_shader_parameter_i64(param : String | Symbol, default : Int64 = 0_i64) : Int64
      get_shader_parameter(param, as: Int64, default: default)
    end

    def get_shader_parameter_i32(param : String | Symbol, default : Int32 = 0_i32) : Int32
      get_shader_parameter(param, as: Int32, default: default)
    end

    def get_shader_parameter_f64(param : String | Symbol, default : Float64 = 0.0_f64) : Float64
      get_shader_parameter(param, as: Float64, default: default)
    end

    def get_shader_parameter_f32(param : String | Symbol, default : Float32 = 0.0_f32) : Float32
      get_shader_parameter(param, as: Float32, default: default)
    end

    def get_shader_parameter_vec2(param : String | Symbol, default : Vector2 = Vector2.zero) : Vector2
      get_shader_parameter(param, as: Vector2, default: default)
    end

    def get_shader_parameter_vec3(param : String | Symbol, default : Vector3 = Vector3.zero) : Vector3
      get_shader_parameter(param, as: Vector3, default: default)
    end

    def get_shader_parameter_vec4(param : String | Symbol, default : Vector4 = Vector4.new(0.0_f32, 0.0_f32, 0.0_f32, 0.0_f32)) : Vector4
      get_shader_parameter(param, as: Vector4, default: default)
    end

    def get_shader_parameter_color(param : String | Symbol, default : Color = Color::WHITE) : Color
      get_shader_parameter(param, as: Color, default: default)
    end

    def get_shader_parameter_transform3d(param : String | Symbol, default : Transform3D = Transform3D.identity) : Transform3D
      get_shader_parameter(param, as: Transform3D, default: default)
    end

    def get_shader_parameter_obj(param : String | Symbol, type : T.class = Godot::Object) : T? forall T
      obj = get_shader_parameter(param, as: T)
      obj.pointer.null? ? nil : obj
    end
  end

  class RenderingServer < Object
    def global_shader_parameter_set(name : String | Symbol, value : ShaderParameterValue) : Void
      return if @pointer.null? || !Bridge.init_done?
      call("global_shader_parameter_set", name.to_s, value)
    end

    def self.global_shader_parameter_set(name : String | Symbol, value : ShaderParameterValue) : Void
      instance.global_shader_parameter_set(name, value)
    end

    def global_shader_parameter_set_override(name : String | Symbol, value : ShaderParameterValue) : Void
      return if @pointer.null? || !Bridge.init_done?
      call("global_shader_parameter_set_override", name.to_s, value)
    end

    def self.global_shader_parameter_set_override(name : String | Symbol, value : ShaderParameterValue) : Void
      instance.global_shader_parameter_set_override(name, value)
    end

    def global_shader_parameter_get(name : String | Symbol, as type : T.class, default : T? = nil) : T forall T
      if @pointer.null? || !Bridge.init_done?
        return default || Variant.default_for(T)
      end
      {% if T == String %}
        return call_str("global_shader_parameter_get", name.to_s)
      {% else %}
        godot_bind(@@mb_global_shader_parameter_get, "RenderingServer", "global_shader_parameter_get", 2760726917_i64)
        sn_0 = Bridge.make_string_name(name.to_s)
        args = StaticArray[sn_0]
        ret_var = StaticArray(UInt8, 24).new(0_u8)
        godot_ptrcall(@@mb_global_shader_parameter_get, @pointer, args.to_unsafe.as(Void**), ret_var.to_unsafe.as(Void*))
        Godot._unpack_variant_buf(ret_var, T, default)
      ensure
        Bridge.free_string_name(sn_0) if sn_0
      {% end %}
    end

    def self.global_shader_parameter_get(name : String | Symbol, as type : T.class, default : T? = nil) : T forall T
      instance.global_shader_parameter_get(name, as: type, default: default)
    end
  end
end


# Loads a resource dynamically from the Godot virtual filesystem with compile-time type inference.
#
# Supported extensions:
# - `.tscn`, `.scn` -> `Godot::PackedScene`
# - `.png`, `.svg`, `.webp` -> `Godot::Texture2D`
# - `.wav`, `.ogg`, `.mp3` -> `Godot::AudioStream`
# - Other / `.tres` -> `Godot::Resource`
#
# For custom types, chain `.as(Type)`:
# ```crystal
# config = load("res://data.tres").as(CustomConfig)
# ```
macro load(path)
  {%
    p_str = path.id.stringify
    if p_str.ends_with?(".tscn") || p_str.ends_with?(".scn")
      target_type = "::Godot::PackedScene"
    elsif p_str.ends_with?(".png") || p_str.ends_with?(".svg") || p_str.ends_with?(".webp")
      target_type = "::Godot::Texture2D"
    elsif p_str.ends_with?(".wav") || p_str.ends_with?(".ogg") || p_str.ends_with?(".mp3")
      target_type = "::Godot::AudioStream"
    else
      target_type = "::Godot::Resource"
    end
  %}
  ::Godot.load_as({{target_type.id}}, {{path}})
end

# Safe, nil-returning variant of `load(path)`.
#
# Returns `nil` if the resource fails to load or does not exist on disk.
#
# ### Example:
# ```crystal
# if scene = load?("res://dlc/bonus_level.tscn")
#   # ...
# end
# ```
macro load?(path)
  {%
    p_str = path.id.stringify
    if p_str.ends_with?(".tscn") || p_str.ends_with?(".scn")
      target_type = "::Godot::PackedScene"
    elsif p_str.ends_with?(".png") || p_str.ends_with?(".svg") || p_str.ends_with?(".webp")
      target_type = "::Godot::Texture2D"
    elsif p_str.ends_with?(".wav") || p_str.ends_with?(".ogg") || p_str.ends_with?(".mp3")
      target_type = "::Godot::AudioStream"
    else
      target_type = "::Godot::Resource"
    end
  %}
  ::Godot.load?({{path}}, {{target_type.id}})
end

# Preloads and caches a resource from the Godot virtual filesystem with compile-time type inference.
#
# Supported extensions:
# - `.tscn`, `.scn` -> `Godot::PackedScene`
# - `.png`, `.svg`, `.webp` -> `Godot::Texture2D`
# - `.wav`, `.ogg`, `.mp3` -> `Godot::AudioStream`
# - Other / `.tres` -> `Godot::Resource`
#
# For custom types, chain `.as(Type)`:
# ```crystal
# const CONFIG = preload("res://data.tres").as(CustomConfig)
# ```
macro preload(path)
  {%
    p_str = path.id.stringify
    if p_str.ends_with?(".tscn") || p_str.ends_with?(".scn")
      target_type = "::Godot::PackedScene"
    elsif p_str.ends_with?(".png") || p_str.ends_with?(".svg") || p_str.ends_with?(".webp")
      target_type = "::Godot::Texture2D"
    elsif p_str.ends_with?(".wav") || p_str.ends_with?(".ogg") || p_str.ends_with?(".mp3")
      target_type = "::Godot::AudioStream"
    else
      target_type = "::Godot::Resource"
    end
  %}
  ::Godot::PreloadCache.get_or_load({{path}}, {{target_type.id}})
end

# Safe, nil-returning variant of `preload(path)`.
#
# Returns `nil` if the resource fails to load or does not exist on disk.
#
# ### Example:
# ```crystal
# if icon = preload?("res://custom_icon.png")
#   # ...
# end
# ```
macro preload?(path)
  {%
    p_str = path.id.stringify
    if p_str.ends_with?(".tscn") || p_str.ends_with?(".scn")
      target_type = "::Godot::PackedScene"
    elsif p_str.ends_with?(".png") || p_str.ends_with?(".svg") || p_str.ends_with?(".webp")
      target_type = "::Godot::Texture2D"
    elsif p_str.ends_with?(".wav") || p_str.ends_with?(".ogg") || p_str.ends_with?(".mp3")
      target_type = "::Godot::AudioStream"
    else
      target_type = "::Godot::Resource"
    end
  %}
  ::Godot::PreloadCache.get_or_load?({{path}}, {{target_type.id}})
end

struct ::Path
  # Resolves a Godot virtual path (`res://...` or `uid://...`) to a filesystem path.
  def self.resolve(path : String) : String
    ::Godot::ResourcePath.resolve(path)
  end
end
