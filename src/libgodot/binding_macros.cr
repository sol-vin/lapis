# ===========================================================================
# Method Binding Cache
# ===========================================================================

# Lazily retrieves and caches a GDExtension method bind handle from ClassDB
macro godot_bind(var_name, class_name, method_name, hash)
  if {{var_name.id}}.null?
    {{var_name.id}} = ::Godot::Bridge.get_method_bind({{class_name}}, {{method_name}}, {{hash}}.to_i64)
  end
end

# ===========================================================================
# Argument Marshalling Macros
# ===========================================================================

# Marshals an enum or integer argument into a typed 64-bit pointer for ptrcall
macro godot_marshal_enum(name, idx)
  val_{{idx}} = {{name.id}}.is_a?(Int) ? {{name.id}}.to_i64 : {{name.id}}.value.to_i64
  arg_{{idx}} = pointerof(val_{{idx}}).as(Void*)
end

# Marshals a Godot Object wrapper into an unmanaged pointer-to-pointer for ptrcall
macro godot_marshal_obj(name, idx)
  arg_ptr_{{idx}} = {{name.id}} ? {{name.id}}.pointer : Pointer(Void).null
  arg_{{idx}} = pointerof(arg_ptr_{{idx}}).as(Void*)
end

# Marshals a primitive scalar (Float, Int, Bool, Vector2/3, Color) for ptrcall
macro godot_marshal_val(name, idx)
  val_{{idx}} = {{name.id}}
  arg_{{idx}} = pointerof(val_{{idx}}).as(Void*)
end

# Marshals a String argument into an unmanaged Godot String pointer
macro godot_marshal_str(name, idx)
  str_{{idx}} = ::Godot::Bridge.make_string({{name.id}})
  arg_{{idx}} = str_{{idx}}
end

# Marshals a String or StringName argument into an interned StringName pointer
macro godot_marshal_string_name(name, idx)
  sn_{{idx}} = ::Godot::Bridge.make_string_name({{name.id}})
  arg_{{idx}} = sn_{{idx}}
end

# Marshals a NodePath or String argument into an unmanaged Godot NodePath pointer
macro godot_marshal_nodepath(name, idx)
  np_{{idx}} = ::Godot::Bridge.make_nodepath({{name.id}}.to_s)
  arg_{{idx}} = np_{{idx}}
end

# ===========================================================================
# Ptrcall & Dispatch Macros
# ===========================================================================

# Executes a low-overhead GDExtension ptrcall
macro godot_ptrcall(mb, target_ptr, args_slice, ret_ptr)
  {% if target_ptr.stringify == "Pointer(Void).null" %}
    ::Godot::Bridge.static_ptrcall({{mb}}, {{args_slice}}, {{ret_ptr}})
  {% else %}
    ::Godot::Bridge.ptrcall({{mb}}, {{target_ptr}}, {{args_slice}}, {{ret_ptr}})
  {% end %}
end

# Dynamically calls an instance method and returns the result as a Crystal String
macro godot_call_str(method_name, *args)
  call_str({{method_name}}{% if !args.empty? %}, {{args.splat}}{% end %})
end

# Dynamically calls a static engine method and returns the result as a Crystal String
macro godot_static_call_str(method_name, *args)
  ::Godot::Bridge.object_call_ret_string(Pointer(Void).null, {{method_name}}{% if !args.empty? %}, {{args.splat}}{% end %})
end

# Executes a void ptrcall with no return buffer
macro godot_ptrcall_void(mb, target_ptr, args_slice)
  godot_ptrcall({{mb}}, {{target_ptr}}, {{args_slice}}, Pointer(Void).null)
end

# Executes a ptrcall returning a boolean
macro godot_ptrcall_bool(mb, target_ptr, args_slice)
  ret_bool_val = 0_u8
  godot_ptrcall({{mb}}, {{target_ptr}}, {{args_slice}}, pointerof(ret_bool_val).as(Void*))
  ret_bool_val != 0_u8
end

# Executes a ptrcall returning an integer (Int64)
macro godot_ptrcall_int(mb, target_ptr, args_slice)
  ret_int_val = 0_i64
  godot_ptrcall({{mb}}, {{target_ptr}}, {{args_slice}}, pointerof(ret_int_val).as(Void*))
  ret_int_val
end

# Executes a ptrcall returning a float (Float64 / Float32)
macro godot_ptrcall_float(mb, target_ptr, args_slice)
  ret_float_val = 0.0_f64
  godot_ptrcall({{mb}}, {{target_ptr}}, {{args_slice}}, pointerof(ret_float_val).as(Void*))
  ret_float_val
end

macro godot_ptrcall_float32(mb, target_ptr, args_slice)
  godot_ptrcall_float({{mb}}, {{target_ptr}}, {{args_slice}})
end

macro godot_ptrcall_float64(mb, target_ptr, args_slice)
  godot_ptrcall_float({{mb}}, {{target_ptr}}, {{args_slice}})
end

# Executes a ptrcall returning a value type with default constructor (e.g. Vector2, Vector3, Color, Transform3D)
macro godot_ptrcall_val(mb, target_ptr, args_slice, type_name)
  ret_val = {{type_name.id}}.new
  godot_ptrcall({{mb}}, {{target_ptr}}, {{args_slice}}, pointerof(ret_val).as(Void*))
  ret_val
end

# Executes a ptrcall returning a typed object wrapper
macro godot_ptrcall_obj(mb, target_ptr, args_slice, class_type)
  ret_obj_ptr = Pointer(Void).null
  godot_ptrcall({{mb}}, {{target_ptr}}, {{args_slice}}, pointerof(ret_obj_ptr).as(Void*))
  {{class_type.id}}.new(ret_obj_ptr)
end

# Executes a ptrcall returning a strongly-typed enum
macro godot_ptrcall_enum(mb, target_ptr, args_slice, enum_type)
  ret_enum_val = 0_i64
  godot_ptrcall({{mb}}, {{target_ptr}}, {{args_slice}}, pointerof(ret_enum_val).as(Void*))
  {{enum_type.id}}.new(ret_enum_val)
end

# ===========================================================================
# Return Marshalling Macros
# ===========================================================================

# Instantiates a strongly-typed enum from a 64-bit ptrcall return buffer
macro godot_return_enum(enum_type, ret_var)
  {{enum_type.id}}.new({{ret_var.id}})
end

# Wraps a returned native object pointer into its typed Crystal wrapper
macro godot_return_obj(class_type, ret_ptr)
  {{class_type.id}}.new({{ret_ptr.id}})
end

# ===========================================================================
# Delegation Macros
# ===========================================================================

# Forwards class-level methods to the class singleton instance (e.g. Input, AudioServer)
macro delegate_to_instance(*method_names)
  {% for method in method_names %}
    def self.{{method.id}}(*args, **kwargs)
      instance.{{method.id}}(*args, **kwargs)
    end
  {% end %}
end

# Forwards class-level properties to the class singleton instance
macro delegate_property_to_instance(*prop_names)
  {% for prop in prop_names %}
    def self.{{prop.id}}
      instance.{{prop.id}}
    end

    def self.{{prop.id}}=(val)
      instance.{{prop.id}} = val
    end
  {% end %}
end

# ===========================================================================
# Property Synthesizer Macros
# ===========================================================================

# Synthesizes an ergonomic getter and setter pair
macro godot_prop(prop_name, getter_name, setter_name = nil)
  def {{prop_name.id}}
    {{getter_name.id}}
  end

  {% if setter_name %}
    def {{prop_name.id}}=(val)
      {{setter_name.id}}(val)
    end
  {% end %}
end

# ===========================================================================
# Signal Synthesizer Macros
# ===========================================================================

# Synthesizes a first-class typed signal accessor and direct emission helper
macro godot_signal(name, *types)
  {% if types.empty? %}
    def {{name.id}} : ::Godot::TypedSignal()
      ::Godot::TypedSignal().new(self, {{name.stringify}})
    end

    def emit_{{name.id}} : Void
      emit_signal({{name.stringify}})
    end
  {% else %}
    def {{name.id}} : ::Godot::TypedSignal({{types.splat}})
      ::Godot::TypedSignal({{types.splat}}).new(self, {{name.stringify}})
    end

    def emit_{{name.id}}(*args) : Void
      emit_signal({{name.stringify}}, *args)
    end
  {% end %}
end

# ===========================================================================
# Singleton Macros
# ===========================================================================

# Defines a Godot singleton accessor and pointer caching
macro godot_singleton(cls_name, godot_name, parent_type = Godot::Object)
  class {{cls_name.id}} < {{parent_type.id}}
    @@instance_ptr : Void* = Pointer(Void).null
    @@typed_instance : {{cls_name.id}}? = nil

    def self.singleton_ptr : Void*
      if @@instance_ptr.null?
        @@instance_ptr = ::Godot::Bridge.get_singleton({{godot_name}})
      end
      @@instance_ptr
    end

    def self.instance : {{cls_name.id}}
      @@typed_instance ||= {{cls_name.id}}.new(singleton_ptr)
    end
  end
end

# Emits top-level Godot module singleton helper
macro godot_singleton_accessor(method_name, cls_name)
  def self.{{method_name.id}} : {{cls_name.id}}
    {{cls_name.id}}.instance
  end
end

# ===========================================================================
# Physics Query Macros
# ===========================================================================

# Synthesizes null-safe #get_collider? query on raycasts and shapecasts
macro godot_collider_query(cls_name, indexed = false)
  class {{cls_name.id}}
    {% if indexed %}
      # Convenience query returning the collider as Godot::Object? if alive, or nil if no hit or dead
      def get_collider?(index : Int = 0) : Godot::Object?
        return nil unless is_colliding
        return nil if index < 0 || index.to_i64 >= get_collision_count
        col = get_collider(index.to_i64)
        col.if_alive
      end
    {% else %}
      # Convenience query returning the collider as Godot::Object? if alive, or nil if no hit or dead
      def get_collider? : Godot::Object?
        return nil unless is_colliding
        col = get_collider
        col.if_alive
      end
    {% end %}
  end
end
