# Generated classes part 6 (in topological order)
module Godot
  class UndoRedo < Godot::Object
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum MergeMode : Int64
      MergeDisable = 0_i64
      MergeEnds = 1_i64
      MergeAll = 2_i64
    end
    @@mb_create_action : Void* = Pointer(Void).null
    def create_action(name : String, merge_mode : MergeMode | Int = 0, backward_undo_ops : Bool = false) : Void
      godot_bind(@@mb_create_action, "UndoRedo", "create_action", 3171901514_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      val_1 = merge_mode.is_a?(Int) ? merge_mode.to_i64 : merge_mode.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = backward_undo_ops
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_create_action, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_commit_action : Void* = Pointer(Void).null
    def commit_action(execute : Bool = true) : Void
      godot_bind(@@mb_commit_action, "UndoRedo", "commit_action", 3216645846_i64)
      val_0 = execute
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_commit_action, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_committing_action : Void* = Pointer(Void).null
    def is_committing_action() : Bool
      godot_bind(@@mb_is_committing_action, "UndoRedo", "is_committing_action", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_committing_action, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_add_do_method : Void* = Pointer(Void).null
    def add_do_method(callable : Pointer(Void)) : Void
      godot_bind(@@mb_add_do_method, "UndoRedo", "add_do_method", 1611583062_i64)
      val_0 = callable
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_add_do_method, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_add_undo_method : Void* = Pointer(Void).null
    def add_undo_method(callable : Pointer(Void)) : Void
      godot_bind(@@mb_add_undo_method, "UndoRedo", "add_undo_method", 1611583062_i64)
      val_0 = callable
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_add_undo_method, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_add_do_property : Void* = Pointer(Void).null
    def add_do_property(object : Godot::Object, property : String, value : Pointer(Void)) : Void
      godot_bind(@@mb_add_do_property, "UndoRedo", "add_do_property", 1017172818_i64)
      arg_ptr_0 = object ? object.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      sn_1 = Bridge.make_string_name(property)
      arg_1 = sn_1
      val_2 = value
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_add_do_property, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_1)
    end
    @@mb_add_undo_property : Void* = Pointer(Void).null
    def add_undo_property(object : Godot::Object, property : String, value : Pointer(Void)) : Void
      godot_bind(@@mb_add_undo_property, "UndoRedo", "add_undo_property", 1017172818_i64)
      arg_ptr_0 = object ? object.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      sn_1 = Bridge.make_string_name(property)
      arg_1 = sn_1
      val_2 = value
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_add_undo_property, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_1)
    end
    @@mb_add_do_reference : Void* = Pointer(Void).null
    def add_do_reference(object : Godot::Object) : Void
      godot_bind(@@mb_add_do_reference, "UndoRedo", "add_do_reference", 3975164845_i64)
      arg_ptr_0 = object ? object.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_add_do_reference, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_add_undo_reference : Void* = Pointer(Void).null
    def add_undo_reference(object : Godot::Object) : Void
      godot_bind(@@mb_add_undo_reference, "UndoRedo", "add_undo_reference", 3975164845_i64)
      arg_ptr_0 = object ? object.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_add_undo_reference, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_start_force_keep_in_merge_ends : Void* = Pointer(Void).null
    def start_force_keep_in_merge_ends() : Void
      godot_bind(@@mb_start_force_keep_in_merge_ends, "UndoRedo", "start_force_keep_in_merge_ends", 3218959716_i64)
      godot_ptrcall(@@mb_start_force_keep_in_merge_ends, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_end_force_keep_in_merge_ends : Void* = Pointer(Void).null
    def end_force_keep_in_merge_ends() : Void
      godot_bind(@@mb_end_force_keep_in_merge_ends, "UndoRedo", "end_force_keep_in_merge_ends", 3218959716_i64)
      godot_ptrcall(@@mb_end_force_keep_in_merge_ends, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_get_history_count : Void* = Pointer(Void).null
    def get_history_count() : Int64
      godot_bind(@@mb_get_history_count, "UndoRedo", "get_history_count", 2455072627_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_history_count, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_current_action : Void* = Pointer(Void).null
    def get_current_action() : Int64
      godot_bind(@@mb_get_current_action, "UndoRedo", "get_current_action", 2455072627_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_current_action, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_action_name : Void* = Pointer(Void).null
    def get_action_name(id : Int64) : String
      godot_bind(@@mb_get_action_name, "UndoRedo", "get_action_name", 990163283_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_call_str("get_action_name", id)
    end
    @@mb_clear_history : Void* = Pointer(Void).null
    def clear_history(increase_version : Bool = true) : Void
      godot_bind(@@mb_clear_history, "UndoRedo", "clear_history", 3216645846_i64)
      val_0 = increase_version
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_clear_history, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_current_action_name : Void* = Pointer(Void).null
    def get_current_action_name() : String
      godot_bind(@@mb_get_current_action_name, "UndoRedo", "get_current_action_name", 201670096_i64)
      godot_call_str("get_current_action_name")
    end
    @@mb_has_undo : Void* = Pointer(Void).null
    def has_undo() : Bool
      godot_bind(@@mb_has_undo, "UndoRedo", "has_undo", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_has_undo, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_has_redo : Void* = Pointer(Void).null
    def has_redo() : Bool
      godot_bind(@@mb_has_redo, "UndoRedo", "has_redo", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_has_redo, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_version : Void* = Pointer(Void).null
    def get_version() : Int64
      godot_bind(@@mb_get_version, "UndoRedo", "get_version", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_version, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_max_steps : Void* = Pointer(Void).null
    def set_max_steps(max_steps : Int64) : Void
      godot_bind(@@mb_set_max_steps, "UndoRedo", "set_max_steps", 1286410249_i64)
      val_0 = max_steps
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_max_steps, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_max_steps : Void* = Pointer(Void).null
    def get_max_steps() : Int64
      godot_bind(@@mb_get_max_steps, "UndoRedo", "get_max_steps", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_max_steps, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_redo : Void* = Pointer(Void).null
    def redo_val() : Bool
      godot_bind(@@mb_redo, "UndoRedo", "redo", 2240911060_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_redo, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_undo : Void* = Pointer(Void).null
    def undo() : Bool
      godot_bind(@@mb_undo, "UndoRedo", "undo", 2240911060_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_undo, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `max_steps` getter
    def max_steps
      get_max_steps
    end
    # Property `max_steps` setter
    def max_steps=(val : Int)
      set_max_steps(val.to_i64)
    end
    godot_signal version_changed
  end
  class UniformSetCacheRD < Godot::Object
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_get_cache : Void* = Pointer(Void).null
    def self.get_cache(shader : Int64, set : Int64, uniforms : Pointer(Void)) : Int64
      godot_bind(@@mb_get_cache, "UniformSetCacheRD", "get_cache", 658571723_i64)
      val_0 = shader
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = set
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = uniforms
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      ret = 0_i64
      godot_ptrcall(@@mb_get_cache, Pointer(Void).null, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    # Instance convenience delegator for static method `get_cache`
    def get_cache(shader : Int64, set : Int64, uniforms : Pointer(Void)) : Int64
      self.class.get_cache(shader, set, uniforms)
    end
  end
  class VFlowContainer < Godot::FlowContainer
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VScrollBar < Godot::ScrollBar
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VSeparator < Godot::Separator
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VSlider < Godot::Slider
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VSplitContainer < Godot::SplitContainer
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VehicleBody3D < Godot::RigidBody3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_engine_force : Void* = Pointer(Void).null
    def set_engine_force(engine_force : Float64) : Void
      godot_bind(@@mb_set_engine_force, "VehicleBody3D", "set_engine_force", 373806689_i64)
      val_0 = engine_force
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_engine_force, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_engine_force : Void* = Pointer(Void).null
    def get_engine_force() : Float64
      godot_bind(@@mb_get_engine_force, "VehicleBody3D", "get_engine_force", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_engine_force, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_brake : Void* = Pointer(Void).null
    def set_brake(brake : Float64) : Void
      godot_bind(@@mb_set_brake, "VehicleBody3D", "set_brake", 373806689_i64)
      val_0 = brake
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_brake, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_brake : Void* = Pointer(Void).null
    def get_brake() : Float64
      godot_bind(@@mb_get_brake, "VehicleBody3D", "get_brake", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_brake, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_steering : Void* = Pointer(Void).null
    def set_steering(steering : Float64) : Void
      godot_bind(@@mb_set_steering, "VehicleBody3D", "set_steering", 373806689_i64)
      val_0 = steering
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_steering, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_steering : Void* = Pointer(Void).null
    def get_steering() : Float64
      godot_bind(@@mb_get_steering, "VehicleBody3D", "get_steering", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_steering, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `engine_force` getter
    def engine_force
      get_engine_force
    end
    # Property `engine_force` setter
    def engine_force=(val : Number)
      set_engine_force(val.to_f64)
    end
    # Property `brake` getter
    def brake
      get_brake
    end
    # Property `brake` setter
    def brake=(val : Number)
      set_brake(val.to_f64)
    end
    # Property `steering` getter
    def steering
      get_steering
    end
    # Property `steering` setter
    def steering=(val : Number)
      set_steering(val.to_f64)
    end
  end
  class VehicleWheel3D < Godot::Node3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_radius : Void* = Pointer(Void).null
    def set_radius(length : Float64) : Void
      godot_bind(@@mb_set_radius, "VehicleWheel3D", "set_radius", 373806689_i64)
      val_0 = length
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_radius, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_radius : Void* = Pointer(Void).null
    def get_radius() : Float64
      godot_bind(@@mb_get_radius, "VehicleWheel3D", "get_radius", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_radius, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_suspension_rest_length : Void* = Pointer(Void).null
    def set_suspension_rest_length(length : Float64) : Void
      godot_bind(@@mb_set_suspension_rest_length, "VehicleWheel3D", "set_suspension_rest_length", 373806689_i64)
      val_0 = length
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_suspension_rest_length, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_suspension_rest_length : Void* = Pointer(Void).null
    def get_suspension_rest_length() : Float64
      godot_bind(@@mb_get_suspension_rest_length, "VehicleWheel3D", "get_suspension_rest_length", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_suspension_rest_length, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_suspension_travel : Void* = Pointer(Void).null
    def set_suspension_travel(length : Float64) : Void
      godot_bind(@@mb_set_suspension_travel, "VehicleWheel3D", "set_suspension_travel", 373806689_i64)
      val_0 = length
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_suspension_travel, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_suspension_travel : Void* = Pointer(Void).null
    def get_suspension_travel() : Float64
      godot_bind(@@mb_get_suspension_travel, "VehicleWheel3D", "get_suspension_travel", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_suspension_travel, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_suspension_stiffness : Void* = Pointer(Void).null
    def set_suspension_stiffness(length : Float64) : Void
      godot_bind(@@mb_set_suspension_stiffness, "VehicleWheel3D", "set_suspension_stiffness", 373806689_i64)
      val_0 = length
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_suspension_stiffness, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_suspension_stiffness : Void* = Pointer(Void).null
    def get_suspension_stiffness() : Float64
      godot_bind(@@mb_get_suspension_stiffness, "VehicleWheel3D", "get_suspension_stiffness", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_suspension_stiffness, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_suspension_max_force : Void* = Pointer(Void).null
    def set_suspension_max_force(length : Float64) : Void
      godot_bind(@@mb_set_suspension_max_force, "VehicleWheel3D", "set_suspension_max_force", 373806689_i64)
      val_0 = length
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_suspension_max_force, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_suspension_max_force : Void* = Pointer(Void).null
    def get_suspension_max_force() : Float64
      godot_bind(@@mb_get_suspension_max_force, "VehicleWheel3D", "get_suspension_max_force", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_suspension_max_force, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_damping_compression : Void* = Pointer(Void).null
    def set_damping_compression(length : Float64) : Void
      godot_bind(@@mb_set_damping_compression, "VehicleWheel3D", "set_damping_compression", 373806689_i64)
      val_0 = length
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_damping_compression, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_damping_compression : Void* = Pointer(Void).null
    def get_damping_compression() : Float64
      godot_bind(@@mb_get_damping_compression, "VehicleWheel3D", "get_damping_compression", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_damping_compression, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_damping_relaxation : Void* = Pointer(Void).null
    def set_damping_relaxation(length : Float64) : Void
      godot_bind(@@mb_set_damping_relaxation, "VehicleWheel3D", "set_damping_relaxation", 373806689_i64)
      val_0 = length
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_damping_relaxation, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_damping_relaxation : Void* = Pointer(Void).null
    def get_damping_relaxation() : Float64
      godot_bind(@@mb_get_damping_relaxation, "VehicleWheel3D", "get_damping_relaxation", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_damping_relaxation, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_use_as_traction : Void* = Pointer(Void).null
    def set_use_as_traction(enable : Bool) : Void
      godot_bind(@@mb_set_use_as_traction, "VehicleWheel3D", "set_use_as_traction", 2586408642_i64)
      val_0 = enable
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_use_as_traction, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_used_as_traction : Void* = Pointer(Void).null
    def is_used_as_traction() : Bool
      godot_bind(@@mb_is_used_as_traction, "VehicleWheel3D", "is_used_as_traction", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_used_as_traction, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_use_as_steering : Void* = Pointer(Void).null
    def set_use_as_steering(enable : Bool) : Void
      godot_bind(@@mb_set_use_as_steering, "VehicleWheel3D", "set_use_as_steering", 2586408642_i64)
      val_0 = enable
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_use_as_steering, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_used_as_steering : Void* = Pointer(Void).null
    def is_used_as_steering() : Bool
      godot_bind(@@mb_is_used_as_steering, "VehicleWheel3D", "is_used_as_steering", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_used_as_steering, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_friction_slip : Void* = Pointer(Void).null
    def set_friction_slip(length : Float64) : Void
      godot_bind(@@mb_set_friction_slip, "VehicleWheel3D", "set_friction_slip", 373806689_i64)
      val_0 = length
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_friction_slip, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_friction_slip : Void* = Pointer(Void).null
    def get_friction_slip() : Float64
      godot_bind(@@mb_get_friction_slip, "VehicleWheel3D", "get_friction_slip", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_friction_slip, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_is_in_contact : Void* = Pointer(Void).null
    def is_in_contact() : Bool
      godot_bind(@@mb_is_in_contact, "VehicleWheel3D", "is_in_contact", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_in_contact, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_contact_body : Void* = Pointer(Void).null
    def get_contact_body() : Node3D
      godot_bind(@@mb_get_contact_body, "VehicleWheel3D", "get_contact_body", 151077316_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_contact_body, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Node3D, ret_ptr)
    end
    @@mb_get_contact_point : Void* = Pointer(Void).null
    def get_contact_point() : Vector3
      godot_bind(@@mb_get_contact_point, "VehicleWheel3D", "get_contact_point", 3360562783_i64)
      ret = Vector3.new
      godot_ptrcall(@@mb_get_contact_point, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_contact_normal : Void* = Pointer(Void).null
    def get_contact_normal() : Vector3
      godot_bind(@@mb_get_contact_normal, "VehicleWheel3D", "get_contact_normal", 3360562783_i64)
      ret = Vector3.new
      godot_ptrcall(@@mb_get_contact_normal, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_roll_influence : Void* = Pointer(Void).null
    def set_roll_influence(roll_influence : Float64) : Void
      godot_bind(@@mb_set_roll_influence, "VehicleWheel3D", "set_roll_influence", 373806689_i64)
      val_0 = roll_influence
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_roll_influence, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_roll_influence : Void* = Pointer(Void).null
    def get_roll_influence() : Float64
      godot_bind(@@mb_get_roll_influence, "VehicleWheel3D", "get_roll_influence", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_roll_influence, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_skidinfo : Void* = Pointer(Void).null
    def get_skidinfo() : Float64
      godot_bind(@@mb_get_skidinfo, "VehicleWheel3D", "get_skidinfo", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_skidinfo, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_rpm : Void* = Pointer(Void).null
    def get_rpm() : Float64
      godot_bind(@@mb_get_rpm, "VehicleWheel3D", "get_rpm", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_rpm, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_engine_force : Void* = Pointer(Void).null
    def set_engine_force(engine_force : Float64) : Void
      godot_bind(@@mb_set_engine_force, "VehicleWheel3D", "set_engine_force", 373806689_i64)
      val_0 = engine_force
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_engine_force, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_engine_force : Void* = Pointer(Void).null
    def get_engine_force() : Float64
      godot_bind(@@mb_get_engine_force, "VehicleWheel3D", "get_engine_force", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_engine_force, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_brake : Void* = Pointer(Void).null
    def set_brake(brake : Float64) : Void
      godot_bind(@@mb_set_brake, "VehicleWheel3D", "set_brake", 373806689_i64)
      val_0 = brake
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_brake, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_brake : Void* = Pointer(Void).null
    def get_brake() : Float64
      godot_bind(@@mb_get_brake, "VehicleWheel3D", "get_brake", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_brake, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_steering : Void* = Pointer(Void).null
    def set_steering(steering : Float64) : Void
      godot_bind(@@mb_set_steering, "VehicleWheel3D", "set_steering", 373806689_i64)
      val_0 = steering
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_steering, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_steering : Void* = Pointer(Void).null
    def get_steering() : Float64
      godot_bind(@@mb_get_steering, "VehicleWheel3D", "get_steering", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_steering, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `engine_force` getter
    def engine_force
      get_engine_force
    end
    # Property `engine_force` setter
    def engine_force=(val : Number)
      set_engine_force(val.to_f64)
    end
    # Property `brake` getter
    def brake
      get_brake
    end
    # Property `brake` setter
    def brake=(val : Number)
      set_brake(val.to_f64)
    end
    # Property `steering` getter
    def steering
      get_steering
    end
    # Property `steering` setter
    def steering=(val : Number)
      set_steering(val.to_f64)
    end
    # Property `use_as_traction` getter
    def use_as_traction
      is_used_as_traction
    end
    def use_as_traction?
      use_as_traction
    end
    # Property `use_as_traction` setter
    def use_as_traction=(val)
      set_use_as_traction(val)
    end
    # Property `use_as_steering` getter
    def use_as_steering
      is_used_as_steering
    end
    def use_as_steering?
      use_as_steering
    end
    # Property `use_as_steering` setter
    def use_as_steering=(val)
      set_use_as_steering(val)
    end
    # Property `wheel_roll_influence` getter
    def wheel_roll_influence
      get_roll_influence
    end
    # Property `wheel_roll_influence` setter
    def wheel_roll_influence=(val : Number)
      set_roll_influence(val.to_f64)
    end
    # Property `wheel_radius` getter
    def wheel_radius
      get_radius
    end
    # Property `wheel_radius` setter
    def wheel_radius=(val : Number)
      set_radius(val.to_f64)
    end
    # Property `wheel_rest_length` getter
    def wheel_rest_length
      get_suspension_rest_length
    end
    # Property `wheel_rest_length` setter
    def wheel_rest_length=(val : Number)
      set_suspension_rest_length(val.to_f64)
    end
    # Property `wheel_friction_slip` getter
    def wheel_friction_slip
      get_friction_slip
    end
    # Property `wheel_friction_slip` setter
    def wheel_friction_slip=(val : Number)
      set_friction_slip(val.to_f64)
    end
    # Property `suspension_travel` getter
    def suspension_travel
      get_suspension_travel
    end
    # Property `suspension_travel` setter
    def suspension_travel=(val : Number)
      set_suspension_travel(val.to_f64)
    end
    # Property `suspension_stiffness` getter
    def suspension_stiffness
      get_suspension_stiffness
    end
    # Property `suspension_stiffness` setter
    def suspension_stiffness=(val : Number)
      set_suspension_stiffness(val.to_f64)
    end
    # Property `suspension_max_force` getter
    def suspension_max_force
      get_suspension_max_force
    end
    # Property `suspension_max_force` setter
    def suspension_max_force=(val : Number)
      set_suspension_max_force(val.to_f64)
    end
    # Property `damping_compression` getter
    def damping_compression
      get_damping_compression
    end
    # Property `damping_compression` setter
    def damping_compression=(val : Number)
      set_damping_compression(val.to_f64)
    end
    # Property `damping_relaxation` getter
    def damping_relaxation
      get_damping_relaxation
    end
    # Property `damping_relaxation` setter
    def damping_relaxation=(val : Number)
      set_damping_relaxation(val.to_f64)
    end
  end
  class VideoStream < Godot::Resource
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_file : Void* = Pointer(Void).null
    def set_file(file : String) : Void
      godot_bind(@@mb_set_file, "VideoStream", "set_file", 83702148_i64)
      str_0 = Bridge.make_string(file)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_file, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_file : Void* = Pointer(Void).null
    def get_file() : String
      godot_bind(@@mb_get_file, "VideoStream", "get_file", 2841200299_i64)
      godot_call_str("get_file")
    end
    # Property `file` getter
    def file
      get_file
    end
    # Property `file` setter
    def file=(val)
      set_file(val)
    end
  end
  class VideoStreamPlayback < Godot::Resource
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_mix_audio : Void* = Pointer(Void).null
    def mix_audio(num_frames : Int64, buffer : Pointer(Void), offset : Int64 = 0_i64) : Int64
      godot_bind(@@mb_mix_audio, "VideoStreamPlayback", "mix_audio", 93876830_i64)
      val_0 = num_frames
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = buffer
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = offset
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      ret = 0_i64
      godot_ptrcall(@@mb_mix_audio, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
  end
  class VideoStreamPlayer < Godot::Control
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_stream : Void* = Pointer(Void).null
    def set_stream(stream : VideoStream) : Void
      godot_bind(@@mb_set_stream, "VideoStreamPlayer", "set_stream", 2317102564_i64)
      arg_ptr_0 = stream ? stream.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_stream, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_stream : Void* = Pointer(Void).null
    def get_stream() : VideoStream
      godot_bind(@@mb_get_stream, "VideoStreamPlayer", "get_stream", 438621487_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_stream, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(VideoStream, ret_ptr)
    end
    @@mb_play : Void* = Pointer(Void).null
    def play() : Void
      godot_bind(@@mb_play, "VideoStreamPlayer", "play", 3218959716_i64)
      godot_ptrcall(@@mb_play, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_stop : Void* = Pointer(Void).null
    def stop() : Void
      godot_bind(@@mb_stop, "VideoStreamPlayer", "stop", 3218959716_i64)
      godot_ptrcall(@@mb_stop, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_is_playing : Void* = Pointer(Void).null
    def is_playing() : Bool
      godot_bind(@@mb_is_playing, "VideoStreamPlayer", "is_playing", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_playing, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_paused : Void* = Pointer(Void).null
    def set_paused(paused : Bool) : Void
      godot_bind(@@mb_set_paused, "VideoStreamPlayer", "set_paused", 2586408642_i64)
      val_0 = paused
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_paused, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_paused : Void* = Pointer(Void).null
    def is_paused() : Bool
      godot_bind(@@mb_is_paused, "VideoStreamPlayer", "is_paused", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_paused, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_loop : Void* = Pointer(Void).null
    def set_loop(loop : Bool) : Void
      godot_bind(@@mb_set_loop, "VideoStreamPlayer", "set_loop", 2586408642_i64)
      val_0 = loop
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_loop, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_has_loop : Void* = Pointer(Void).null
    def has_loop() : Bool
      godot_bind(@@mb_has_loop, "VideoStreamPlayer", "has_loop", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_has_loop, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_volume : Void* = Pointer(Void).null
    def set_volume(volume : Float64) : Void
      godot_bind(@@mb_set_volume, "VideoStreamPlayer", "set_volume", 373806689_i64)
      val_0 = volume
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_volume, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_volume : Void* = Pointer(Void).null
    def get_volume() : Float64
      godot_bind(@@mb_get_volume, "VideoStreamPlayer", "get_volume", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_volume, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_volume_db : Void* = Pointer(Void).null
    def set_volume_db(db : Float64) : Void
      godot_bind(@@mb_set_volume_db, "VideoStreamPlayer", "set_volume_db", 373806689_i64)
      val_0 = db
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_volume_db, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_volume_db : Void* = Pointer(Void).null
    def get_volume_db() : Float64
      godot_bind(@@mb_get_volume_db, "VideoStreamPlayer", "get_volume_db", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_volume_db, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_speed_scale : Void* = Pointer(Void).null
    def set_speed_scale(speed_scale : Float64) : Void
      godot_bind(@@mb_set_speed_scale, "VideoStreamPlayer", "set_speed_scale", 373806689_i64)
      val_0 = speed_scale
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_speed_scale, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_speed_scale : Void* = Pointer(Void).null
    def get_speed_scale() : Float64
      godot_bind(@@mb_get_speed_scale, "VideoStreamPlayer", "get_speed_scale", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_speed_scale, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_audio_track : Void* = Pointer(Void).null
    def set_audio_track(track : Int64) : Void
      godot_bind(@@mb_set_audio_track, "VideoStreamPlayer", "set_audio_track", 1286410249_i64)
      val_0 = track
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_audio_track, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_audio_track : Void* = Pointer(Void).null
    def get_audio_track() : Int64
      godot_bind(@@mb_get_audio_track, "VideoStreamPlayer", "get_audio_track", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_audio_track, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_stream_name : Void* = Pointer(Void).null
    def get_stream_name() : String
      godot_bind(@@mb_get_stream_name, "VideoStreamPlayer", "get_stream_name", 201670096_i64)
      godot_call_str("get_stream_name")
    end
    @@mb_get_stream_length : Void* = Pointer(Void).null
    def get_stream_length() : Float64
      godot_bind(@@mb_get_stream_length, "VideoStreamPlayer", "get_stream_length", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_stream_length, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_stream_position : Void* = Pointer(Void).null
    def set_stream_position(position : Float64) : Void
      godot_bind(@@mb_set_stream_position, "VideoStreamPlayer", "set_stream_position", 373806689_i64)
      val_0 = position
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_stream_position, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_stream_position : Void* = Pointer(Void).null
    def get_stream_position() : Float64
      godot_bind(@@mb_get_stream_position, "VideoStreamPlayer", "get_stream_position", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_stream_position, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_autoplay : Void* = Pointer(Void).null
    def set_autoplay(enabled : Bool) : Void
      godot_bind(@@mb_set_autoplay, "VideoStreamPlayer", "set_autoplay", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_autoplay, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_has_autoplay : Void* = Pointer(Void).null
    def has_autoplay() : Bool
      godot_bind(@@mb_has_autoplay, "VideoStreamPlayer", "has_autoplay", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_has_autoplay, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_expand : Void* = Pointer(Void).null
    def set_expand(enable : Bool) : Void
      godot_bind(@@mb_set_expand, "VideoStreamPlayer", "set_expand", 2586408642_i64)
      val_0 = enable
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_expand, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_has_expand : Void* = Pointer(Void).null
    def has_expand() : Bool
      godot_bind(@@mb_has_expand, "VideoStreamPlayer", "has_expand", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_has_expand, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_buffering_msec : Void* = Pointer(Void).null
    def set_buffering_msec(msec : Int64) : Void
      godot_bind(@@mb_set_buffering_msec, "VideoStreamPlayer", "set_buffering_msec", 1286410249_i64)
      val_0 = msec
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_buffering_msec, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_buffering_msec : Void* = Pointer(Void).null
    def get_buffering_msec() : Int64
      godot_bind(@@mb_get_buffering_msec, "VideoStreamPlayer", "get_buffering_msec", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_buffering_msec, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_bus : Void* = Pointer(Void).null
    def set_bus(bus : String) : Void
      godot_bind(@@mb_set_bus, "VideoStreamPlayer", "set_bus", 3304788590_i64)
      sn_0 = Bridge.make_string_name(bus)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_bus, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_bus : Void* = Pointer(Void).null
    def get_bus() : String
      godot_bind(@@mb_get_bus, "VideoStreamPlayer", "get_bus", 2002593661_i64)
      godot_call_str("get_bus")
    end
    @@mb_get_video_texture : Void* = Pointer(Void).null
    def get_video_texture() : Texture2D
      godot_bind(@@mb_get_video_texture, "VideoStreamPlayer", "get_video_texture", 3635182373_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_video_texture, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Texture2D, ret_ptr)
    end
    # Property `audio_track` getter
    def audio_track
      get_audio_track
    end
    # Property `audio_track` setter
    def audio_track=(val : Int)
      set_audio_track(val.to_i64)
    end
    # Property `stream` getter
    def stream
      get_stream
    end
    # Property `stream` setter
    def stream=(val)
      set_stream(val)
    end
    # Property `volume_db` getter
    def volume_db
      get_volume_db
    end
    # Property `volume_db` setter
    def volume_db=(val : Number)
      set_volume_db(val.to_f64)
    end
    # Property `volume` getter
    def volume
      get_volume
    end
    # Property `volume` setter
    def volume=(val : Number)
      set_volume(val.to_f64)
    end
    # Property `speed_scale` getter
    def speed_scale
      get_speed_scale
    end
    # Property `speed_scale` setter
    def speed_scale=(val : Number)
      set_speed_scale(val.to_f64)
    end
    # Property `autoplay` getter
    def autoplay
      has_autoplay
    end
    def autoplay?
      autoplay
    end
    # Property `autoplay` setter
    def autoplay=(val)
      set_autoplay(val)
    end
    # Property `paused` getter
    def paused
      is_paused
    end
    def paused?
      paused
    end
    # Property `paused` setter
    def paused=(val)
      set_paused(val)
    end
    # Property `expand` getter
    def expand
      has_expand
    end
    def expand?
      expand
    end
    # Property `expand` setter
    def expand=(val)
      set_expand(val)
    end
    # Property `loop` getter
    def loop
      has_loop
    end
    def loop?
      loop
    end
    # Property `loop` setter
    def loop=(val)
      set_loop(val)
    end
    # Property `buffering_msec` getter
    def buffering_msec
      get_buffering_msec
    end
    # Property `buffering_msec` setter
    def buffering_msec=(val : Int)
      set_buffering_msec(val.to_i64)
    end
    # Property `stream_position` getter
    def stream_position
      get_stream_position
    end
    # Property `stream_position` setter
    def stream_position=(val : Number)
      set_stream_position(val.to_f64)
    end
    # Property `bus` getter
    def bus
      get_bus
    end
    # Property `bus` setter
    def bus=(val)
      set_bus(val)
    end
    godot_signal finished
  end
  class VideoStreamTheora < Godot::VideoStream
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class ViewportTexture < Godot::Texture2D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_viewport_path_in_scene : Void* = Pointer(Void).null
    def set_viewport_path_in_scene(path : NodePath | String) : Void
      godot_bind(@@mb_set_viewport_path_in_scene, "ViewportTexture", "set_viewport_path_in_scene", 1348162250_i64)
      np_0 = Bridge.make_nodepath(path.to_s)
      arg_0 = np_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_viewport_path_in_scene, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_nodepath(np_0)
    end
    @@mb_get_viewport_path_in_scene : Void* = Pointer(Void).null
    def get_viewport_path_in_scene() : NodePath
      godot_bind(@@mb_get_viewport_path_in_scene, "ViewportTexture", "get_viewport_path_in_scene", 4075236667_i64)
      NodePath.new(godot_call_str("get_viewport_path_in_scene"))
    end
    # Property `viewport_path` getter
    def viewport_path
      get_viewport_path_in_scene
    end
    # Property `viewport_path` setter
    def viewport_path=(val)
      set_viewport_path_in_scene(val)
    end
  end
  class VirtualJoystick < Godot::Control
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum JoystickMode : Int64
      JoystickFixed = 0_i64
      JoystickDynamic = 1_i64
      JoystickFollowing = 2_i64
    end
    enum VisibilityMode : Int64
      VisibilityAlways = 0_i64
      VisibilityWhenTouched = 1_i64
    end
    @@mb_set_joystick_mode : Void* = Pointer(Void).null
    def set_joystick_mode(mode : JoystickMode | Int) : Void
      godot_bind(@@mb_set_joystick_mode, "VirtualJoystick", "set_joystick_mode", 1316760817_i64)
      val_0 = mode.is_a?(Int) ? mode.to_i64 : mode.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_joystick_mode, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_joystick_mode : Void* = Pointer(Void).null
    def get_joystick_mode() : JoystickMode
      godot_bind(@@mb_get_joystick_mode, "VirtualJoystick", "get_joystick_mode", 2694680530_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_joystick_mode, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(JoystickMode, ret)
    end
    @@mb_set_joystick_size : Void* = Pointer(Void).null
    def set_joystick_size(size : Float64) : Void
      godot_bind(@@mb_set_joystick_size, "VirtualJoystick", "set_joystick_size", 373806689_i64)
      val_0 = size
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_joystick_size, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_joystick_size : Void* = Pointer(Void).null
    def get_joystick_size() : Float64
      godot_bind(@@mb_get_joystick_size, "VirtualJoystick", "get_joystick_size", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_joystick_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_tip_size : Void* = Pointer(Void).null
    def set_tip_size(size : Float64) : Void
      godot_bind(@@mb_set_tip_size, "VirtualJoystick", "set_tip_size", 373806689_i64)
      val_0 = size
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_tip_size, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_tip_size : Void* = Pointer(Void).null
    def get_tip_size() : Float64
      godot_bind(@@mb_get_tip_size, "VirtualJoystick", "get_tip_size", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_tip_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_deadzone_ratio : Void* = Pointer(Void).null
    def set_deadzone_ratio(ratio : Float64) : Void
      godot_bind(@@mb_set_deadzone_ratio, "VirtualJoystick", "set_deadzone_ratio", 373806689_i64)
      val_0 = ratio
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_deadzone_ratio, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_deadzone_ratio : Void* = Pointer(Void).null
    def get_deadzone_ratio() : Float64
      godot_bind(@@mb_get_deadzone_ratio, "VirtualJoystick", "get_deadzone_ratio", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_deadzone_ratio, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_clampzone_ratio : Void* = Pointer(Void).null
    def set_clampzone_ratio(ratio : Float64) : Void
      godot_bind(@@mb_set_clampzone_ratio, "VirtualJoystick", "set_clampzone_ratio", 373806689_i64)
      val_0 = ratio
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_clampzone_ratio, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_clampzone_ratio : Void* = Pointer(Void).null
    def get_clampzone_ratio() : Float64
      godot_bind(@@mb_get_clampzone_ratio, "VirtualJoystick", "get_clampzone_ratio", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_clampzone_ratio, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_initial_offset_ratio : Void* = Pointer(Void).null
    def set_initial_offset_ratio(ratio : Vector2) : Void
      godot_bind(@@mb_set_initial_offset_ratio, "VirtualJoystick", "set_initial_offset_ratio", 743155724_i64)
      val_0 = ratio
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_initial_offset_ratio, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_initial_offset_ratio : Void* = Pointer(Void).null
    def get_initial_offset_ratio() : Vector2
      godot_bind(@@mb_get_initial_offset_ratio, "VirtualJoystick", "get_initial_offset_ratio", 3341600327_i64)
      ret = Vector2.new
      godot_ptrcall(@@mb_get_initial_offset_ratio, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_action_left : Void* = Pointer(Void).null
    def set_action_left(action : String) : Void
      godot_bind(@@mb_set_action_left, "VirtualJoystick", "set_action_left", 3304788590_i64)
      sn_0 = Bridge.make_string_name(action)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_action_left, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_action_left : Void* = Pointer(Void).null
    def get_action_left() : String
      godot_bind(@@mb_get_action_left, "VirtualJoystick", "get_action_left", 2002593661_i64)
      godot_call_str("get_action_left")
    end
    @@mb_set_action_right : Void* = Pointer(Void).null
    def set_action_right(action : String) : Void
      godot_bind(@@mb_set_action_right, "VirtualJoystick", "set_action_right", 3304788590_i64)
      sn_0 = Bridge.make_string_name(action)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_action_right, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_action_right : Void* = Pointer(Void).null
    def get_action_right() : String
      godot_bind(@@mb_get_action_right, "VirtualJoystick", "get_action_right", 2002593661_i64)
      godot_call_str("get_action_right")
    end
    @@mb_set_action_up : Void* = Pointer(Void).null
    def set_action_up(action : String) : Void
      godot_bind(@@mb_set_action_up, "VirtualJoystick", "set_action_up", 3304788590_i64)
      sn_0 = Bridge.make_string_name(action)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_action_up, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_action_up : Void* = Pointer(Void).null
    def get_action_up() : String
      godot_bind(@@mb_get_action_up, "VirtualJoystick", "get_action_up", 2002593661_i64)
      godot_call_str("get_action_up")
    end
    @@mb_set_action_down : Void* = Pointer(Void).null
    def set_action_down(action : String) : Void
      godot_bind(@@mb_set_action_down, "VirtualJoystick", "set_action_down", 3304788590_i64)
      sn_0 = Bridge.make_string_name(action)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_action_down, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_action_down : Void* = Pointer(Void).null
    def get_action_down() : String
      godot_bind(@@mb_get_action_down, "VirtualJoystick", "get_action_down", 2002593661_i64)
      godot_call_str("get_action_down")
    end
    @@mb_set_visibility_mode : Void* = Pointer(Void).null
    def set_visibility_mode(mode : VisibilityMode | Int) : Void
      godot_bind(@@mb_set_visibility_mode, "VirtualJoystick", "set_visibility_mode", 2638298545_i64)
      val_0 = mode.is_a?(Int) ? mode.to_i64 : mode.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_visibility_mode, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_visibility_mode : Void* = Pointer(Void).null
    def get_visibility_mode() : VisibilityMode
      godot_bind(@@mb_get_visibility_mode, "VirtualJoystick", "get_visibility_mode", 3530872950_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_visibility_mode, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(VisibilityMode, ret)
    end
    # Property `joystick_mode` getter
    def joystick_mode
      get_joystick_mode
    end
    # Property `joystick_mode` setter
    def joystick_mode=(val : Int)
      set_joystick_mode(val.to_i64)
    end
    # Property `joystick_size` getter
    def joystick_size
      get_joystick_size
    end
    # Property `joystick_size` setter
    def joystick_size=(val : Number)
      set_joystick_size(val.to_f64)
    end
    # Property `tip_size` getter
    def tip_size
      get_tip_size
    end
    # Property `tip_size` setter
    def tip_size=(val : Number)
      set_tip_size(val.to_f64)
    end
    # Property `deadzone_ratio` getter
    def deadzone_ratio
      get_deadzone_ratio
    end
    # Property `deadzone_ratio` setter
    def deadzone_ratio=(val : Number)
      set_deadzone_ratio(val.to_f64)
    end
    # Property `clampzone_ratio` getter
    def clampzone_ratio
      get_clampzone_ratio
    end
    # Property `clampzone_ratio` setter
    def clampzone_ratio=(val : Number)
      set_clampzone_ratio(val.to_f64)
    end
    # Property `initial_offset_ratio` getter
    def initial_offset_ratio
      get_initial_offset_ratio
    end
    # Property `initial_offset_ratio` setter
    def initial_offset_ratio=(val)
      set_initial_offset_ratio(val)
    end
    # Property `action_left` getter
    def action_left
      get_action_left
    end
    # Property `action_left` setter
    def action_left=(val)
      set_action_left(val)
    end
    # Property `action_right` getter
    def action_right
      get_action_right
    end
    # Property `action_right` setter
    def action_right=(val)
      set_action_right(val)
    end
    # Property `action_up` getter
    def action_up
      get_action_up
    end
    # Property `action_up` setter
    def action_up=(val)
      set_action_up(val)
    end
    # Property `action_down` getter
    def action_down
      get_action_down
    end
    # Property `action_down` setter
    def action_down=(val)
      set_action_down(val)
    end
    # Property `visibility_mode` getter
    def visibility_mode
      get_visibility_mode
    end
    # Property `visibility_mode` setter
    def visibility_mode=(val : Int)
      set_visibility_mode(val.to_i64)
    end
    godot_signal pressed
    godot_signal tapped
    godot_signal released, Vector2
    godot_signal flicked, Vector2
    godot_signal flick_canceled
  end
  class VisibleOnScreenNotifier2D < Godot::Node2D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_rect : Void* = Pointer(Void).null
    def set_rect(rect : Rect2) : Void
      godot_bind(@@mb_set_rect, "VisibleOnScreenNotifier2D", "set_rect", 2046264180_i64)
      val_0 = rect
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_rect, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_rect : Void* = Pointer(Void).null
    def get_rect() : Rect2
      godot_bind(@@mb_get_rect, "VisibleOnScreenNotifier2D", "get_rect", 1639390495_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_rect, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Rect2, ret_ptr)
    end
    @@mb_set_show_rect : Void* = Pointer(Void).null
    def set_show_rect(show_rect : Bool) : Void
      godot_bind(@@mb_set_show_rect, "VisibleOnScreenNotifier2D", "set_show_rect", 2586408642_i64)
      val_0 = show_rect
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_show_rect, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_showing_rect : Void* = Pointer(Void).null
    def is_showing_rect() : Bool
      godot_bind(@@mb_is_showing_rect, "VisibleOnScreenNotifier2D", "is_showing_rect", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_showing_rect, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_is_on_screen : Void* = Pointer(Void).null
    def is_on_screen() : Bool
      godot_bind(@@mb_is_on_screen, "VisibleOnScreenNotifier2D", "is_on_screen", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_on_screen, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `rect` getter
    def rect
      get_rect
    end
    # Property `rect` setter
    def rect=(val)
      set_rect(val)
    end
    # Property `show_rect` getter
    def show_rect
      is_showing_rect
    end
    def show_rect?
      show_rect
    end
    # Property `show_rect` setter
    def show_rect=(val)
      set_show_rect(val)
    end
    godot_signal screen_entered
    godot_signal screen_exited
  end
  class VisibleOnScreenEnabler2D < Godot::VisibleOnScreenNotifier2D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum EnableMode : Int64
      EnableModeInherit = 0_i64
      EnableModeAlways = 1_i64
      EnableModeWhenPaused = 2_i64
    end
    @@mb_set_enable_mode : Void* = Pointer(Void).null
    def set_enable_mode(mode : EnableMode | Int) : Void
      godot_bind(@@mb_set_enable_mode, "VisibleOnScreenEnabler2D", "set_enable_mode", 2961788752_i64)
      val_0 = mode.is_a?(Int) ? mode.to_i64 : mode.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_enable_mode, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_enable_mode : Void* = Pointer(Void).null
    def get_enable_mode() : EnableMode
      godot_bind(@@mb_get_enable_mode, "VisibleOnScreenEnabler2D", "get_enable_mode", 2650445576_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_enable_mode, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(EnableMode, ret)
    end
    @@mb_set_enable_node_path : Void* = Pointer(Void).null
    def set_enable_node_path(path : NodePath | String) : Void
      godot_bind(@@mb_set_enable_node_path, "VisibleOnScreenEnabler2D", "set_enable_node_path", 1348162250_i64)
      np_0 = Bridge.make_nodepath(path.to_s)
      arg_0 = np_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_enable_node_path, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_nodepath(np_0)
    end
    @@mb_get_enable_node_path : Void* = Pointer(Void).null
    def get_enable_node_path() : NodePath
      godot_bind(@@mb_get_enable_node_path, "VisibleOnScreenEnabler2D", "get_enable_node_path", 277076166_i64)
      NodePath.new(godot_call_str("get_enable_node_path"))
    end
    # Property `enable_mode` getter
    def enable_mode
      get_enable_mode
    end
    # Property `enable_mode` setter
    def enable_mode=(val : Int)
      set_enable_mode(val.to_i64)
    end
    # Property `enable_node_path` getter
    def enable_node_path
      get_enable_node_path
    end
    # Property `enable_node_path` setter
    def enable_node_path=(val)
      set_enable_node_path(val)
    end
  end
  class VisibleOnScreenNotifier3D < Godot::VisualInstance3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_aabb : Void* = Pointer(Void).null
    def set_aabb(rect : AABB) : Void
      godot_bind(@@mb_set_aabb, "VisibleOnScreenNotifier3D", "set_aabb", 259215842_i64)
      val_0 = rect
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_aabb, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_on_screen : Void* = Pointer(Void).null
    def is_on_screen() : Bool
      godot_bind(@@mb_is_on_screen, "VisibleOnScreenNotifier3D", "is_on_screen", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_on_screen, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `aabb` getter
    def aabb
      get_aabb
    end
    # Property `aabb` setter
    def aabb=(val)
      set_aabb(val)
    end
    godot_signal screen_entered
    godot_signal screen_exited
  end
  class VisibleOnScreenEnabler3D < Godot::VisibleOnScreenNotifier3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum EnableMode : Int64
      EnableModeInherit = 0_i64
      EnableModeAlways = 1_i64
      EnableModeWhenPaused = 2_i64
    end
    @@mb_set_enable_mode : Void* = Pointer(Void).null
    def set_enable_mode(mode : EnableMode | Int) : Void
      godot_bind(@@mb_set_enable_mode, "VisibleOnScreenEnabler3D", "set_enable_mode", 320303646_i64)
      val_0 = mode.is_a?(Int) ? mode.to_i64 : mode.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_enable_mode, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_enable_mode : Void* = Pointer(Void).null
    def get_enable_mode() : EnableMode
      godot_bind(@@mb_get_enable_mode, "VisibleOnScreenEnabler3D", "get_enable_mode", 3352990031_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_enable_mode, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(EnableMode, ret)
    end
    @@mb_set_enable_node_path : Void* = Pointer(Void).null
    def set_enable_node_path(path : NodePath | String) : Void
      godot_bind(@@mb_set_enable_node_path, "VisibleOnScreenEnabler3D", "set_enable_node_path", 1348162250_i64)
      np_0 = Bridge.make_nodepath(path.to_s)
      arg_0 = np_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_enable_node_path, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_nodepath(np_0)
    end
    @@mb_get_enable_node_path : Void* = Pointer(Void).null
    def get_enable_node_path() : NodePath
      godot_bind(@@mb_get_enable_node_path, "VisibleOnScreenEnabler3D", "get_enable_node_path", 277076166_i64)
      NodePath.new(godot_call_str("get_enable_node_path"))
    end
    # Property `enable_mode` getter
    def enable_mode
      get_enable_mode
    end
    # Property `enable_mode` setter
    def enable_mode=(val : Int)
      set_enable_mode(val.to_i64)
    end
    # Property `enable_node_path` getter
    def enable_node_path
      get_enable_node_path
    end
    # Property `enable_node_path` setter
    def enable_node_path=(val)
      set_enable_node_path(val)
    end
  end
  class VisualShader < Godot::Shader
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Type : Int64
      TypeVertex = 0_i64
      TypeFragment = 1_i64
      TypeLight = 2_i64
      TypeStart = 3_i64
      TypeProcess = 4_i64
      TypeCollide = 5_i64
      TypeStartCustom = 6_i64
      TypeProcessCustom = 7_i64
      TypeSky = 8_i64
      TypeFog = 9_i64
      TypeTextureBlit = 10_i64
      TypeMax = 11_i64
    end
    enum VaryingMode : Int64
      VaryingModeVertexToFragLight = 0_i64
      VaryingModeFragToLight = 1_i64
      VaryingModeMax = 2_i64
    end
    enum VaryingType : Int64
      VaryingTypeFloat = 0_i64
      VaryingTypeInt = 1_i64
      VaryingTypeUint = 2_i64
      VaryingTypeVector2d = 3_i64
      VaryingTypeVector3d = 4_i64
      VaryingTypeVector4d = 5_i64
      VaryingTypeBoolean = 6_i64
      VaryingTypeTransform = 7_i64
      VaryingTypeMax = 8_i64
    end
    @@mb_set_mode : Void* = Pointer(Void).null
    def set_mode(mode : Godot::Shader::Mode | Int) : Void
      godot_bind(@@mb_set_mode, "VisualShader", "set_mode", 3978014962_i64)
      val_0 = mode.is_a?(Int) ? mode.to_i64 : mode.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_mode, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_add_node : Void* = Pointer(Void).null
    def add_node(get_type : Type | Int, node : VisualShaderNode, position : Vector2, id : Int64) : Void
      godot_bind(@@mb_add_node, "VisualShader", "add_node", 1560769431_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      arg_ptr_1 = node ? node.pointer : Pointer(Void).null
      arg_1 = pointerof(arg_ptr_1).as(Void*)
      val_2 = position
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = id
      arg_3 = pointerof(val_3).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3]
      godot_ptrcall(@@mb_add_node, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_node : Void* = Pointer(Void).null
    def get_node(get_type : Type | Int, id : Int64) : VisualShaderNode
      godot_bind(@@mb_get_node, "VisualShader", "get_node", 3784670312_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = id
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_node, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      godot_return_obj(VisualShaderNode, ret_ptr)
    end
    @@mb_set_node_position : Void* = Pointer(Void).null
    def set_node_position(get_type : Type | Int, id : Int64, position : Vector2) : Void
      godot_bind(@@mb_set_node_position, "VisualShader", "set_node_position", 2726660721_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = id
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = position
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_set_node_position, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_node_position : Void* = Pointer(Void).null
    def get_node_position(get_type : Type | Int, id : Int64) : Vector2
      godot_bind(@@mb_get_node_position, "VisualShader", "get_node_position", 2175036082_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = id
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret = Vector2.new
      godot_ptrcall(@@mb_get_node_position, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_node_list : Void* = Pointer(Void).null
    def get_node_list(get_type : Type | Int) : Pointer(Void)
      godot_bind(@@mb_get_node_list, "VisualShader", "get_node_list", 2370592410_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_node_list, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_get_valid_node_id : Void* = Pointer(Void).null
    def get_valid_node_id(get_type : Type | Int) : Int64
      godot_bind(@@mb_get_valid_node_id, "VisualShader", "get_valid_node_id", 629467342_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_valid_node_id, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_remove_node : Void* = Pointer(Void).null
    def remove_node(get_type : Type | Int, id : Int64) : Void
      godot_bind(@@mb_remove_node, "VisualShader", "remove_node", 844050912_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = id
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_remove_node, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_replace_node : Void* = Pointer(Void).null
    def replace_node(get_type : Type | Int, id : Int64, new_class : String) : Void
      godot_bind(@@mb_replace_node, "VisualShader", "replace_node", 3144735253_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = id
      arg_1 = pointerof(val_1).as(Void*)
      sn_2 = Bridge.make_string_name(new_class)
      arg_2 = sn_2
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_replace_node, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_2)
    end
    @@mb_is_node_connection : Void* = Pointer(Void).null
    def is_node_connection(get_type : Type | Int, from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Bool
      godot_bind(@@mb_is_node_connection, "VisualShader", "is_node_connection", 3922381898_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_node
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = from_port
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_node
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = to_port
      arg_4 = pointerof(val_4).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3, arg_4]
      ret = 0_u8
      godot_ptrcall(@@mb_is_node_connection, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_can_connect_nodes : Void* = Pointer(Void).null
    def can_connect_nodes(get_type : Type | Int, from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Bool
      godot_bind(@@mb_can_connect_nodes, "VisualShader", "can_connect_nodes", 3922381898_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_node
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = from_port
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_node
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = to_port
      arg_4 = pointerof(val_4).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3, arg_4]
      ret = 0_u8
      godot_ptrcall(@@mb_can_connect_nodes, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_connect_nodes : Void* = Pointer(Void).null
    def connect_nodes(get_type : Type | Int, from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Godot::Error
      godot_bind(@@mb_connect_nodes, "VisualShader", "connect_nodes", 3081049573_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_node
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = from_port
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_node
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = to_port
      arg_4 = pointerof(val_4).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3, arg_4]
      ret = 0_i64
      godot_ptrcall(@@mb_connect_nodes, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_disconnect_nodes : Void* = Pointer(Void).null
    def disconnect_nodes(get_type : Type | Int, from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Void
      godot_bind(@@mb_disconnect_nodes, "VisualShader", "disconnect_nodes", 2268060358_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_node
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = from_port
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_node
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = to_port
      arg_4 = pointerof(val_4).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3, arg_4]
      godot_ptrcall(@@mb_disconnect_nodes, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_connect_nodes_forced : Void* = Pointer(Void).null
    def connect_nodes_forced(get_type : Type | Int, from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Void
      godot_bind(@@mb_connect_nodes_forced, "VisualShader", "connect_nodes_forced", 2268060358_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_node
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = from_port
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_node
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = to_port
      arg_4 = pointerof(val_4).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3, arg_4]
      godot_ptrcall(@@mb_connect_nodes_forced, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_node_connections : Void* = Pointer(Void).null
    def get_node_connections(get_type : Type | Int) : Pointer(Void)
      godot_bind(@@mb_get_node_connections, "VisualShader", "get_node_connections", 1441964831_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_node_connections, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_attach_node_to_frame : Void* = Pointer(Void).null
    def attach_node_to_frame(get_type : Type | Int, id : Int64, frame : Int64) : Void
      godot_bind(@@mb_attach_node_to_frame, "VisualShader", "attach_node_to_frame", 2479945279_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = id
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = frame
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_attach_node_to_frame, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_detach_node_from_frame : Void* = Pointer(Void).null
    def detach_node_from_frame(get_type : Type | Int, id : Int64) : Void
      godot_bind(@@mb_detach_node_from_frame, "VisualShader", "detach_node_from_frame", 844050912_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = id
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_detach_node_from_frame, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_add_varying : Void* = Pointer(Void).null
    def add_varying(name : String, mode : VaryingMode | Int, get_type : VaryingType | Int) : Void
      godot_bind(@@mb_add_varying, "VisualShader", "add_varying", 2084110726_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      val_1 = mode.is_a?(Int) ? mode.to_i64 : mode.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_add_varying, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_remove_varying : Void* = Pointer(Void).null
    def remove_varying(name : String) : Void
      godot_bind(@@mb_remove_varying, "VisualShader", "remove_varying", 83702148_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_remove_varying, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_has_varying : Void* = Pointer(Void).null
    def has_varying(name : String) : Bool
      godot_bind(@@mb_has_varying, "VisualShader", "has_varying", 3927539163_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_has_varying, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_set_graph_offset : Void* = Pointer(Void).null
    def set_graph_offset(offset : Vector2) : Void
      godot_bind(@@mb_set_graph_offset, "VisualShader", "set_graph_offset", 743155724_i64)
      val_0 = offset
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_graph_offset, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_graph_offset : Void* = Pointer(Void).null
    def get_graph_offset() : Vector2
      godot_bind(@@mb_get_graph_offset, "VisualShader", "get_graph_offset", 3341600327_i64)
      ret = Vector2.new
      godot_ptrcall(@@mb_get_graph_offset, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `graph_offset` getter
    def graph_offset
      get_graph_offset
    end
    # Property `graph_offset` setter
    def graph_offset=(val)
      set_graph_offset(val)
    end
  end
  class VisualShaderGroup < Godot::Resource
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_group_name : Void* = Pointer(Void).null
    def set_group_name(name : String) : Void
      godot_bind(@@mb_set_group_name, "VisualShaderGroup", "set_group_name", 83702148_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_group_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_group_name : Void* = Pointer(Void).null
    def get_group_name() : String
      godot_bind(@@mb_get_group_name, "VisualShaderGroup", "get_group_name", 201670096_i64)
      godot_call_str("get_group_name")
    end
    @@mb_insert_input_port : Void* = Pointer(Void).null
    def insert_input_port(id : Int64, get_type : Godot::VisualShaderNode::PortType | Int, name : String) : String
      godot_bind(@@mb_insert_input_port, "VisualShaderGroup", "insert_input_port", 3880595796_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      str_2 = Bridge.make_string(name)
      arg_2 = str_2
      args = [arg_0, arg_1, arg_2]
      godot_call_str("insert_input_port", id, get_type, name)
    ensure
      Bridge.free_string(str_2)
    end
    @@mb_remove_input_port : Void* = Pointer(Void).null
    def remove_input_port(id : Int64) : Void
      godot_bind(@@mb_remove_input_port, "VisualShaderGroup", "remove_input_port", 1286410249_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_input_port, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_move_input_port : Void* = Pointer(Void).null
    def move_input_port(from : Int64, to : Int64) : Void
      godot_bind(@@mb_move_input_port, "VisualShaderGroup", "move_input_port", 3937882851_i64)
      val_0 = from
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = to
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_move_input_port, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_set_input_port_name : Void* = Pointer(Void).null
    def set_input_port_name(id : Int64, name : String) : Void
      godot_bind(@@mb_set_input_port_name, "VisualShaderGroup", "set_input_port_name", 501894301_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      str_1 = Bridge.make_string(name)
      arg_1 = str_1
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_input_port_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_1)
    end
    @@mb_set_input_port_type : Void* = Pointer(Void).null
    def set_input_port_type(id : Int64, get_type : Godot::VisualShaderNode::PortType | Int) : Void
      godot_bind(@@mb_set_input_port_type, "VisualShaderGroup", "set_input_port_type", 1959648900_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_input_port_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_set_input_port_count : Void* = Pointer(Void).null
    def set_input_port_count(count : Int64) : Void
      godot_bind(@@mb_set_input_port_count, "VisualShaderGroup", "set_input_port_count", 1286410249_i64)
      val_0 = count
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_input_port_count, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_input_port_count : Void* = Pointer(Void).null
    def get_input_port_count() : Int64
      godot_bind(@@mb_get_input_port_count, "VisualShaderGroup", "get_input_port_count", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_input_port_count, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_input_port_name : Void* = Pointer(Void).null
    def get_input_port_name(id : Int64) : String
      godot_bind(@@mb_get_input_port_name, "VisualShaderGroup", "get_input_port_name", 844755477_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_call_str("get_input_port_name", id)
    end
    @@mb_get_input_port_type : Void* = Pointer(Void).null
    def get_input_port_type(id : Int64) : Godot::VisualShaderNode::PortType
      godot_bind(@@mb_get_input_port_type, "VisualShaderGroup", "get_input_port_type", 4102573379_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_input_port_type, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::VisualShaderNode::PortType, ret)
    end
    @@mb_insert_output_port : Void* = Pointer(Void).null
    def insert_output_port(id : Int64, get_type : Godot::VisualShaderNode::PortType | Int, name : String) : String
      godot_bind(@@mb_insert_output_port, "VisualShaderGroup", "insert_output_port", 3880595796_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      str_2 = Bridge.make_string(name)
      arg_2 = str_2
      args = [arg_0, arg_1, arg_2]
      godot_call_str("insert_output_port", id, get_type, name)
    ensure
      Bridge.free_string(str_2)
    end
    @@mb_remove_output_port : Void* = Pointer(Void).null
    def remove_output_port(id : Int64) : Void
      godot_bind(@@mb_remove_output_port, "VisualShaderGroup", "remove_output_port", 1286410249_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_output_port, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_move_output_port : Void* = Pointer(Void).null
    def move_output_port(from : Int64, to : Int64) : Void
      godot_bind(@@mb_move_output_port, "VisualShaderGroup", "move_output_port", 3937882851_i64)
      val_0 = from
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = to
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_move_output_port, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_set_output_port_name : Void* = Pointer(Void).null
    def set_output_port_name(id : Int64, name : String) : Void
      godot_bind(@@mb_set_output_port_name, "VisualShaderGroup", "set_output_port_name", 501894301_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      str_1 = Bridge.make_string(name)
      arg_1 = str_1
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_output_port_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_1)
    end
    @@mb_set_output_port_type : Void* = Pointer(Void).null
    def set_output_port_type(id : Int64, get_type : Godot::VisualShaderNode::PortType | Int) : Void
      godot_bind(@@mb_set_output_port_type, "VisualShaderGroup", "set_output_port_type", 1959648900_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_output_port_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_set_output_port_count : Void* = Pointer(Void).null
    def set_output_port_count(count : Int64) : Void
      godot_bind(@@mb_set_output_port_count, "VisualShaderGroup", "set_output_port_count", 1286410249_i64)
      val_0 = count
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_output_port_count, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_output_port_count : Void* = Pointer(Void).null
    def get_output_port_count() : Int64
      godot_bind(@@mb_get_output_port_count, "VisualShaderGroup", "get_output_port_count", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_output_port_count, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_output_port_name : Void* = Pointer(Void).null
    def get_output_port_name(id : Int64) : String
      godot_bind(@@mb_get_output_port_name, "VisualShaderGroup", "get_output_port_name", 844755477_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_call_str("get_output_port_name", id)
    end
    @@mb_get_output_port_type : Void* = Pointer(Void).null
    def get_output_port_type(id : Int64) : Godot::VisualShaderNode::PortType
      godot_bind(@@mb_get_output_port_type, "VisualShaderGroup", "get_output_port_type", 4102573379_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_output_port_type, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::VisualShaderNode::PortType, ret)
    end
    @@mb_add_node : Void* = Pointer(Void).null
    def add_node(node : VisualShaderNode, position : Vector2, id : Int64) : Void
      godot_bind(@@mb_add_node, "VisualShaderGroup", "add_node", 3625527446_i64)
      arg_ptr_0 = node ? node.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      val_1 = position
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = id
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_add_node, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_node : Void* = Pointer(Void).null
    def get_node(id : Int64) : VisualShaderNode
      godot_bind(@@mb_get_node, "VisualShaderGroup", "get_node", 1177927464_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_node, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      godot_return_obj(VisualShaderNode, ret_ptr)
    end
    @@mb_set_node_position : Void* = Pointer(Void).null
    def set_node_position(id : Int64, position : Vector2) : Void
      godot_bind(@@mb_set_node_position, "VisualShaderGroup", "set_node_position", 163021252_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = position
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_node_position, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_node_position : Void* = Pointer(Void).null
    def get_node_position(id : Int64) : Vector2
      godot_bind(@@mb_get_node_position, "VisualShaderGroup", "get_node_position", 2299179447_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = Vector2.new
      godot_ptrcall(@@mb_get_node_position, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_node_list : Void* = Pointer(Void).null
    def get_node_list() : Pointer(Void)
      godot_bind(@@mb_get_node_list, "VisualShaderGroup", "get_node_list", 1930428628_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_node_list, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_get_valid_node_id : Void* = Pointer(Void).null
    def get_valid_node_id() : Int64
      godot_bind(@@mb_get_valid_node_id, "VisualShaderGroup", "get_valid_node_id", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_valid_node_id, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_remove_node : Void* = Pointer(Void).null
    def remove_node(id : Int64) : Void
      godot_bind(@@mb_remove_node, "VisualShaderGroup", "remove_node", 1286410249_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_node, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_replace_node : Void* = Pointer(Void).null
    def replace_node(id : Int64, new_class : String) : Void
      godot_bind(@@mb_replace_node, "VisualShaderGroup", "replace_node", 3780747571_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      sn_1 = Bridge.make_string_name(new_class)
      arg_1 = sn_1
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_replace_node, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_1)
    end
    @@mb_is_node_connection : Void* = Pointer(Void).null
    def is_node_connection(from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Bool
      godot_bind(@@mb_is_node_connection, "VisualShaderGroup", "is_node_connection", 1701679529_i64)
      val_0 = from_node
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_port
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = to_node
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_port
      arg_3 = pointerof(val_3).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3]
      ret = 0_u8
      godot_ptrcall(@@mb_is_node_connection, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_can_connect_nodes : Void* = Pointer(Void).null
    def can_connect_nodes(from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Bool
      godot_bind(@@mb_can_connect_nodes, "VisualShaderGroup", "can_connect_nodes", 1701679529_i64)
      val_0 = from_node
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_port
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = to_node
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_port
      arg_3 = pointerof(val_3).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3]
      ret = 0_u8
      godot_ptrcall(@@mb_can_connect_nodes, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_connect_nodes : Void* = Pointer(Void).null
    def connect_nodes(from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Godot::Error
      godot_bind(@@mb_connect_nodes, "VisualShaderGroup", "connect_nodes", 3684568301_i64)
      val_0 = from_node
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_port
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = to_node
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_port
      arg_3 = pointerof(val_3).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3]
      ret = 0_i64
      godot_ptrcall(@@mb_connect_nodes, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_disconnect_nodes : Void* = Pointer(Void).null
    def disconnect_nodes(from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Void
      godot_bind(@@mb_disconnect_nodes, "VisualShaderGroup", "disconnect_nodes", 4275841770_i64)
      val_0 = from_node
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_port
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = to_node
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_port
      arg_3 = pointerof(val_3).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3]
      godot_ptrcall(@@mb_disconnect_nodes, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_connect_nodes_forced : Void* = Pointer(Void).null
    def connect_nodes_forced(from_node : Int64, from_port : Int64, to_node : Int64, to_port : Int64) : Void
      godot_bind(@@mb_connect_nodes_forced, "VisualShaderGroup", "connect_nodes_forced", 4275841770_i64)
      val_0 = from_node
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = from_port
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = to_node
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = to_port
      arg_3 = pointerof(val_3).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3]
      godot_ptrcall(@@mb_connect_nodes_forced, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_node_connections : Void* = Pointer(Void).null
    def get_node_connections() : Pointer(Void)
      godot_bind(@@mb_get_node_connections, "VisualShaderGroup", "get_node_connections", 3995934104_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_node_connections, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_attach_node_to_frame : Void* = Pointer(Void).null
    def attach_node_to_frame(id : Int64, frame : Int64) : Void
      godot_bind(@@mb_attach_node_to_frame, "VisualShaderGroup", "attach_node_to_frame", 3937882851_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = frame
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_attach_node_to_frame, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_detach_node_from_frame : Void* = Pointer(Void).null
    def detach_node_from_frame(id : Int64) : Void
      godot_bind(@@mb_detach_node_from_frame, "VisualShaderGroup", "detach_node_from_frame", 1286410249_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_detach_node_from_frame, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    # Property `group_name` getter
    def group_name
      get_group_name
    end
    # Property `group_name` setter
    def group_name=(val)
      set_group_name(val)
    end
    # Property `input_port_count` getter
    def input_port_count
      get_input_port_count
    end
    # Property `input_port_count` setter
    def input_port_count=(val : Int)
      set_input_port_count(val.to_i64)
    end
    # Property `output_port_count` getter
    def output_port_count
      get_output_port_count
    end
    # Property `output_port_count` setter
    def output_port_count=(val : Int)
      set_output_port_count(val.to_i64)
    end
  end
  class VisualShaderNode < Godot::Resource
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum PortType : Int64
      PortTypeScalar = 0_i64
      PortTypeScalarInt = 1_i64
      PortTypeScalarUint = 2_i64
      PortTypeVector2d = 3_i64
      PortTypeVector3d = 4_i64
      PortTypeVector4d = 5_i64
      PortTypeBoolean = 6_i64
      PortTypeTransform = 7_i64
      PortTypeSampler = 8_i64
      PortTypeMax = 9_i64
    end
    @@mb_get_default_input_port : Void* = Pointer(Void).null
    def get_default_input_port(get_type : PortType | Int) : Int64
      godot_bind(@@mb_get_default_input_port, "VisualShaderNode", "get_default_input_port", 1894493699_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_default_input_port, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_output_port_for_preview : Void* = Pointer(Void).null
    def set_output_port_for_preview(port : Int64) : Void
      godot_bind(@@mb_set_output_port_for_preview, "VisualShaderNode", "set_output_port_for_preview", 1286410249_i64)
      val_0 = port
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_output_port_for_preview, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_output_port_for_preview : Void* = Pointer(Void).null
    def get_output_port_for_preview() : Int64
      godot_bind(@@mb_get_output_port_for_preview, "VisualShaderNode", "get_output_port_for_preview", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_output_port_for_preview, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_input_port_default_value : Void* = Pointer(Void).null
    def set_input_port_default_value(port : Int64, value : Pointer(Void), prev_value : Pointer(Void)? = nil) : Void
      godot_bind(@@mb_set_input_port_default_value, "VisualShaderNode", "set_input_port_default_value", 150923387_i64)
      val_0 = port
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = value
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = prev_value
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_set_input_port_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_input_port_default_value : Void* = Pointer(Void).null
    def get_input_port_default_value(port : Int64) : Pointer(Void)
      godot_bind(@@mb_get_input_port_default_value, "VisualShaderNode", "get_input_port_default_value", 4227898402_i64)
      val_0 = port
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret_var = StaticArray(UInt8, 24).new(0_u8)
      godot_ptrcall(@@mb_get_input_port_default_value, @pointer, args.to_unsafe.as(Void**), ret_var.to_unsafe.as(Void*))
      ret_ptr = Pointer(Void).null
      Bridge.type_from_variant(24, pointerof(ret_ptr).as(Void*), ret_var.to_unsafe.as(Void*))
      ret_ptr
    end
    @@mb_remove_input_port_default_value : Void* = Pointer(Void).null
    def remove_input_port_default_value(port : Int64) : Void
      godot_bind(@@mb_remove_input_port_default_value, "VisualShaderNode", "remove_input_port_default_value", 1286410249_i64)
      val_0 = port
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_input_port_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_clear_default_input_values : Void* = Pointer(Void).null
    def clear_default_input_values() : Void
      godot_bind(@@mb_clear_default_input_values, "VisualShaderNode", "clear_default_input_values", 3218959716_i64)
      godot_ptrcall(@@mb_clear_default_input_values, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_set_default_input_values : Void* = Pointer(Void).null
    def set_default_input_values(values : Pointer(Void)) : Void
      godot_bind(@@mb_set_default_input_values, "VisualShaderNode", "set_default_input_values", 381264803_i64)
      val_0 = values
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_input_values, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_input_values : Void* = Pointer(Void).null
    def get_default_input_values() : Pointer(Void)
      godot_bind(@@mb_get_default_input_values, "VisualShaderNode", "get_default_input_values", 3995934104_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_default_input_values, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_set_frame : Void* = Pointer(Void).null
    def set_frame(frame : Int64) : Void
      godot_bind(@@mb_set_frame, "VisualShaderNode", "set_frame", 1286410249_i64)
      val_0 = frame
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_frame, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_frame : Void* = Pointer(Void).null
    def get_frame() : Int64
      godot_bind(@@mb_get_frame, "VisualShaderNode", "get_frame", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_frame, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `output_port_for_preview` getter
    def output_port_for_preview
      get_output_port_for_preview
    end
    # Property `output_port_for_preview` setter
    def output_port_for_preview=(val : Int)
      set_output_port_for_preview(val.to_i64)
    end
    # Property `default_input_values` getter
    def default_input_values
      get_default_input_values
    end
    # Property `default_input_values` setter
    def default_input_values=(val)
      set_default_input_values(val)
    end
    # Property `linked_parent_graph_frame` getter
    def linked_parent_graph_frame
      get_frame
    end
    # Property `linked_parent_graph_frame` setter
    def linked_parent_graph_frame=(val : Int)
      set_frame(val.to_i64)
    end
  end
  class VisualShaderNodeBillboard < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum BillboardType : Int64
      BillboardTypeDisabled = 0_i64
      BillboardTypeEnabled = 1_i64
      BillboardTypeFixedY = 2_i64
      BillboardTypeParticles = 3_i64
      BillboardTypeMax = 4_i64
    end
    @@mb_set_billboard_type : Void* = Pointer(Void).null
    def set_billboard_type(billboard_type : BillboardType | Int) : Void
      godot_bind(@@mb_set_billboard_type, "VisualShaderNodeBillboard", "set_billboard_type", 1227463289_i64)
      val_0 = billboard_type.is_a?(Int) ? billboard_type.to_i64 : billboard_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_billboard_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_billboard_type : Void* = Pointer(Void).null
    def get_billboard_type() : BillboardType
      godot_bind(@@mb_get_billboard_type, "VisualShaderNodeBillboard", "get_billboard_type", 3724188517_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_billboard_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(BillboardType, ret)
    end
    @@mb_set_keep_scale_enabled : Void* = Pointer(Void).null
    def set_keep_scale_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_keep_scale_enabled, "VisualShaderNodeBillboard", "set_keep_scale_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_keep_scale_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_keep_scale_enabled : Void* = Pointer(Void).null
    def is_keep_scale_enabled() : Bool
      godot_bind(@@mb_is_keep_scale_enabled, "VisualShaderNodeBillboard", "is_keep_scale_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_keep_scale_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `billboard_type` getter
    def billboard_type
      get_billboard_type
    end
    # Property `billboard_type` setter
    def billboard_type=(val : Int)
      set_billboard_type(val.to_i64)
    end
    # Property `keep_scale` getter
    def keep_scale
      is_keep_scale_enabled
    end
    def keep_scale?
      keep_scale
    end
    # Property `keep_scale` setter
    def keep_scale=(val)
      set_keep_scale_enabled(val)
    end
  end
  class VisualShaderNodeConstant < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeBooleanConstant < Godot::VisualShaderNodeConstant
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_constant : Void* = Pointer(Void).null
    def set_constant(constant : Bool) : Void
      godot_bind(@@mb_set_constant, "VisualShaderNodeBooleanConstant", "set_constant", 2586408642_i64)
      val_0 = constant
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_constant, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_constant : Void* = Pointer(Void).null
    def get_constant() : Bool
      godot_bind(@@mb_get_constant, "VisualShaderNodeBooleanConstant", "get_constant", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_get_constant, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `constant` getter
    def constant
      get_constant
    end
    def constant?
      constant
    end
    # Property `constant` setter
    def constant=(val)
      set_constant(val)
    end
  end
  class VisualShaderNodeParameter < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Qualifier : Int64
      QualNone = 0_i64
      QualGlobal = 1_i64
      QualInstance = 2_i64
      QualInstanceIndex = 3_i64
      QualMax = 4_i64
    end
    @@mb_set_parameter_name : Void* = Pointer(Void).null
    def set_parameter_name(name : String) : Void
      godot_bind(@@mb_set_parameter_name, "VisualShaderNodeParameter", "set_parameter_name", 83702148_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_parameter_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_parameter_name : Void* = Pointer(Void).null
    def get_parameter_name() : String
      godot_bind(@@mb_get_parameter_name, "VisualShaderNodeParameter", "get_parameter_name", 201670096_i64)
      godot_call_str("get_parameter_name")
    end
    @@mb_set_qualifier : Void* = Pointer(Void).null
    def set_qualifier(qualifier : Qualifier | Int) : Void
      godot_bind(@@mb_set_qualifier, "VisualShaderNodeParameter", "set_qualifier", 1276489447_i64)
      val_0 = qualifier.is_a?(Int) ? qualifier.to_i64 : qualifier.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_qualifier, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_qualifier : Void* = Pointer(Void).null
    def get_qualifier() : Qualifier
      godot_bind(@@mb_get_qualifier, "VisualShaderNodeParameter", "get_qualifier", 3558406205_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_qualifier, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Qualifier, ret)
    end
    @@mb_set_instance_index : Void* = Pointer(Void).null
    def set_instance_index(instance_index : Int64) : Void
      godot_bind(@@mb_set_instance_index, "VisualShaderNodeParameter", "set_instance_index", 1286410249_i64)
      val_0 = instance_index
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_instance_index, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_instance_index : Void* = Pointer(Void).null
    def get_instance_index() : Int64
      godot_bind(@@mb_get_instance_index, "VisualShaderNodeParameter", "get_instance_index", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_instance_index, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `parameter_name` getter
    def parameter_name
      get_parameter_name
    end
    # Property `parameter_name` setter
    def parameter_name=(val)
      set_parameter_name(val)
    end
    # Property `qualifier` getter
    def qualifier
      get_qualifier
    end
    # Property `qualifier` setter
    def qualifier=(val : Int)
      set_qualifier(val.to_i64)
    end
    # Property `instance_index` getter
    def instance_index
      get_instance_index
    end
    # Property `instance_index` setter
    def instance_index=(val : Int)
      set_instance_index(val.to_i64)
    end
  end
  class VisualShaderNodeBooleanParameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_default_value_enabled : Void* = Pointer(Void).null
    def set_default_value_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_default_value_enabled, "VisualShaderNodeBooleanParameter", "set_default_value_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_default_value_enabled : Void* = Pointer(Void).null
    def is_default_value_enabled() : Bool
      godot_bind(@@mb_is_default_value_enabled, "VisualShaderNodeBooleanParameter", "is_default_value_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_default_value_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_default_value : Void* = Pointer(Void).null
    def set_default_value(value : Bool) : Void
      godot_bind(@@mb_set_default_value, "VisualShaderNodeBooleanParameter", "set_default_value", 2586408642_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_value : Void* = Pointer(Void).null
    def get_default_value() : Bool
      godot_bind(@@mb_get_default_value, "VisualShaderNodeBooleanParameter", "get_default_value", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_get_default_value, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `default_value_enabled` getter
    def default_value_enabled
      is_default_value_enabled
    end
    def default_value_enabled?
      default_value_enabled
    end
    # Property `default_value_enabled` setter
    def default_value_enabled=(val)
      set_default_value_enabled(val)
    end
    # Property `default_value` getter
    def default_value
      get_default_value
    end
    def default_value?
      default_value
    end
    # Property `default_value` setter
    def default_value=(val)
      set_default_value(val)
    end
  end
  class VisualShaderNodeClamp < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeFloat = 0_i64
      OpTypeInt = 1_i64
      OpTypeUint = 2_i64
      OpTypeVector2d = 3_i64
      OpTypeVector3d = 4_i64
      OpTypeVector4d = 5_i64
      OpTypeMax = 6_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(op_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeClamp", "set_op_type", 405010749_i64)
      val_0 = op_type.is_a?(Int) ? op_type.to_i64 : op_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeClamp", "get_op_type", 233276050_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
  end
  class VisualShaderNodeColorConstant < Godot::VisualShaderNodeConstant
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_constant : Void* = Pointer(Void).null
    def set_constant(constant : Color) : Void
      godot_bind(@@mb_set_constant, "VisualShaderNodeColorConstant", "set_constant", 2920490490_i64)
      val_0 = constant
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_constant, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_constant : Void* = Pointer(Void).null
    def get_constant() : Color
      godot_bind(@@mb_get_constant, "VisualShaderNodeColorConstant", "get_constant", 3444240500_i64)
      ret = Color.new
      godot_ptrcall(@@mb_get_constant, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `constant` getter
    def constant
      get_constant
    end
    # Property `constant` setter
    def constant=(val)
      set_constant(val)
    end
  end
  class VisualShaderNodeColorFunc < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Function : Int64
      FuncGrayscale = 0_i64
      FuncHsv2rgb = 1_i64
      FuncRgb2hsv = 2_i64
      FuncSepia = 3_i64
      FuncLinearToSrgb = 4_i64
      FuncSrgbToLinear = 5_i64
      FuncMax = 6_i64
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeColorFunc", "set_function", 3973396138_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeColorFunc", "get_function", 554863321_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
  end
  class VisualShaderNodeColorOp < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Operator : Int64
      OpScreen = 0_i64
      OpDifference = 1_i64
      OpDarken = 2_i64
      OpLighten = 3_i64
      OpOverlay = 4_i64
      OpDodge = 5_i64
      OpBurn = 6_i64
      OpSoftLight = 7_i64
      OpHardLight = 8_i64
      OpMax = 9_i64
    end
    @@mb_set_operator : Void* = Pointer(Void).null
    def set_operator(op : Operator | Int) : Void
      godot_bind(@@mb_set_operator, "VisualShaderNodeColorOp", "set_operator", 4260370673_i64)
      val_0 = op.is_a?(Int) ? op.to_i64 : op.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_operator, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_operator : Void* = Pointer(Void).null
    def get_operator() : Operator
      godot_bind(@@mb_get_operator, "VisualShaderNodeColorOp", "get_operator", 1950956529_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_operator, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Operator, ret)
    end
    # Property `operator` getter
    def operator
      get_operator
    end
    # Property `operator` setter
    def operator=(val : Int)
      set_operator(val.to_i64)
    end
  end
  class VisualShaderNodeColorParameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_default_value_enabled : Void* = Pointer(Void).null
    def set_default_value_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_default_value_enabled, "VisualShaderNodeColorParameter", "set_default_value_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_default_value_enabled : Void* = Pointer(Void).null
    def is_default_value_enabled() : Bool
      godot_bind(@@mb_is_default_value_enabled, "VisualShaderNodeColorParameter", "is_default_value_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_default_value_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_default_value : Void* = Pointer(Void).null
    def set_default_value(value : Color) : Void
      godot_bind(@@mb_set_default_value, "VisualShaderNodeColorParameter", "set_default_value", 2920490490_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_value : Void* = Pointer(Void).null
    def get_default_value() : Color
      godot_bind(@@mb_get_default_value, "VisualShaderNodeColorParameter", "get_default_value", 3444240500_i64)
      ret = Color.new
      godot_ptrcall(@@mb_get_default_value, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `default_value_enabled` getter
    def default_value_enabled
      is_default_value_enabled
    end
    def default_value_enabled?
      default_value_enabled
    end
    # Property `default_value_enabled` setter
    def default_value_enabled=(val)
      set_default_value_enabled(val)
    end
    # Property `default_value` getter
    def default_value
      get_default_value
    end
    # Property `default_value` setter
    def default_value=(val)
      set_default_value(val)
    end
  end
  class VisualShaderNodeResizableBase < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_size : Void* = Pointer(Void).null
    def set_size(size : Vector2) : Void
      godot_bind(@@mb_set_size, "VisualShaderNodeResizableBase", "set_size", 743155724_i64)
      val_0 = size
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_size, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_size : Void* = Pointer(Void).null
    def get_size() : Vector2
      godot_bind(@@mb_get_size, "VisualShaderNodeResizableBase", "get_size", 3341600327_i64)
      ret = Vector2.new
      godot_ptrcall(@@mb_get_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `size` getter
    def size
      get_size
    end
    # Property `size` setter
    def size=(val)
      set_size(val)
    end
  end
  class VisualShaderNodeFrame < Godot::VisualShaderNodeResizableBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_title : Void* = Pointer(Void).null
    def set_title(title : String) : Void
      godot_bind(@@mb_set_title, "VisualShaderNodeFrame", "set_title", 83702148_i64)
      str_0 = Bridge.make_string(title)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_title, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_title : Void* = Pointer(Void).null
    def get_title() : String
      godot_bind(@@mb_get_title, "VisualShaderNodeFrame", "get_title", 201670096_i64)
      godot_call_str("get_title")
    end
    @@mb_set_tint_color_enabled : Void* = Pointer(Void).null
    def set_tint_color_enabled(enable : Bool) : Void
      godot_bind(@@mb_set_tint_color_enabled, "VisualShaderNodeFrame", "set_tint_color_enabled", 2586408642_i64)
      val_0 = enable
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_tint_color_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_tint_color_enabled : Void* = Pointer(Void).null
    def is_tint_color_enabled() : Bool
      godot_bind(@@mb_is_tint_color_enabled, "VisualShaderNodeFrame", "is_tint_color_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_tint_color_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_tint_color : Void* = Pointer(Void).null
    def set_tint_color(color : Color) : Void
      godot_bind(@@mb_set_tint_color, "VisualShaderNodeFrame", "set_tint_color", 2920490490_i64)
      val_0 = color
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_tint_color, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_tint_color : Void* = Pointer(Void).null
    def get_tint_color() : Color
      godot_bind(@@mb_get_tint_color, "VisualShaderNodeFrame", "get_tint_color", 3444240500_i64)
      ret = Color.new
      godot_ptrcall(@@mb_get_tint_color, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_autoshrink_enabled : Void* = Pointer(Void).null
    def set_autoshrink_enabled(enable : Bool) : Void
      godot_bind(@@mb_set_autoshrink_enabled, "VisualShaderNodeFrame", "set_autoshrink_enabled", 2586408642_i64)
      val_0 = enable
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_autoshrink_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_autoshrink_enabled : Void* = Pointer(Void).null
    def is_autoshrink_enabled() : Bool
      godot_bind(@@mb_is_autoshrink_enabled, "VisualShaderNodeFrame", "is_autoshrink_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_autoshrink_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_add_attached_node : Void* = Pointer(Void).null
    def add_attached_node(node : Int64) : Void
      godot_bind(@@mb_add_attached_node, "VisualShaderNodeFrame", "add_attached_node", 1286410249_i64)
      val_0 = node
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_add_attached_node, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_remove_attached_node : Void* = Pointer(Void).null
    def remove_attached_node(node : Int64) : Void
      godot_bind(@@mb_remove_attached_node, "VisualShaderNodeFrame", "remove_attached_node", 1286410249_i64)
      val_0 = node
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_attached_node, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_set_attached_nodes : Void* = Pointer(Void).null
    def set_attached_nodes(attached_nodes : Pointer(Void)) : Void
      godot_bind(@@mb_set_attached_nodes, "VisualShaderNodeFrame", "set_attached_nodes", 3614634198_i64)
      val_0 = attached_nodes
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_attached_nodes, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_attached_nodes : Void* = Pointer(Void).null
    def get_attached_nodes() : Pointer(Void)
      godot_bind(@@mb_get_attached_nodes, "VisualShaderNodeFrame", "get_attached_nodes", 1930428628_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_attached_nodes, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    # Property `title` getter
    def title
      get_title
    end
    # Property `title` setter
    def title=(val)
      set_title(val)
    end
    # Property `tint_color_enabled` getter
    def tint_color_enabled
      is_tint_color_enabled
    end
    def tint_color_enabled?
      tint_color_enabled
    end
    # Property `tint_color_enabled` setter
    def tint_color_enabled=(val)
      set_tint_color_enabled(val)
    end
    # Property `tint_color` getter
    def tint_color
      get_tint_color
    end
    # Property `tint_color` setter
    def tint_color=(val)
      set_tint_color(val)
    end
    # Property `autoshrink` getter
    def autoshrink
      is_autoshrink_enabled
    end
    def autoshrink?
      autoshrink
    end
    # Property `autoshrink` setter
    def autoshrink=(val)
      set_autoshrink_enabled(val)
    end
    # Property `attached_nodes` getter
    def attached_nodes
      get_attached_nodes
    end
    # Property `attached_nodes` setter
    def attached_nodes=(val)
      set_attached_nodes(val)
    end
  end
  class VisualShaderNodeComment < Godot::VisualShaderNodeFrame
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_description : Void* = Pointer(Void).null
    def set_description(description : String) : Void
      godot_bind(@@mb_set_description, "VisualShaderNodeComment", "set_description", 83702148_i64)
      str_0 = Bridge.make_string(description)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_description, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_description : Void* = Pointer(Void).null
    def get_description() : String
      godot_bind(@@mb_get_description, "VisualShaderNodeComment", "get_description", 201670096_i64)
      godot_call_str("get_description")
    end
    # Property `description` getter
    def description
      get_description
    end
    # Property `description` setter
    def description=(val)
      set_description(val)
    end
  end
  class VisualShaderNodeCompare < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum ComparisonType : Int64
      CtypeScalar = 0_i64
      CtypeScalarInt = 1_i64
      CtypeScalarUint = 2_i64
      CtypeVector2d = 3_i64
      CtypeVector3d = 4_i64
      CtypeVector4d = 5_i64
      CtypeBoolean = 6_i64
      CtypeTransform = 7_i64
      CtypeMax = 8_i64
    end
    enum Function : Int64
      FuncEqual = 0_i64
      FuncNotEqual = 1_i64
      FuncGreaterThan = 2_i64
      FuncGreaterThanEqual = 3_i64
      FuncLessThan = 4_i64
      FuncLessThanEqual = 5_i64
      FuncMax = 6_i64
    end
    enum Condition : Int64
      CondAll = 0_i64
      CondAny = 1_i64
      CondMax = 2_i64
    end
    @@mb_set_comparison_type : Void* = Pointer(Void).null
    def set_comparison_type(get_type : ComparisonType | Int) : Void
      godot_bind(@@mb_set_comparison_type, "VisualShaderNodeCompare", "set_comparison_type", 516558320_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_comparison_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_comparison_type : Void* = Pointer(Void).null
    def get_comparison_type() : ComparisonType
      godot_bind(@@mb_get_comparison_type, "VisualShaderNodeCompare", "get_comparison_type", 3495315961_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_comparison_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(ComparisonType, ret)
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeCompare", "set_function", 2370951349_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeCompare", "get_function", 4089164265_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    @@mb_set_condition : Void* = Pointer(Void).null
    def set_condition(condition : Condition | Int) : Void
      godot_bind(@@mb_set_condition, "VisualShaderNodeCompare", "set_condition", 918742392_i64)
      val_0 = condition.is_a?(Int) ? condition.to_i64 : condition.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_condition, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_condition : Void* = Pointer(Void).null
    def get_condition() : Condition
      godot_bind(@@mb_get_condition, "VisualShaderNodeCompare", "get_condition", 3281078941_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_condition, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Condition, ret)
    end
    # Property `type` getter
    def get_type
      get_comparison_type
    end
    # Property `type` setter
    def get_type=(val : Int)
      set_comparison_type(val.to_i64)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
    # Property `condition` getter
    def condition
      get_condition
    end
    # Property `condition` setter
    def condition=(val : Int)
      set_condition(val.to_i64)
    end
  end
  class VisualShaderNodeCubemap < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Source : Int64
      SourceTexture = 0_i64
      SourcePort = 1_i64
      SourceMax = 2_i64
    end
    enum TextureType : Int64
      TypeData = 0_i64
      TypeColor = 1_i64
      TypeNormalMap = 2_i64
      TypeMax = 3_i64
    end
    @@mb_set_source : Void* = Pointer(Void).null
    def set_source(value : Source | Int) : Void
      godot_bind(@@mb_set_source, "VisualShaderNodeCubemap", "set_source", 1625400621_i64)
      val_0 = value.is_a?(Int) ? value.to_i64 : value.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_source, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_source : Void* = Pointer(Void).null
    def get_source() : Source
      godot_bind(@@mb_get_source, "VisualShaderNodeCubemap", "get_source", 2222048781_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_source, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Source, ret)
    end
    @@mb_set_cube_map : Void* = Pointer(Void).null
    def set_cube_map(value : TextureLayered) : Void
      godot_bind(@@mb_set_cube_map, "VisualShaderNodeCubemap", "set_cube_map", 1278366092_i64)
      arg_ptr_0 = value ? value.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_cube_map, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_cube_map : Void* = Pointer(Void).null
    def get_cube_map() : TextureLayered
      godot_bind(@@mb_get_cube_map, "VisualShaderNodeCubemap", "get_cube_map", 3984243839_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_cube_map, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(TextureLayered, ret_ptr)
    end
    @@mb_set_texture_type : Void* = Pointer(Void).null
    def set_texture_type(value : TextureType | Int) : Void
      godot_bind(@@mb_set_texture_type, "VisualShaderNodeCubemap", "set_texture_type", 1899718876_i64)
      val_0 = value.is_a?(Int) ? value.to_i64 : value.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture_type : Void* = Pointer(Void).null
    def get_texture_type() : TextureType
      godot_bind(@@mb_get_texture_type, "VisualShaderNodeCubemap", "get_texture_type", 3356498888_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_texture_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(TextureType, ret)
    end
    # Property `source` getter
    def source
      get_source
    end
    # Property `source` setter
    def source=(val : Int)
      set_source(val.to_i64)
    end
    # Property `cube_map` getter
    def cube_map
      get_cube_map
    end
    # Property `cube_map` setter
    def cube_map=(val)
      set_cube_map(val)
    end
    # Property `texture_type` getter
    def texture_type
      get_texture_type
    end
    # Property `texture_type` setter
    def texture_type=(val : Int)
      set_texture_type(val.to_i64)
    end
  end
  class VisualShaderNodeTextureParameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum TextureType : Int64
      TypeData = 0_i64
      TypeColor = 1_i64
      TypeNormalMap = 2_i64
      TypeAnisotropy = 3_i64
      TypeMax = 4_i64
    end
    enum ColorDefault : Int64
      ColorDefaultWhite = 0_i64
      ColorDefaultBlack = 1_i64
      ColorDefaultTransparent = 2_i64
      ColorDefaultMax = 3_i64
    end
    enum TextureFilter : Int64
      FilterDefault = 0_i64
      FilterNearest = 1_i64
      FilterLinear = 2_i64
      FilterNearestMipmap = 3_i64
      FilterLinearMipmap = 4_i64
      FilterNearestMipmapAnisotropic = 5_i64
      FilterLinearMipmapAnisotropic = 6_i64
      FilterMax = 7_i64
    end
    enum TextureRepeat : Int64
      RepeatDefault = 0_i64
      RepeatEnabled = 1_i64
      RepeatDisabled = 2_i64
      RepeatMax = 3_i64
    end
    enum TextureSource : Int64
      SourceNone = 0_i64
      SourceScreen = 1_i64
      SourceDepth = 2_i64
      SourceNormalRoughness = 3_i64
      SourceMax = 4_i64
    end
    @@mb_set_texture_type : Void* = Pointer(Void).null
    def set_texture_type(get_type : TextureType | Int) : Void
      godot_bind(@@mb_set_texture_type, "VisualShaderNodeTextureParameter", "set_texture_type", 2227296876_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture_type : Void* = Pointer(Void).null
    def get_texture_type() : TextureType
      godot_bind(@@mb_get_texture_type, "VisualShaderNodeTextureParameter", "get_texture_type", 367922070_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_texture_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(TextureType, ret)
    end
    @@mb_set_color_default : Void* = Pointer(Void).null
    def set_color_default(color : ColorDefault | Int) : Void
      godot_bind(@@mb_set_color_default, "VisualShaderNodeTextureParameter", "set_color_default", 4217624432_i64)
      val_0 = color.is_a?(Int) ? color.to_i64 : color.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_color_default, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_color_default : Void* = Pointer(Void).null
    def get_color_default() : ColorDefault
      godot_bind(@@mb_get_color_default, "VisualShaderNodeTextureParameter", "get_color_default", 3837060134_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_color_default, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(ColorDefault, ret)
    end
    @@mb_set_texture_filter : Void* = Pointer(Void).null
    def set_texture_filter(filter : TextureFilter | Int) : Void
      godot_bind(@@mb_set_texture_filter, "VisualShaderNodeTextureParameter", "set_texture_filter", 2147684752_i64)
      val_0 = filter.is_a?(Int) ? filter.to_i64 : filter.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture_filter, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture_filter : Void* = Pointer(Void).null
    def get_texture_filter() : TextureFilter
      godot_bind(@@mb_get_texture_filter, "VisualShaderNodeTextureParameter", "get_texture_filter", 4184490817_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_texture_filter, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(TextureFilter, ret)
    end
    @@mb_set_texture_repeat : Void* = Pointer(Void).null
    def set_texture_repeat(repeat : TextureRepeat | Int) : Void
      godot_bind(@@mb_set_texture_repeat, "VisualShaderNodeTextureParameter", "set_texture_repeat", 2036143070_i64)
      val_0 = repeat.is_a?(Int) ? repeat.to_i64 : repeat.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture_repeat, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture_repeat : Void* = Pointer(Void).null
    def get_texture_repeat() : TextureRepeat
      godot_bind(@@mb_get_texture_repeat, "VisualShaderNodeTextureParameter", "get_texture_repeat", 1690132794_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_texture_repeat, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(TextureRepeat, ret)
    end
    @@mb_set_texture_source : Void* = Pointer(Void).null
    def set_texture_source(source : TextureSource | Int) : Void
      godot_bind(@@mb_set_texture_source, "VisualShaderNodeTextureParameter", "set_texture_source", 1212687372_i64)
      val_0 = source.is_a?(Int) ? source.to_i64 : source.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture_source, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture_source : Void* = Pointer(Void).null
    def get_texture_source() : TextureSource
      godot_bind(@@mb_get_texture_source, "VisualShaderNodeTextureParameter", "get_texture_source", 2039092262_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_texture_source, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(TextureSource, ret)
    end
    # Property `texture_type` getter
    def texture_type
      get_texture_type
    end
    # Property `texture_type` setter
    def texture_type=(val : Int)
      set_texture_type(val.to_i64)
    end
    # Property `color_default` getter
    def color_default
      get_color_default
    end
    # Property `color_default` setter
    def color_default=(val : Int)
      set_color_default(val.to_i64)
    end
    # Property `texture_filter` getter
    def texture_filter
      get_texture_filter
    end
    # Property `texture_filter` setter
    def texture_filter=(val : Int)
      set_texture_filter(val.to_i64)
    end
    # Property `texture_repeat` getter
    def texture_repeat
      get_texture_repeat
    end
    # Property `texture_repeat` setter
    def texture_repeat=(val : Int)
      set_texture_repeat(val.to_i64)
    end
    # Property `texture_source` getter
    def texture_source
      get_texture_source
    end
    # Property `texture_source` setter
    def texture_source=(val : Int)
      set_texture_source(val.to_i64)
    end
  end
  class VisualShaderNodeCubemapParameter < Godot::VisualShaderNodeTextureParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeCurveTexture < Godot::VisualShaderNodeResizableBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_texture : Void* = Pointer(Void).null
    def set_texture(texture : CurveTexture) : Void
      godot_bind(@@mb_set_texture, "VisualShaderNodeCurveTexture", "set_texture", 181872837_i64)
      arg_ptr_0 = texture ? texture.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture : Void* = Pointer(Void).null
    def get_texture() : CurveTexture
      godot_bind(@@mb_get_texture, "VisualShaderNodeCurveTexture", "get_texture", 2800800579_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_texture, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(CurveTexture, ret_ptr)
    end
    # Property `texture` getter
    def texture
      get_texture
    end
    # Property `texture` setter
    def texture=(val)
      set_texture(val)
    end
  end
  class VisualShaderNodeCurveXYZTexture < Godot::VisualShaderNodeResizableBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_texture : Void* = Pointer(Void).null
    def set_texture(texture : CurveXYZTexture) : Void
      godot_bind(@@mb_set_texture, "VisualShaderNodeCurveXYZTexture", "set_texture", 8031783_i64)
      arg_ptr_0 = texture ? texture.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture : Void* = Pointer(Void).null
    def get_texture() : CurveXYZTexture
      godot_bind(@@mb_get_texture, "VisualShaderNodeCurveXYZTexture", "get_texture", 1950275015_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_texture, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(CurveXYZTexture, ret_ptr)
    end
    # Property `texture` getter
    def texture
      get_texture
    end
    # Property `texture` setter
    def texture=(val)
      set_texture(val)
    end
  end
  class VisualShaderNodeCustom < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_get_option_index : Void* = Pointer(Void).null
    def get_option_index(option : Int64) : Int64
      godot_bind(@@mb_get_option_index, "VisualShaderNodeCustom", "get_option_index", 923996154_i64)
      val_0 = option
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_option_index, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    # Property `initialized` getter
    def initialized
      _is_initialized
    end
    def initialized?
      initialized
    end
    # Property `properties` getter
    def properties
      get_properties
    end
  end
  class VisualShaderNodeDerivativeFunc < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeScalar = 0_i64
      OpTypeVector2d = 1_i64
      OpTypeVector3d = 2_i64
      OpTypeVector4d = 3_i64
      OpTypeMax = 4_i64
    end
    enum Function : Int64
      FuncSum = 0_i64
      FuncX = 1_i64
      FuncY = 2_i64
      FuncMax = 3_i64
    end
    enum Precision : Int64
      PrecisionNone = 0_i64
      PrecisionCoarse = 1_i64
      PrecisionFine = 2_i64
      PrecisionMax = 3_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(get_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeDerivativeFunc", "set_op_type", 377800221_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeDerivativeFunc", "get_op_type", 3997800514_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeDerivativeFunc", "set_function", 1944704156_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeDerivativeFunc", "get_function", 2389093396_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    @@mb_set_precision : Void* = Pointer(Void).null
    def set_precision(precision : Precision | Int) : Void
      godot_bind(@@mb_set_precision, "VisualShaderNodeDerivativeFunc", "set_precision", 797270566_i64)
      val_0 = precision.is_a?(Int) ? precision.to_i64 : precision.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_precision, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_precision : Void* = Pointer(Void).null
    def get_precision() : Precision
      godot_bind(@@mb_get_precision, "VisualShaderNodeDerivativeFunc", "get_precision", 3822547323_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_precision, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Precision, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
    # Property `precision` getter
    def precision
      get_precision
    end
    # Property `precision` setter
    def precision=(val : Int)
      set_precision(val.to_i64)
    end
  end
  class VisualShaderNodeDeterminant < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeDistanceFade < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeDotProduct < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeGroupBase < Godot::VisualShaderNodeResizableBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_inputs : Void* = Pointer(Void).null
    def set_inputs(inputs : String) : Void
      godot_bind(@@mb_set_inputs, "VisualShaderNodeGroupBase", "set_inputs", 83702148_i64)
      str_0 = Bridge.make_string(inputs)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_inputs, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_inputs : Void* = Pointer(Void).null
    def get_inputs() : String
      godot_bind(@@mb_get_inputs, "VisualShaderNodeGroupBase", "get_inputs", 201670096_i64)
      godot_call_str("get_inputs")
    end
    @@mb_set_outputs : Void* = Pointer(Void).null
    def set_outputs(outputs : String) : Void
      godot_bind(@@mb_set_outputs, "VisualShaderNodeGroupBase", "set_outputs", 83702148_i64)
      str_0 = Bridge.make_string(outputs)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_outputs, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_outputs : Void* = Pointer(Void).null
    def get_outputs() : String
      godot_bind(@@mb_get_outputs, "VisualShaderNodeGroupBase", "get_outputs", 201670096_i64)
      godot_call_str("get_outputs")
    end
    @@mb_is_valid_port_name : Void* = Pointer(Void).null
    def is_valid_port_name(name : String) : Bool
      godot_bind(@@mb_is_valid_port_name, "VisualShaderNodeGroupBase", "is_valid_port_name", 3927539163_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_is_valid_port_name, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_add_input_port : Void* = Pointer(Void).null
    def add_input_port(id : Int64, get_type : Int64, name : String) : Void
      godot_bind(@@mb_add_input_port, "VisualShaderNodeGroupBase", "add_input_port", 2285447957_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = get_type
      arg_1 = pointerof(val_1).as(Void*)
      str_2 = Bridge.make_string(name)
      arg_2 = str_2
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_add_input_port, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_2)
    end
    @@mb_remove_input_port : Void* = Pointer(Void).null
    def remove_input_port(id : Int64) : Void
      godot_bind(@@mb_remove_input_port, "VisualShaderNodeGroupBase", "remove_input_port", 1286410249_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_input_port, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_input_port_count : Void* = Pointer(Void).null
    def get_input_port_count() : Int64
      godot_bind(@@mb_get_input_port_count, "VisualShaderNodeGroupBase", "get_input_port_count", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_input_port_count, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_has_input_port : Void* = Pointer(Void).null
    def has_input_port(id : Int64) : Bool
      godot_bind(@@mb_has_input_port, "VisualShaderNodeGroupBase", "has_input_port", 1116898809_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_has_input_port, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_clear_input_ports : Void* = Pointer(Void).null
    def clear_input_ports() : Void
      godot_bind(@@mb_clear_input_ports, "VisualShaderNodeGroupBase", "clear_input_ports", 3218959716_i64)
      godot_ptrcall(@@mb_clear_input_ports, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_add_output_port : Void* = Pointer(Void).null
    def add_output_port(id : Int64, get_type : Int64, name : String) : Void
      godot_bind(@@mb_add_output_port, "VisualShaderNodeGroupBase", "add_output_port", 2285447957_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = get_type
      arg_1 = pointerof(val_1).as(Void*)
      str_2 = Bridge.make_string(name)
      arg_2 = str_2
      args = [arg_0, arg_1, arg_2]
      godot_ptrcall(@@mb_add_output_port, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_2)
    end
    @@mb_remove_output_port : Void* = Pointer(Void).null
    def remove_output_port(id : Int64) : Void
      godot_bind(@@mb_remove_output_port, "VisualShaderNodeGroupBase", "remove_output_port", 1286410249_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_output_port, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_output_port_count : Void* = Pointer(Void).null
    def get_output_port_count() : Int64
      godot_bind(@@mb_get_output_port_count, "VisualShaderNodeGroupBase", "get_output_port_count", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_output_port_count, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_has_output_port : Void* = Pointer(Void).null
    def has_output_port(id : Int64) : Bool
      godot_bind(@@mb_has_output_port, "VisualShaderNodeGroupBase", "has_output_port", 1116898809_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_has_output_port, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_clear_output_ports : Void* = Pointer(Void).null
    def clear_output_ports() : Void
      godot_bind(@@mb_clear_output_ports, "VisualShaderNodeGroupBase", "clear_output_ports", 3218959716_i64)
      godot_ptrcall(@@mb_clear_output_ports, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_set_input_port_name : Void* = Pointer(Void).null
    def set_input_port_name(id : Int64, name : String) : Void
      godot_bind(@@mb_set_input_port_name, "VisualShaderNodeGroupBase", "set_input_port_name", 501894301_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      str_1 = Bridge.make_string(name)
      arg_1 = str_1
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_input_port_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_1)
    end
    @@mb_set_input_port_type : Void* = Pointer(Void).null
    def set_input_port_type(id : Int64, get_type : Int64) : Void
      godot_bind(@@mb_set_input_port_type, "VisualShaderNodeGroupBase", "set_input_port_type", 3937882851_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = get_type
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_input_port_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_set_output_port_name : Void* = Pointer(Void).null
    def set_output_port_name(id : Int64, name : String) : Void
      godot_bind(@@mb_set_output_port_name, "VisualShaderNodeGroupBase", "set_output_port_name", 501894301_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      str_1 = Bridge.make_string(name)
      arg_1 = str_1
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_output_port_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_1)
    end
    @@mb_set_output_port_type : Void* = Pointer(Void).null
    def set_output_port_type(id : Int64, get_type : Int64) : Void
      godot_bind(@@mb_set_output_port_type, "VisualShaderNodeGroupBase", "set_output_port_type", 3937882851_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = get_type
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_output_port_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_free_input_port_id : Void* = Pointer(Void).null
    def get_free_input_port_id() : Int64
      godot_bind(@@mb_get_free_input_port_id, "VisualShaderNodeGroupBase", "get_free_input_port_id", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_free_input_port_id, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_free_output_port_id : Void* = Pointer(Void).null
    def get_free_output_port_id() : Int64
      godot_bind(@@mb_get_free_output_port_id, "VisualShaderNodeGroupBase", "get_free_output_port_id", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_free_output_port_id, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
  end
  class VisualShaderNodeExpression < Godot::VisualShaderNodeGroupBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_expression : Void* = Pointer(Void).null
    def set_expression(expression : String) : Void
      godot_bind(@@mb_set_expression, "VisualShaderNodeExpression", "set_expression", 83702148_i64)
      str_0 = Bridge.make_string(expression)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_expression, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_expression : Void* = Pointer(Void).null
    def get_expression() : String
      godot_bind(@@mb_get_expression, "VisualShaderNodeExpression", "get_expression", 201670096_i64)
      godot_call_str("get_expression")
    end
    # Property `expression` getter
    def expression
      get_expression
    end
    # Property `expression` setter
    def expression=(val)
      set_expression(val)
    end
  end
  class VisualShaderNodeVectorBase < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeVector2d = 0_i64
      OpTypeVector3d = 1_i64
      OpTypeVector4d = 2_i64
      OpTypeMax = 3_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(get_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeVectorBase", "set_op_type", 1692596998_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeVectorBase", "get_op_type", 2568738462_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
  end
  class VisualShaderNodeFaceForward < Godot::VisualShaderNodeVectorBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeFloatConstant < Godot::VisualShaderNodeConstant
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_constant : Void* = Pointer(Void).null
    def set_constant(constant : Float64) : Void
      godot_bind(@@mb_set_constant, "VisualShaderNodeFloatConstant", "set_constant", 373806689_i64)
      val_0 = constant
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_constant, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_constant : Void* = Pointer(Void).null
    def get_constant() : Float64
      godot_bind(@@mb_get_constant, "VisualShaderNodeFloatConstant", "get_constant", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_constant, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `constant` getter
    def constant
      get_constant
    end
    # Property `constant` setter
    def constant=(val : Number)
      set_constant(val.to_f64)
    end
  end
  class VisualShaderNodeFloatFunc < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Function : Int64
      FuncSin = 0_i64
      FuncCos = 1_i64
      FuncTan = 2_i64
      FuncAsin = 3_i64
      FuncAcos = 4_i64
      FuncAtan = 5_i64
      FuncSinh = 6_i64
      FuncCosh = 7_i64
      FuncTanh = 8_i64
      FuncLog = 9_i64
      FuncExp = 10_i64
      FuncSqrt = 11_i64
      FuncAbs = 12_i64
      FuncSign = 13_i64
      FuncFloor = 14_i64
      FuncRound = 15_i64
      FuncCeil = 16_i64
      FuncFract = 17_i64
      FuncSaturate = 18_i64
      FuncNegate = 19_i64
      FuncAcosh = 20_i64
      FuncAsinh = 21_i64
      FuncAtanh = 22_i64
      FuncDegrees = 23_i64
      FuncExp2 = 24_i64
      FuncInverseSqrt = 25_i64
      FuncLog2 = 26_i64
      FuncRadians = 27_i64
      FuncReciprocal = 28_i64
      FuncRoundeven = 29_i64
      FuncTrunc = 30_i64
      FuncOneminus = 31_i64
      FuncMax = 32_i64
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeFloatFunc", "set_function", 536026177_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeFloatFunc", "get_function", 2033948868_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
  end
  class VisualShaderNodeFloatOp < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Operator : Int64
      OpAdd = 0_i64
      OpSub = 1_i64
      OpMul = 2_i64
      OpDiv = 3_i64
      OpMod = 4_i64
      OpPow = 5_i64
      OpMax = 6_i64
      OpMin = 7_i64
      OpAtan2 = 8_i64
      OpStep = 9_i64
      OpEnumSize = 10_i64
    end
    @@mb_set_operator : Void* = Pointer(Void).null
    def set_operator(op : Operator | Int) : Void
      godot_bind(@@mb_set_operator, "VisualShaderNodeFloatOp", "set_operator", 2488468047_i64)
      val_0 = op.is_a?(Int) ? op.to_i64 : op.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_operator, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_operator : Void* = Pointer(Void).null
    def get_operator() : Operator
      godot_bind(@@mb_get_operator, "VisualShaderNodeFloatOp", "get_operator", 1867979390_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_operator, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Operator, ret)
    end
    # Property `operator` getter
    def operator
      get_operator
    end
    # Property `operator` setter
    def operator=(val : Int)
      set_operator(val.to_i64)
    end
  end
  class VisualShaderNodeFloatParameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Hint : Int64
      HintNone = 0_i64
      HintRange = 1_i64
      HintRangeStep = 2_i64
      HintMax = 3_i64
    end
    @@mb_set_hint : Void* = Pointer(Void).null
    def set_hint(hint : Hint | Int) : Void
      godot_bind(@@mb_set_hint, "VisualShaderNodeFloatParameter", "set_hint", 3712586466_i64)
      val_0 = hint.is_a?(Int) ? hint.to_i64 : hint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_hint, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_hint : Void* = Pointer(Void).null
    def get_hint() : Hint
      godot_bind(@@mb_get_hint, "VisualShaderNodeFloatParameter", "get_hint", 3042240429_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_hint, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Hint, ret)
    end
    @@mb_set_min : Void* = Pointer(Void).null
    def set_min(value : Float64) : Void
      godot_bind(@@mb_set_min, "VisualShaderNodeFloatParameter", "set_min", 373806689_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_min, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_min : Void* = Pointer(Void).null
    def get_min() : Float64
      godot_bind(@@mb_get_min, "VisualShaderNodeFloatParameter", "get_min", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_min, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_max : Void* = Pointer(Void).null
    def set_max(value : Float64) : Void
      godot_bind(@@mb_set_max, "VisualShaderNodeFloatParameter", "set_max", 373806689_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_max, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_max : Void* = Pointer(Void).null
    def get_max() : Float64
      godot_bind(@@mb_get_max, "VisualShaderNodeFloatParameter", "get_max", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_max, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_step : Void* = Pointer(Void).null
    def set_step(value : Float64) : Void
      godot_bind(@@mb_set_step, "VisualShaderNodeFloatParameter", "set_step", 373806689_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_step, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_step : Void* = Pointer(Void).null
    def get_step() : Float64
      godot_bind(@@mb_get_step, "VisualShaderNodeFloatParameter", "get_step", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_step, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_default_value_enabled : Void* = Pointer(Void).null
    def set_default_value_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_default_value_enabled, "VisualShaderNodeFloatParameter", "set_default_value_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_default_value_enabled : Void* = Pointer(Void).null
    def is_default_value_enabled() : Bool
      godot_bind(@@mb_is_default_value_enabled, "VisualShaderNodeFloatParameter", "is_default_value_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_default_value_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_default_value : Void* = Pointer(Void).null
    def set_default_value(value : Float64) : Void
      godot_bind(@@mb_set_default_value, "VisualShaderNodeFloatParameter", "set_default_value", 373806689_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_value : Void* = Pointer(Void).null
    def get_default_value() : Float64
      godot_bind(@@mb_get_default_value, "VisualShaderNodeFloatParameter", "get_default_value", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_default_value, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `hint` getter
    def hint
      get_hint
    end
    # Property `hint` setter
    def hint=(val : Int)
      set_hint(val.to_i64)
    end
    # Property `min` getter
    def min
      get_min
    end
    # Property `min` setter
    def min=(val : Number)
      set_min(val.to_f64)
    end
    # Property `max` getter
    def max
      get_max
    end
    # Property `max` setter
    def max=(val : Number)
      set_max(val.to_f64)
    end
    # Property `step` getter
    def step
      get_step
    end
    # Property `step` setter
    def step=(val : Number)
      set_step(val.to_f64)
    end
    # Property `default_value_enabled` getter
    def default_value_enabled
      is_default_value_enabled
    end
    def default_value_enabled?
      default_value_enabled
    end
    # Property `default_value_enabled` setter
    def default_value_enabled=(val)
      set_default_value_enabled(val)
    end
    # Property `default_value` getter
    def default_value
      get_default_value
    end
    # Property `default_value` setter
    def default_value=(val : Number)
      set_default_value(val.to_f64)
    end
  end
  class VisualShaderNodeFresnel < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeGlobalExpression < Godot::VisualShaderNodeExpression
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeGroup < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_group : Void* = Pointer(Void).null
    def set_group(group : VisualShaderGroup) : Void
      godot_bind(@@mb_set_group, "VisualShaderNodeGroup", "set_group", 3093265740_i64)
      arg_ptr_0 = group ? group.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_group, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_group : Void* = Pointer(Void).null
    def get_group() : VisualShaderGroup
      godot_bind(@@mb_get_group, "VisualShaderNodeGroup", "get_group", 1230504110_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_group, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(VisualShaderGroup, ret_ptr)
    end
    # Property `group` getter
    def group
      get_group
    end
    # Property `group` setter
    def group=(val)
      set_group(val)
    end
  end
  class VisualShaderNodeGroupInput < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeGroupOutput < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeIf < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeInput < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_input_name : Void* = Pointer(Void).null
    def set_input_name(name : String) : Void
      godot_bind(@@mb_set_input_name, "VisualShaderNodeInput", "set_input_name", 83702148_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_input_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_input_name : Void* = Pointer(Void).null
    def get_input_name() : String
      godot_bind(@@mb_get_input_name, "VisualShaderNodeInput", "get_input_name", 201670096_i64)
      godot_call_str("get_input_name")
    end
    @@mb_get_input_real_name : Void* = Pointer(Void).null
    def get_input_real_name() : String
      godot_bind(@@mb_get_input_real_name, "VisualShaderNodeInput", "get_input_real_name", 201670096_i64)
      godot_call_str("get_input_real_name")
    end
    # Property `input_name` getter
    def input_name
      get_input_name
    end
    # Property `input_name` setter
    def input_name=(val)
      set_input_name(val)
    end
    godot_signal input_type_changed
  end
  class VisualShaderNodeIntConstant < Godot::VisualShaderNodeConstant
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_constant : Void* = Pointer(Void).null
    def set_constant(constant : Int64) : Void
      godot_bind(@@mb_set_constant, "VisualShaderNodeIntConstant", "set_constant", 1286410249_i64)
      val_0 = constant
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_constant, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_constant : Void* = Pointer(Void).null
    def get_constant() : Int64
      godot_bind(@@mb_get_constant, "VisualShaderNodeIntConstant", "get_constant", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_constant, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `constant` getter
    def constant
      get_constant
    end
    # Property `constant` setter
    def constant=(val : Int)
      set_constant(val.to_i64)
    end
  end
  class VisualShaderNodeIntFunc < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Function : Int64
      FuncAbs = 0_i64
      FuncNegate = 1_i64
      FuncSign = 2_i64
      FuncBitwiseNot = 3_i64
      FuncMax = 4_i64
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeIntFunc", "set_function", 424195284_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeIntFunc", "get_function", 2753496911_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
  end
  class VisualShaderNodeIntOp < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Operator : Int64
      OpAdd = 0_i64
      OpSub = 1_i64
      OpMul = 2_i64
      OpDiv = 3_i64
      OpMod = 4_i64
      OpMax = 5_i64
      OpMin = 6_i64
      OpBitwiseAnd = 7_i64
      OpBitwiseOr = 8_i64
      OpBitwiseXor = 9_i64
      OpBitwiseLeftShift = 10_i64
      OpBitwiseRightShift = 11_i64
      OpEnumSize = 12_i64
    end
    @@mb_set_operator : Void* = Pointer(Void).null
    def set_operator(op : Operator | Int) : Void
      godot_bind(@@mb_set_operator, "VisualShaderNodeIntOp", "set_operator", 1677909323_i64)
      val_0 = op.is_a?(Int) ? op.to_i64 : op.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_operator, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_operator : Void* = Pointer(Void).null
    def get_operator() : Operator
      godot_bind(@@mb_get_operator, "VisualShaderNodeIntOp", "get_operator", 1236987913_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_operator, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Operator, ret)
    end
    # Property `operator` getter
    def operator
      get_operator
    end
    # Property `operator` setter
    def operator=(val : Int)
      set_operator(val.to_i64)
    end
  end
  class VisualShaderNodeIntParameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Hint : Int64
      HintNone = 0_i64
      HintRange = 1_i64
      HintRangeStep = 2_i64
      HintEnum = 3_i64
      HintMax = 4_i64
    end
    @@mb_set_hint : Void* = Pointer(Void).null
    def set_hint(hint : Hint | Int) : Void
      godot_bind(@@mb_set_hint, "VisualShaderNodeIntParameter", "set_hint", 2540512075_i64)
      val_0 = hint.is_a?(Int) ? hint.to_i64 : hint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_hint, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_hint : Void* = Pointer(Void).null
    def get_hint() : Hint
      godot_bind(@@mb_get_hint, "VisualShaderNodeIntParameter", "get_hint", 4250814924_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_hint, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Hint, ret)
    end
    @@mb_set_min : Void* = Pointer(Void).null
    def set_min(value : Int64) : Void
      godot_bind(@@mb_set_min, "VisualShaderNodeIntParameter", "set_min", 1286410249_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_min, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_min : Void* = Pointer(Void).null
    def get_min() : Int64
      godot_bind(@@mb_get_min, "VisualShaderNodeIntParameter", "get_min", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_min, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_max : Void* = Pointer(Void).null
    def set_max(value : Int64) : Void
      godot_bind(@@mb_set_max, "VisualShaderNodeIntParameter", "set_max", 1286410249_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_max, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_max : Void* = Pointer(Void).null
    def get_max() : Int64
      godot_bind(@@mb_get_max, "VisualShaderNodeIntParameter", "get_max", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_max, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_step : Void* = Pointer(Void).null
    def set_step(value : Int64) : Void
      godot_bind(@@mb_set_step, "VisualShaderNodeIntParameter", "set_step", 1286410249_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_step, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_step : Void* = Pointer(Void).null
    def get_step() : Int64
      godot_bind(@@mb_get_step, "VisualShaderNodeIntParameter", "get_step", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_step, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_enum_names : Void* = Pointer(Void).null
    def set_enum_names(names : Pointer(Void)) : Void
      godot_bind(@@mb_set_enum_names, "VisualShaderNodeIntParameter", "set_enum_names", 4015028928_i64)
      val_0 = names
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_enum_names, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_enum_names : Void* = Pointer(Void).null
    def get_enum_names() : Pointer(Void)
      godot_bind(@@mb_get_enum_names, "VisualShaderNodeIntParameter", "get_enum_names", 1139954409_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_enum_names, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_set_default_value_enabled : Void* = Pointer(Void).null
    def set_default_value_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_default_value_enabled, "VisualShaderNodeIntParameter", "set_default_value_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_default_value_enabled : Void* = Pointer(Void).null
    def is_default_value_enabled() : Bool
      godot_bind(@@mb_is_default_value_enabled, "VisualShaderNodeIntParameter", "is_default_value_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_default_value_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_default_value : Void* = Pointer(Void).null
    def set_default_value(value : Int64) : Void
      godot_bind(@@mb_set_default_value, "VisualShaderNodeIntParameter", "set_default_value", 1286410249_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_value : Void* = Pointer(Void).null
    def get_default_value() : Int64
      godot_bind(@@mb_get_default_value, "VisualShaderNodeIntParameter", "get_default_value", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_default_value, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `hint` getter
    def hint
      get_hint
    end
    # Property `hint` setter
    def hint=(val : Int)
      set_hint(val.to_i64)
    end
    # Property `min` getter
    def min
      get_min
    end
    # Property `min` setter
    def min=(val : Int)
      set_min(val.to_i64)
    end
    # Property `max` getter
    def max
      get_max
    end
    # Property `max` setter
    def max=(val : Int)
      set_max(val.to_i64)
    end
    # Property `step` getter
    def step
      get_step
    end
    # Property `step` setter
    def step=(val : Int)
      set_step(val.to_i64)
    end
    # Property `enum_names` getter
    def enum_names
      get_enum_names
    end
    # Property `enum_names` setter
    def enum_names=(val)
      set_enum_names(val)
    end
    # Property `default_value_enabled` getter
    def default_value_enabled
      is_default_value_enabled
    end
    def default_value_enabled?
      default_value_enabled
    end
    # Property `default_value_enabled` setter
    def default_value_enabled=(val)
      set_default_value_enabled(val)
    end
    # Property `default_value` getter
    def default_value
      get_default_value
    end
    # Property `default_value` setter
    def default_value=(val : Int)
      set_default_value(val.to_i64)
    end
  end
  class VisualShaderNodeIs < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Function : Int64
      FuncIsInf = 0_i64
      FuncIsNan = 1_i64
      FuncMax = 2_i64
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeIs", "set_function", 1438374690_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeIs", "get_function", 580678557_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
  end
  class VisualShaderNodeLinearSceneDepth < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeMix < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeScalar = 0_i64
      OpTypeVector2d = 1_i64
      OpTypeVector2dScalar = 2_i64
      OpTypeVector3d = 3_i64
      OpTypeVector3dScalar = 4_i64
      OpTypeVector4d = 5_i64
      OpTypeVector4dScalar = 6_i64
      OpTypeMax = 7_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(op_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeMix", "set_op_type", 3397501671_i64)
      val_0 = op_type.is_a?(Int) ? op_type.to_i64 : op_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeMix", "get_op_type", 4013957297_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
  end
  class VisualShaderNodeMultiplyAdd < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeScalar = 0_i64
      OpTypeVector2d = 1_i64
      OpTypeVector3d = 2_i64
      OpTypeVector4d = 3_i64
      OpTypeMax = 4_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(get_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeMultiplyAdd", "set_op_type", 1409862380_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeMultiplyAdd", "get_op_type", 2823201991_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
  end
  class VisualShaderNodeOuterProduct < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeOutput < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeParameterRef < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_parameter_name : Void* = Pointer(Void).null
    def set_parameter_name(name : String) : Void
      godot_bind(@@mb_set_parameter_name, "VisualShaderNodeParameterRef", "set_parameter_name", 83702148_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_parameter_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_parameter_name : Void* = Pointer(Void).null
    def get_parameter_name() : String
      godot_bind(@@mb_get_parameter_name, "VisualShaderNodeParameterRef", "get_parameter_name", 201670096_i64)
      godot_call_str("get_parameter_name")
    end
    # Property `parameter_name` getter
    def parameter_name
      get_parameter_name
    end
    # Property `parameter_name` setter
    def parameter_name=(val)
      set_parameter_name(val)
    end
  end
  class VisualShaderNodeParticleAccelerator < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Mode : Int64
      ModeLinear = 0_i64
      ModeRadial = 1_i64
      ModeTangential = 2_i64
      ModeMax = 3_i64
    end
    @@mb_set_mode : Void* = Pointer(Void).null
    def set_mode(mode : Mode | Int) : Void
      godot_bind(@@mb_set_mode, "VisualShaderNodeParticleAccelerator", "set_mode", 3457585749_i64)
      val_0 = mode.is_a?(Int) ? mode.to_i64 : mode.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_mode, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_mode : Void* = Pointer(Void).null
    def get_mode() : Mode
      godot_bind(@@mb_get_mode, "VisualShaderNodeParticleAccelerator", "get_mode", 2660365633_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_mode, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Mode, ret)
    end
    # Property `mode` getter
    def mode
      get_mode
    end
    # Property `mode` setter
    def mode=(val : Int)
      set_mode(val.to_i64)
    end
  end
  class VisualShaderNodeParticleEmitter < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_mode_2d : Void* = Pointer(Void).null
    def set_mode_2d(enabled : Bool) : Void
      godot_bind(@@mb_set_mode_2d, "VisualShaderNodeParticleEmitter", "set_mode_2d", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_mode_2d, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_mode_2d : Void* = Pointer(Void).null
    def is_mode_2d() : Bool
      godot_bind(@@mb_is_mode_2d, "VisualShaderNodeParticleEmitter", "is_mode_2d", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_mode_2d, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `mode_2d` getter
    def mode_2d
      is_mode_2d
    end
    def mode_2d?
      mode_2d
    end
    # Property `mode_2d` setter
    def mode_2d=(val)
      set_mode_2d(val)
    end
  end
  class VisualShaderNodeParticleBoxEmitter < Godot::VisualShaderNodeParticleEmitter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeParticleConeVelocity < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeParticleEmit < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum EmitFlags : Int64
      EmitFlagPosition = 1_i64
      EmitFlagRotScale = 2_i64
      EmitFlagVelocity = 4_i64
      EmitFlagColor = 8_i64
      EmitFlagCustom = 16_i64
    end
    @@mb_set_flags : Void* = Pointer(Void).null
    def set_flags(flags : EmitFlags | Int) : Void
      godot_bind(@@mb_set_flags, "VisualShaderNodeParticleEmit", "set_flags", 3960756792_i64)
      val_0 = flags.is_a?(Int) ? flags.to_i64 : flags.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_flags, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_flags : Void* = Pointer(Void).null
    def get_flags() : EmitFlags
      godot_bind(@@mb_get_flags, "VisualShaderNodeParticleEmit", "get_flags", 171277835_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_flags, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(EmitFlags, ret)
    end
    # Property `flags` getter
    def flags
      get_flags
    end
    # Property `flags` setter
    def flags=(val : Int)
      set_flags(val.to_i64)
    end
  end
  class VisualShaderNodeParticleMeshEmitter < Godot::VisualShaderNodeParticleEmitter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_mesh : Void* = Pointer(Void).null
    def set_mesh(mesh : Mesh) : Void
      godot_bind(@@mb_set_mesh, "VisualShaderNodeParticleMeshEmitter", "set_mesh", 194775623_i64)
      arg_ptr_0 = mesh ? mesh.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_mesh, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_mesh : Void* = Pointer(Void).null
    def get_mesh() : Mesh
      godot_bind(@@mb_get_mesh, "VisualShaderNodeParticleMeshEmitter", "get_mesh", 1808005922_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_mesh, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Mesh, ret_ptr)
    end
    @@mb_set_use_all_surfaces : Void* = Pointer(Void).null
    def set_use_all_surfaces(enabled : Bool) : Void
      godot_bind(@@mb_set_use_all_surfaces, "VisualShaderNodeParticleMeshEmitter", "set_use_all_surfaces", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_use_all_surfaces, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_use_all_surfaces : Void* = Pointer(Void).null
    def is_use_all_surfaces() : Bool
      godot_bind(@@mb_is_use_all_surfaces, "VisualShaderNodeParticleMeshEmitter", "is_use_all_surfaces", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_use_all_surfaces, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_surface_index : Void* = Pointer(Void).null
    def set_surface_index(surface_index : Int64) : Void
      godot_bind(@@mb_set_surface_index, "VisualShaderNodeParticleMeshEmitter", "set_surface_index", 1286410249_i64)
      val_0 = surface_index
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_surface_index, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_surface_index : Void* = Pointer(Void).null
    def get_surface_index() : Int64
      godot_bind(@@mb_get_surface_index, "VisualShaderNodeParticleMeshEmitter", "get_surface_index", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_surface_index, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `mesh` getter
    def mesh
      get_mesh
    end
    # Property `mesh` setter
    def mesh=(val)
      set_mesh(val)
    end
    # Property `use_all_surfaces` getter
    def use_all_surfaces
      is_use_all_surfaces
    end
    def use_all_surfaces?
      use_all_surfaces
    end
    # Property `use_all_surfaces` setter
    def use_all_surfaces=(val)
      set_use_all_surfaces(val)
    end
    # Property `surface_index` getter
    def surface_index
      get_surface_index
    end
    # Property `surface_index` setter
    def surface_index=(val : Int)
      set_surface_index(val.to_i64)
    end
  end
  class VisualShaderNodeParticleMultiplyByAxisAngle < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_degrees_mode : Void* = Pointer(Void).null
    def set_degrees_mode(enabled : Bool) : Void
      godot_bind(@@mb_set_degrees_mode, "VisualShaderNodeParticleMultiplyByAxisAngle", "set_degrees_mode", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_degrees_mode, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_degrees_mode : Void* = Pointer(Void).null
    def is_degrees_mode() : Bool
      godot_bind(@@mb_is_degrees_mode, "VisualShaderNodeParticleMultiplyByAxisAngle", "is_degrees_mode", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_degrees_mode, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `degrees_mode` getter
    def degrees_mode
      is_degrees_mode
    end
    def degrees_mode?
      degrees_mode
    end
    # Property `degrees_mode` setter
    def degrees_mode=(val)
      set_degrees_mode(val)
    end
  end
  class VisualShaderNodeParticleOutput < Godot::VisualShaderNodeOutput
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeParticleRandomness < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeScalar = 0_i64
      OpTypeVector2d = 1_i64
      OpTypeVector3d = 2_i64
      OpTypeVector4d = 3_i64
      OpTypeMax = 4_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(get_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeParticleRandomness", "set_op_type", 2060089061_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeParticleRandomness", "get_op_type", 3597061078_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
  end
  class VisualShaderNodeParticleRingEmitter < Godot::VisualShaderNodeParticleEmitter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeParticleSphereEmitter < Godot::VisualShaderNodeParticleEmitter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeProximityFade < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeRandomRange < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeRemap < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeScalar = 0_i64
      OpTypeVector2d = 1_i64
      OpTypeVector2dScalar = 2_i64
      OpTypeVector3d = 3_i64
      OpTypeVector3dScalar = 4_i64
      OpTypeVector4d = 5_i64
      OpTypeVector4dScalar = 6_i64
      OpTypeMax = 7_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(op_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeRemap", "set_op_type", 1703697889_i64)
      val_0 = op_type.is_a?(Int) ? op_type.to_i64 : op_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeRemap", "get_op_type", 1678380563_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
  end
  class VisualShaderNodeReroute < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_get_port_type : Void* = Pointer(Void).null
    def get_port_type() : Godot::VisualShaderNode::PortType
      godot_bind(@@mb_get_port_type, "VisualShaderNodeReroute", "get_port_type", 1287173294_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_port_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::VisualShaderNode::PortType, ret)
    end
    # Property `port_type` getter
    def port_type
      get_port_type
    end
  end
  class VisualShaderNodeRotationByAxis < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeSDFRaymarch < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeSDFToScreenUV < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeSample3D < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Source : Int64
      SourceTexture = 0_i64
      SourcePort = 1_i64
      SourceMax = 2_i64
    end
    @@mb_set_source : Void* = Pointer(Void).null
    def set_source(value : Source | Int) : Void
      godot_bind(@@mb_set_source, "VisualShaderNodeSample3D", "set_source", 3315130991_i64)
      val_0 = value.is_a?(Int) ? value.to_i64 : value.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_source, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_source : Void* = Pointer(Void).null
    def get_source() : Source
      godot_bind(@@mb_get_source, "VisualShaderNodeSample3D", "get_source", 1079494121_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_source, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Source, ret)
    end
    # Property `source` getter
    def source
      get_source
    end
    # Property `source` setter
    def source=(val : Int)
      set_source(val.to_i64)
    end
  end
  class VisualShaderNodeScreenNormalWorldSpace < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeScreenUVToSDF < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeSmoothStep < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeScalar = 0_i64
      OpTypeVector2d = 1_i64
      OpTypeVector2dScalar = 2_i64
      OpTypeVector3d = 3_i64
      OpTypeVector3dScalar = 4_i64
      OpTypeVector4d = 5_i64
      OpTypeVector4dScalar = 6_i64
      OpTypeMax = 7_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(op_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeSmoothStep", "set_op_type", 2427426148_i64)
      val_0 = op_type.is_a?(Int) ? op_type.to_i64 : op_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeSmoothStep", "get_op_type", 359640855_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
  end
  class VisualShaderNodeStep < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeScalar = 0_i64
      OpTypeVector2d = 1_i64
      OpTypeVector2dScalar = 2_i64
      OpTypeVector3d = 3_i64
      OpTypeVector3dScalar = 4_i64
      OpTypeVector4d = 5_i64
      OpTypeVector4dScalar = 6_i64
      OpTypeMax = 7_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(op_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeStep", "set_op_type", 715172489_i64)
      val_0 = op_type.is_a?(Int) ? op_type.to_i64 : op_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeStep", "get_op_type", 3274022781_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
  end
  class VisualShaderNodeSwitch < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum OpType : Int64
      OpTypeFloat = 0_i64
      OpTypeInt = 1_i64
      OpTypeUint = 2_i64
      OpTypeVector2d = 3_i64
      OpTypeVector3d = 4_i64
      OpTypeVector4d = 5_i64
      OpTypeBoolean = 6_i64
      OpTypeTransform = 7_i64
      OpTypeMax = 8_i64
    end
    @@mb_set_op_type : Void* = Pointer(Void).null
    def set_op_type(get_type : OpType | Int) : Void
      godot_bind(@@mb_set_op_type, "VisualShaderNodeSwitch", "set_op_type", 510471861_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_op_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_op_type : Void* = Pointer(Void).null
    def get_op_type() : OpType
      godot_bind(@@mb_get_op_type, "VisualShaderNodeSwitch", "get_op_type", 2517845071_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_op_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(OpType, ret)
    end
    # Property `op_type` getter
    def op_type
      get_op_type
    end
    # Property `op_type` setter
    def op_type=(val : Int)
      set_op_type(val.to_i64)
    end
  end
  class VisualShaderNodeTexture < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Source : Int64
      SourceTexture = 0_i64
      SourceScreen = 1_i64
      Source2dTexture = 2_i64
      Source2dNormal = 3_i64
      SourceDepth = 4_i64
      SourcePort = 5_i64
      Source3dNormal = 6_i64
      SourceRoughness = 7_i64
      SourceMax = 8_i64
    end
    enum TextureType : Int64
      TypeData = 0_i64
      TypeColor = 1_i64
      TypeNormalMap = 2_i64
      TypeMax = 3_i64
    end
    @@mb_set_source : Void* = Pointer(Void).null
    def set_source(value : Source | Int) : Void
      godot_bind(@@mb_set_source, "VisualShaderNodeTexture", "set_source", 905262939_i64)
      val_0 = value.is_a?(Int) ? value.to_i64 : value.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_source, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_source : Void* = Pointer(Void).null
    def get_source() : Source
      godot_bind(@@mb_get_source, "VisualShaderNodeTexture", "get_source", 2896297444_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_source, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Source, ret)
    end
    @@mb_set_texture : Void* = Pointer(Void).null
    def set_texture(value : Texture2D) : Void
      godot_bind(@@mb_set_texture, "VisualShaderNodeTexture", "set_texture", 4051416890_i64)
      arg_ptr_0 = value ? value.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture : Void* = Pointer(Void).null
    def get_texture() : Texture2D
      godot_bind(@@mb_get_texture, "VisualShaderNodeTexture", "get_texture", 3635182373_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_texture, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Texture2D, ret_ptr)
    end
    @@mb_set_texture_type : Void* = Pointer(Void).null
    def set_texture_type(value : TextureType | Int) : Void
      godot_bind(@@mb_set_texture_type, "VisualShaderNodeTexture", "set_texture_type", 986314081_i64)
      val_0 = value.is_a?(Int) ? value.to_i64 : value.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture_type : Void* = Pointer(Void).null
    def get_texture_type() : TextureType
      godot_bind(@@mb_get_texture_type, "VisualShaderNodeTexture", "get_texture_type", 3290430153_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_texture_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(TextureType, ret)
    end
    # Property `source` getter
    def source
      get_source
    end
    # Property `source` setter
    def source=(val : Int)
      set_source(val.to_i64)
    end
    # Property `texture` getter
    def texture
      get_texture
    end
    # Property `texture` setter
    def texture=(val)
      set_texture(val)
    end
    # Property `texture_type` getter
    def texture_type
      get_texture_type
    end
    # Property `texture_type` setter
    def texture_type=(val : Int)
      set_texture_type(val.to_i64)
    end
  end
  class VisualShaderNodeTexture2DArray < Godot::VisualShaderNodeSample3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_texture_array : Void* = Pointer(Void).null
    def set_texture_array(value : TextureLayered) : Void
      godot_bind(@@mb_set_texture_array, "VisualShaderNodeTexture2DArray", "set_texture_array", 1278366092_i64)
      arg_ptr_0 = value ? value.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture_array, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture_array : Void* = Pointer(Void).null
    def get_texture_array() : TextureLayered
      godot_bind(@@mb_get_texture_array, "VisualShaderNodeTexture2DArray", "get_texture_array", 3984243839_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_texture_array, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(TextureLayered, ret_ptr)
    end
    # Property `texture_array` getter
    def texture_array
      get_texture_array
    end
    # Property `texture_array` setter
    def texture_array=(val)
      set_texture_array(val)
    end
  end
  class VisualShaderNodeTexture2DArrayParameter < Godot::VisualShaderNodeTextureParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeTexture2DParameter < Godot::VisualShaderNodeTextureParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeTexture3D < Godot::VisualShaderNodeSample3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_texture : Void* = Pointer(Void).null
    def set_texture(value : Texture3D) : Void
      godot_bind(@@mb_set_texture, "VisualShaderNodeTexture3D", "set_texture", 1188404210_i64)
      arg_ptr_0 = value ? value.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_texture, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_texture : Void* = Pointer(Void).null
    def get_texture() : Texture3D
      godot_bind(@@mb_get_texture, "VisualShaderNodeTexture3D", "get_texture", 373985333_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_texture, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Texture3D, ret_ptr)
    end
    # Property `texture` getter
    def texture
      get_texture
    end
    # Property `texture` setter
    def texture=(val)
      set_texture(val)
    end
  end
  class VisualShaderNodeTexture3DParameter < Godot::VisualShaderNodeTextureParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeTextureParameterTriplanar < Godot::VisualShaderNodeTextureParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeTextureSDF < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeTextureSDFNormal < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeTransformCompose < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeTransformConstant < Godot::VisualShaderNodeConstant
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_constant : Void* = Pointer(Void).null
    def set_constant(constant : Transform3D) : Void
      godot_bind(@@mb_set_constant, "VisualShaderNodeTransformConstant", "set_constant", 2952846383_i64)
      val_0 = constant
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_constant, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_constant : Void* = Pointer(Void).null
    def get_constant() : Transform3D
      godot_bind(@@mb_get_constant, "VisualShaderNodeTransformConstant", "get_constant", 3229777777_i64)
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_constant, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `constant` getter
    def constant
      get_constant
    end
    # Property `constant` setter
    def constant=(val)
      set_constant(val)
    end
  end
  class VisualShaderNodeTransformDecompose < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeTransformFunc < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Function : Int64
      FuncInverse = 0_i64
      FuncTranspose = 1_i64
      FuncMax = 2_i64
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeTransformFunc", "set_function", 2900990409_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeTransformFunc", "get_function", 2839926569_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
  end
  class VisualShaderNodeTransformOp < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Operator : Int64
      OpAxb = 0_i64
      OpBxa = 1_i64
      OpAxbComp = 2_i64
      OpBxaComp = 3_i64
      OpAdd = 4_i64
      OpAMinusB = 5_i64
      OpBMinusA = 6_i64
      OpADivB = 7_i64
      OpBDivA = 8_i64
      OpMax = 9_i64
    end
    @@mb_set_operator : Void* = Pointer(Void).null
    def set_operator(op : Operator | Int) : Void
      godot_bind(@@mb_set_operator, "VisualShaderNodeTransformOp", "set_operator", 2287310733_i64)
      val_0 = op.is_a?(Int) ? op.to_i64 : op.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_operator, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_operator : Void* = Pointer(Void).null
    def get_operator() : Operator
      godot_bind(@@mb_get_operator, "VisualShaderNodeTransformOp", "get_operator", 1238663601_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_operator, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Operator, ret)
    end
    # Property `operator` getter
    def operator
      get_operator
    end
    # Property `operator` setter
    def operator=(val : Int)
      set_operator(val.to_i64)
    end
  end
  class VisualShaderNodeTransformParameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_default_value_enabled : Void* = Pointer(Void).null
    def set_default_value_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_default_value_enabled, "VisualShaderNodeTransformParameter", "set_default_value_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_default_value_enabled : Void* = Pointer(Void).null
    def is_default_value_enabled() : Bool
      godot_bind(@@mb_is_default_value_enabled, "VisualShaderNodeTransformParameter", "is_default_value_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_default_value_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_default_value : Void* = Pointer(Void).null
    def set_default_value(value : Transform3D) : Void
      godot_bind(@@mb_set_default_value, "VisualShaderNodeTransformParameter", "set_default_value", 2952846383_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_value : Void* = Pointer(Void).null
    def get_default_value() : Transform3D
      godot_bind(@@mb_get_default_value, "VisualShaderNodeTransformParameter", "get_default_value", 3229777777_i64)
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_default_value, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `default_value_enabled` getter
    def default_value_enabled
      is_default_value_enabled
    end
    def default_value_enabled?
      default_value_enabled
    end
    # Property `default_value_enabled` setter
    def default_value_enabled=(val)
      set_default_value_enabled(val)
    end
    # Property `default_value` getter
    def default_value
      get_default_value
    end
    # Property `default_value` setter
    def default_value=(val)
      set_default_value(val)
    end
  end
  class VisualShaderNodeTransformVecMult < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Operator : Int64
      OpAxb = 0_i64
      OpBxa = 1_i64
      Op3x3Axb = 2_i64
      Op3x3Bxa = 3_i64
      OpMax = 4_i64
    end
    @@mb_set_operator : Void* = Pointer(Void).null
    def set_operator(op : Operator | Int) : Void
      godot_bind(@@mb_set_operator, "VisualShaderNodeTransformVecMult", "set_operator", 1785665912_i64)
      val_0 = op.is_a?(Int) ? op.to_i64 : op.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_operator, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_operator : Void* = Pointer(Void).null
    def get_operator() : Operator
      godot_bind(@@mb_get_operator, "VisualShaderNodeTransformVecMult", "get_operator", 1622088722_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_operator, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Operator, ret)
    end
    # Property `operator` getter
    def operator
      get_operator
    end
    # Property `operator` setter
    def operator=(val : Int)
      set_operator(val.to_i64)
    end
  end
  class VisualShaderNodeUIntConstant < Godot::VisualShaderNodeConstant
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_constant : Void* = Pointer(Void).null
    def set_constant(constant : Int64) : Void
      godot_bind(@@mb_set_constant, "VisualShaderNodeUIntConstant", "set_constant", 1286410249_i64)
      val_0 = constant
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_constant, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_constant : Void* = Pointer(Void).null
    def get_constant() : Int64
      godot_bind(@@mb_get_constant, "VisualShaderNodeUIntConstant", "get_constant", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_constant, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `constant` getter
    def constant
      get_constant
    end
    # Property `constant` setter
    def constant=(val : Int)
      set_constant(val.to_i64)
    end
  end
  class VisualShaderNodeUIntFunc < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Function : Int64
      FuncNegate = 0_i64
      FuncBitwiseNot = 1_i64
      FuncMax = 2_i64
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeUIntFunc", "set_function", 2273148961_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeUIntFunc", "get_function", 4187123296_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
  end
  class VisualShaderNodeUIntOp < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Operator : Int64
      OpAdd = 0_i64
      OpSub = 1_i64
      OpMul = 2_i64
      OpDiv = 3_i64
      OpMod = 4_i64
      OpMax = 5_i64
      OpMin = 6_i64
      OpBitwiseAnd = 7_i64
      OpBitwiseOr = 8_i64
      OpBitwiseXor = 9_i64
      OpBitwiseLeftShift = 10_i64
      OpBitwiseRightShift = 11_i64
      OpEnumSize = 12_i64
    end
    @@mb_set_operator : Void* = Pointer(Void).null
    def set_operator(op : Operator | Int) : Void
      godot_bind(@@mb_set_operator, "VisualShaderNodeUIntOp", "set_operator", 3463048345_i64)
      val_0 = op.is_a?(Int) ? op.to_i64 : op.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_operator, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_operator : Void* = Pointer(Void).null
    def get_operator() : Operator
      godot_bind(@@mb_get_operator, "VisualShaderNodeUIntOp", "get_operator", 256631461_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_operator, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Operator, ret)
    end
    # Property `operator` getter
    def operator
      get_operator
    end
    # Property `operator` setter
    def operator=(val : Int)
      set_operator(val.to_i64)
    end
  end
  class VisualShaderNodeUIntParameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_default_value_enabled : Void* = Pointer(Void).null
    def set_default_value_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_default_value_enabled, "VisualShaderNodeUIntParameter", "set_default_value_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_default_value_enabled : Void* = Pointer(Void).null
    def is_default_value_enabled() : Bool
      godot_bind(@@mb_is_default_value_enabled, "VisualShaderNodeUIntParameter", "is_default_value_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_default_value_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_default_value : Void* = Pointer(Void).null
    def set_default_value(value : Int64) : Void
      godot_bind(@@mb_set_default_value, "VisualShaderNodeUIntParameter", "set_default_value", 1286410249_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_value : Void* = Pointer(Void).null
    def get_default_value() : Int64
      godot_bind(@@mb_get_default_value, "VisualShaderNodeUIntParameter", "get_default_value", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_default_value, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `default_value_enabled` getter
    def default_value_enabled
      is_default_value_enabled
    end
    def default_value_enabled?
      default_value_enabled
    end
    # Property `default_value_enabled` setter
    def default_value_enabled=(val)
      set_default_value_enabled(val)
    end
    # Property `default_value` getter
    def default_value
      get_default_value
    end
    # Property `default_value` setter
    def default_value=(val : Int)
      set_default_value(val.to_i64)
    end
  end
  class VisualShaderNodeUVFunc < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Function : Int64
      FuncPanning = 0_i64
      FuncScaling = 1_i64
      FuncMax = 2_i64
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeUVFunc", "set_function", 765791915_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeUVFunc", "get_function", 3772902164_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
  end
  class VisualShaderNodeUVPolarCoord < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeVarying < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_varying_name : Void* = Pointer(Void).null
    def set_varying_name(name : String) : Void
      godot_bind(@@mb_set_varying_name, "VisualShaderNodeVarying", "set_varying_name", 83702148_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_varying_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_varying_name : Void* = Pointer(Void).null
    def get_varying_name() : String
      godot_bind(@@mb_get_varying_name, "VisualShaderNodeVarying", "get_varying_name", 201670096_i64)
      godot_call_str("get_varying_name")
    end
    @@mb_set_varying_type : Void* = Pointer(Void).null
    def set_varying_type(get_type : Godot::VisualShader::VaryingType | Int) : Void
      godot_bind(@@mb_set_varying_type, "VisualShaderNodeVarying", "set_varying_type", 3565867981_i64)
      val_0 = get_type.is_a?(Int) ? get_type.to_i64 : get_type.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_varying_type, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_varying_type : Void* = Pointer(Void).null
    def get_varying_type() : Godot::VisualShader::VaryingType
      godot_bind(@@mb_get_varying_type, "VisualShaderNodeVarying", "get_varying_type", 523183580_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_varying_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::VisualShader::VaryingType, ret)
    end
    # Property `varying_name` getter
    def varying_name
      get_varying_name
    end
    # Property `varying_name` setter
    def varying_name=(val)
      set_varying_name(val)
    end
    # Property `varying_type` getter
    def varying_type
      get_varying_type
    end
    # Property `varying_type` setter
    def varying_type=(val : Int)
      set_varying_type(val.to_i64)
    end
  end
  class VisualShaderNodeVaryingGetter < Godot::VisualShaderNodeVarying
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeVaryingSetter < Godot::VisualShaderNodeVarying
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeVec2Constant < Godot::VisualShaderNodeConstant
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_constant : Void* = Pointer(Void).null
    def set_constant(constant : Vector2) : Void
      godot_bind(@@mb_set_constant, "VisualShaderNodeVec2Constant", "set_constant", 743155724_i64)
      val_0 = constant
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_constant, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_constant : Void* = Pointer(Void).null
    def get_constant() : Vector2
      godot_bind(@@mb_get_constant, "VisualShaderNodeVec2Constant", "get_constant", 3341600327_i64)
      ret = Vector2.new
      godot_ptrcall(@@mb_get_constant, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `constant` getter
    def constant
      get_constant
    end
    # Property `constant` setter
    def constant=(val)
      set_constant(val)
    end
  end
  class VisualShaderNodeVec2Parameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_default_value_enabled : Void* = Pointer(Void).null
    def set_default_value_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_default_value_enabled, "VisualShaderNodeVec2Parameter", "set_default_value_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_default_value_enabled : Void* = Pointer(Void).null
    def is_default_value_enabled() : Bool
      godot_bind(@@mb_is_default_value_enabled, "VisualShaderNodeVec2Parameter", "is_default_value_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_default_value_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_default_value : Void* = Pointer(Void).null
    def set_default_value(value : Vector2) : Void
      godot_bind(@@mb_set_default_value, "VisualShaderNodeVec2Parameter", "set_default_value", 743155724_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_value : Void* = Pointer(Void).null
    def get_default_value() : Vector2
      godot_bind(@@mb_get_default_value, "VisualShaderNodeVec2Parameter", "get_default_value", 3341600327_i64)
      ret = Vector2.new
      godot_ptrcall(@@mb_get_default_value, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `default_value_enabled` getter
    def default_value_enabled
      is_default_value_enabled
    end
    def default_value_enabled?
      default_value_enabled
    end
    # Property `default_value_enabled` setter
    def default_value_enabled=(val)
      set_default_value_enabled(val)
    end
    # Property `default_value` getter
    def default_value
      get_default_value
    end
    # Property `default_value` setter
    def default_value=(val)
      set_default_value(val)
    end
  end
  class VisualShaderNodeVec3Constant < Godot::VisualShaderNodeConstant
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_constant : Void* = Pointer(Void).null
    def set_constant(constant : Vector3) : Void
      godot_bind(@@mb_set_constant, "VisualShaderNodeVec3Constant", "set_constant", 3460891852_i64)
      val_0 = constant
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_constant, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_constant : Void* = Pointer(Void).null
    def get_constant() : Vector3
      godot_bind(@@mb_get_constant, "VisualShaderNodeVec3Constant", "get_constant", 3360562783_i64)
      ret = Vector3.new
      godot_ptrcall(@@mb_get_constant, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `constant` getter
    def constant
      get_constant
    end
    # Property `constant` setter
    def constant=(val)
      set_constant(val)
    end
  end
  class VisualShaderNodeVec3Parameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_default_value_enabled : Void* = Pointer(Void).null
    def set_default_value_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_default_value_enabled, "VisualShaderNodeVec3Parameter", "set_default_value_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_default_value_enabled : Void* = Pointer(Void).null
    def is_default_value_enabled() : Bool
      godot_bind(@@mb_is_default_value_enabled, "VisualShaderNodeVec3Parameter", "is_default_value_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_default_value_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_default_value : Void* = Pointer(Void).null
    def set_default_value(value : Vector3) : Void
      godot_bind(@@mb_set_default_value, "VisualShaderNodeVec3Parameter", "set_default_value", 3460891852_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_value : Void* = Pointer(Void).null
    def get_default_value() : Vector3
      godot_bind(@@mb_get_default_value, "VisualShaderNodeVec3Parameter", "get_default_value", 3360562783_i64)
      ret = Vector3.new
      godot_ptrcall(@@mb_get_default_value, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `default_value_enabled` getter
    def default_value_enabled
      is_default_value_enabled
    end
    def default_value_enabled?
      default_value_enabled
    end
    # Property `default_value_enabled` setter
    def default_value_enabled=(val)
      set_default_value_enabled(val)
    end
    # Property `default_value` getter
    def default_value
      get_default_value
    end
    # Property `default_value` setter
    def default_value=(val)
      set_default_value(val)
    end
  end
  class VisualShaderNodeVec4Constant < Godot::VisualShaderNodeConstant
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_constant : Void* = Pointer(Void).null
    def set_constant(constant : Quaternion) : Void
      godot_bind(@@mb_set_constant, "VisualShaderNodeVec4Constant", "set_constant", 1727505552_i64)
      val_0 = constant
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_constant, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_constant : Void* = Pointer(Void).null
    def get_constant() : Quaternion
      godot_bind(@@mb_get_constant, "VisualShaderNodeVec4Constant", "get_constant", 1222331677_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_constant, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Quaternion, ret_ptr)
    end
    # Property `constant` getter
    def constant
      get_constant
    end
    # Property `constant` setter
    def constant=(val)
      set_constant(val)
    end
  end
  class VisualShaderNodeVec4Parameter < Godot::VisualShaderNodeParameter
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_default_value_enabled : Void* = Pointer(Void).null
    def set_default_value_enabled(enabled : Bool) : Void
      godot_bind(@@mb_set_default_value_enabled, "VisualShaderNodeVec4Parameter", "set_default_value_enabled", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value_enabled, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_default_value_enabled : Void* = Pointer(Void).null
    def is_default_value_enabled() : Bool
      godot_bind(@@mb_is_default_value_enabled, "VisualShaderNodeVec4Parameter", "is_default_value_enabled", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_default_value_enabled, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_default_value : Void* = Pointer(Void).null
    def set_default_value(value : Vector4) : Void
      godot_bind(@@mb_set_default_value, "VisualShaderNodeVec4Parameter", "set_default_value", 643568085_i64)
      val_0 = value
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_value, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_default_value : Void* = Pointer(Void).null
    def get_default_value() : Vector4
      godot_bind(@@mb_get_default_value, "VisualShaderNodeVec4Parameter", "get_default_value", 2435802345_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_default_value, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Vector4, ret_ptr)
    end
    # Property `default_value_enabled` getter
    def default_value_enabled
      is_default_value_enabled
    end
    def default_value_enabled?
      default_value_enabled
    end
    # Property `default_value_enabled` setter
    def default_value_enabled=(val)
      set_default_value_enabled(val)
    end
    # Property `default_value` getter
    def default_value
      get_default_value
    end
    # Property `default_value` setter
    def default_value=(val)
      set_default_value(val)
    end
  end
  class VisualShaderNodeVectorCompose < Godot::VisualShaderNodeVectorBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeVectorDecompose < Godot::VisualShaderNodeVectorBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeVectorDistance < Godot::VisualShaderNodeVectorBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeVectorFunc < Godot::VisualShaderNodeVectorBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Function : Int64
      FuncNormalize = 0_i64
      FuncSaturate = 1_i64
      FuncNegate = 2_i64
      FuncReciprocal = 3_i64
      FuncAbs = 4_i64
      FuncAcos = 5_i64
      FuncAcosh = 6_i64
      FuncAsin = 7_i64
      FuncAsinh = 8_i64
      FuncAtan = 9_i64
      FuncAtanh = 10_i64
      FuncCeil = 11_i64
      FuncCos = 12_i64
      FuncCosh = 13_i64
      FuncDegrees = 14_i64
      FuncExp = 15_i64
      FuncExp2 = 16_i64
      FuncFloor = 17_i64
      FuncFract = 18_i64
      FuncInverseSqrt = 19_i64
      FuncLog = 20_i64
      FuncLog2 = 21_i64
      FuncRadians = 22_i64
      FuncRound = 23_i64
      FuncRoundeven = 24_i64
      FuncSign = 25_i64
      FuncSin = 26_i64
      FuncSinh = 27_i64
      FuncSqrt = 28_i64
      FuncTan = 29_i64
      FuncTanh = 30_i64
      FuncTrunc = 31_i64
      FuncOneminus = 32_i64
      FuncMax = 33_i64
    end
    @@mb_set_function : Void* = Pointer(Void).null
    def set_function(func : Function | Int) : Void
      godot_bind(@@mb_set_function, "VisualShaderNodeVectorFunc", "set_function", 629964457_i64)
      val_0 = func.is_a?(Int) ? func.to_i64 : func.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_function, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_function : Void* = Pointer(Void).null
    def get_function() : Function
      godot_bind(@@mb_get_function, "VisualShaderNodeVectorFunc", "get_function", 4047776843_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_function, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Function, ret)
    end
    # Property `function` getter
    def function
      get_function
    end
    # Property `function` setter
    def function=(val : Int)
      set_function(val.to_i64)
    end
  end
  class VisualShaderNodeVectorLen < Godot::VisualShaderNodeVectorBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeVectorOp < Godot::VisualShaderNodeVectorBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Operator : Int64
      OpAdd = 0_i64
      OpSub = 1_i64
      OpMul = 2_i64
      OpDiv = 3_i64
      OpMod = 4_i64
      OpPow = 5_i64
      OpMax = 6_i64
      OpMin = 7_i64
      OpCross = 8_i64
      OpAtan2 = 9_i64
      OpReflect = 10_i64
      OpStep = 11_i64
      OpEnumSize = 12_i64
    end
    @@mb_set_operator : Void* = Pointer(Void).null
    def set_operator(op : Operator | Int) : Void
      godot_bind(@@mb_set_operator, "VisualShaderNodeVectorOp", "set_operator", 3371507302_i64)
      val_0 = op.is_a?(Int) ? op.to_i64 : op.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_operator, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_operator : Void* = Pointer(Void).null
    def get_operator() : Operator
      godot_bind(@@mb_get_operator, "VisualShaderNodeVectorOp", "get_operator", 11793929_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_operator, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Operator, ret)
    end
    # Property `operator` getter
    def operator
      get_operator
    end
    # Property `operator` setter
    def operator=(val : Int)
      set_operator(val.to_i64)
    end
  end
  class VisualShaderNodeVectorRefract < Godot::VisualShaderNodeVectorBase
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VisualShaderNodeWorldPositionFromDepth < Godot::VisualShaderNode
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class VoxelGI < Godot::VisualInstance3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum Subdiv : Int64
      Subdiv64 = 0_i64
      Subdiv128 = 1_i64
      Subdiv256 = 2_i64
      Subdiv512 = 3_i64
      SubdivMax = 4_i64
    end
    @@mb_set_probe_data : Void* = Pointer(Void).null
    def set_probe_data(data : VoxelGIData) : Void
      godot_bind(@@mb_set_probe_data, "VoxelGI", "set_probe_data", 1637849675_i64)
      arg_ptr_0 = data ? data.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_probe_data, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_probe_data : Void* = Pointer(Void).null
    def get_probe_data() : VoxelGIData
      godot_bind(@@mb_get_probe_data, "VoxelGI", "get_probe_data", 1730645405_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_probe_data, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(VoxelGIData, ret_ptr)
    end
    @@mb_set_subdiv : Void* = Pointer(Void).null
    def set_subdiv(subdiv : Subdiv | Int) : Void
      godot_bind(@@mb_set_subdiv, "VoxelGI", "set_subdiv", 2240898472_i64)
      val_0 = subdiv.is_a?(Int) ? subdiv.to_i64 : subdiv.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_subdiv, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_subdiv : Void* = Pointer(Void).null
    def get_subdiv() : Subdiv
      godot_bind(@@mb_get_subdiv, "VoxelGI", "get_subdiv", 4261647950_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_subdiv, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Subdiv, ret)
    end
    @@mb_set_size : Void* = Pointer(Void).null
    def set_size(size : Vector3) : Void
      godot_bind(@@mb_set_size, "VoxelGI", "set_size", 3460891852_i64)
      val_0 = size
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_size, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_size : Void* = Pointer(Void).null
    def get_size() : Vector3
      godot_bind(@@mb_get_size, "VoxelGI", "get_size", 3360562783_i64)
      ret = Vector3.new
      godot_ptrcall(@@mb_get_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_camera_attributes : Void* = Pointer(Void).null
    def set_camera_attributes(camera_attributes : CameraAttributes) : Void
      godot_bind(@@mb_set_camera_attributes, "VoxelGI", "set_camera_attributes", 2817810567_i64)
      arg_ptr_0 = camera_attributes ? camera_attributes.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_camera_attributes, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_camera_attributes : Void* = Pointer(Void).null
    def get_camera_attributes() : CameraAttributes
      godot_bind(@@mb_get_camera_attributes, "VoxelGI", "get_camera_attributes", 3921283215_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_camera_attributes, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(CameraAttributes, ret_ptr)
    end
    @@mb_bake : Void* = Pointer(Void).null
    def bake(from_node : Node? = nil, create_visual_debug : Bool = false) : Void
      godot_bind(@@mb_bake, "VoxelGI", "bake", 2781551026_i64)
      arg_ptr_0 = from_node ? from_node.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      val_1 = create_visual_debug
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_bake, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_debug_bake : Void* = Pointer(Void).null
    def debug_bake() : Void
      godot_bind(@@mb_debug_bake, "VoxelGI", "debug_bake", 3218959716_i64)
      godot_ptrcall(@@mb_debug_bake, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    # Property `subdiv` getter
    def subdiv
      get_subdiv
    end
    # Property `subdiv` setter
    def subdiv=(val : Int)
      set_subdiv(val.to_i64)
    end
    # Property `size` getter
    def size
      get_size
    end
    # Property `size` setter
    def size=(val)
      set_size(val)
    end
    # Property `camera_attributes` getter
    def camera_attributes
      get_camera_attributes
    end
    # Property `camera_attributes` setter
    def camera_attributes=(val)
      set_camera_attributes(val)
    end
    # Property `data` getter
    def data
      get_probe_data
    end
    # Property `data` setter
    def data=(val)
      set_probe_data(val)
    end
  end
  class VoxelGIData < Godot::Resource
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_allocate : Void* = Pointer(Void).null
    def godot_allocate(to_cell_xform : Transform3D, aabb : AABB, octree_size : Vector3, octree_cells : Pointer(Void), data_cells : Pointer(Void), distance_field : Pointer(Void), level_counts : Pointer(Void)) : Void
      godot_bind(@@mb_allocate, "VoxelGIData", "allocate", 4041601946_i64)
      val_0 = to_cell_xform
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = aabb
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = octree_size
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = octree_cells
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = data_cells
      arg_4 = pointerof(val_4).as(Void*)
      val_5 = distance_field
      arg_5 = pointerof(val_5).as(Void*)
      val_6 = level_counts
      arg_6 = pointerof(val_6).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3, arg_4, arg_5, arg_6]
      godot_ptrcall(@@mb_allocate, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_bounds : Void* = Pointer(Void).null
    def get_bounds() : AABB
      godot_bind(@@mb_get_bounds, "VoxelGIData", "get_bounds", 1068685055_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_bounds, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(AABB, ret_ptr)
    end
    @@mb_get_octree_size : Void* = Pointer(Void).null
    def get_octree_size() : Vector3
      godot_bind(@@mb_get_octree_size, "VoxelGIData", "get_octree_size", 3360562783_i64)
      ret = Vector3.new
      godot_ptrcall(@@mb_get_octree_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_to_cell_xform : Void* = Pointer(Void).null
    def get_to_cell_xform() : Transform3D
      godot_bind(@@mb_get_to_cell_xform, "VoxelGIData", "get_to_cell_xform", 3229777777_i64)
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_to_cell_xform, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_octree_cells : Void* = Pointer(Void).null
    def get_octree_cells() : Pointer(Void)
      godot_bind(@@mb_get_octree_cells, "VoxelGIData", "get_octree_cells", 2362200018_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_octree_cells, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_get_data_cells : Void* = Pointer(Void).null
    def get_data_cells() : Pointer(Void)
      godot_bind(@@mb_get_data_cells, "VoxelGIData", "get_data_cells", 2362200018_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_data_cells, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_get_level_counts : Void* = Pointer(Void).null
    def get_level_counts() : Pointer(Void)
      godot_bind(@@mb_get_level_counts, "VoxelGIData", "get_level_counts", 1930428628_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_level_counts, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_set_dynamic_range : Void* = Pointer(Void).null
    def set_dynamic_range(dynamic_range : Float64) : Void
      godot_bind(@@mb_set_dynamic_range, "VoxelGIData", "set_dynamic_range", 373806689_i64)
      val_0 = dynamic_range
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_dynamic_range, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_dynamic_range : Void* = Pointer(Void).null
    def get_dynamic_range() : Float64
      godot_bind(@@mb_get_dynamic_range, "VoxelGIData", "get_dynamic_range", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_dynamic_range, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_energy : Void* = Pointer(Void).null
    def set_energy(energy : Float64) : Void
      godot_bind(@@mb_set_energy, "VoxelGIData", "set_energy", 373806689_i64)
      val_0 = energy
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_energy, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_energy : Void* = Pointer(Void).null
    def get_energy() : Float64
      godot_bind(@@mb_get_energy, "VoxelGIData", "get_energy", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_energy, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_bias : Void* = Pointer(Void).null
    def set_bias(bias : Float64) : Void
      godot_bind(@@mb_set_bias, "VoxelGIData", "set_bias", 373806689_i64)
      val_0 = bias
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_bias, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_bias : Void* = Pointer(Void).null
    def get_bias() : Float64
      godot_bind(@@mb_get_bias, "VoxelGIData", "get_bias", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_bias, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_normal_bias : Void* = Pointer(Void).null
    def set_normal_bias(bias : Float64) : Void
      godot_bind(@@mb_set_normal_bias, "VoxelGIData", "set_normal_bias", 373806689_i64)
      val_0 = bias
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_normal_bias, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_normal_bias : Void* = Pointer(Void).null
    def get_normal_bias() : Float64
      godot_bind(@@mb_get_normal_bias, "VoxelGIData", "get_normal_bias", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_normal_bias, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_propagation : Void* = Pointer(Void).null
    def set_propagation(propagation : Float64) : Void
      godot_bind(@@mb_set_propagation, "VoxelGIData", "set_propagation", 373806689_i64)
      val_0 = propagation
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_propagation, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_propagation : Void* = Pointer(Void).null
    def get_propagation() : Float64
      godot_bind(@@mb_get_propagation, "VoxelGIData", "get_propagation", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_propagation, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_interior : Void* = Pointer(Void).null
    def set_interior(interior : Bool) : Void
      godot_bind(@@mb_set_interior, "VoxelGIData", "set_interior", 2586408642_i64)
      val_0 = interior
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_interior, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_interior : Void* = Pointer(Void).null
    def is_interior() : Bool
      godot_bind(@@mb_is_interior, "VoxelGIData", "is_interior", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_interior, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_use_two_bounces : Void* = Pointer(Void).null
    def set_use_two_bounces(enable : Bool) : Void
      godot_bind(@@mb_set_use_two_bounces, "VoxelGIData", "set_use_two_bounces", 2586408642_i64)
      val_0 = enable
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_use_two_bounces, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_using_two_bounces : Void* = Pointer(Void).null
    def is_using_two_bounces() : Bool
      godot_bind(@@mb_is_using_two_bounces, "VoxelGIData", "is_using_two_bounces", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_using_two_bounces, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `dynamic_range` getter
    def dynamic_range
      get_dynamic_range
    end
    # Property `dynamic_range` setter
    def dynamic_range=(val : Number)
      set_dynamic_range(val.to_f64)
    end
    # Property `energy` getter
    def energy
      get_energy
    end
    # Property `energy` setter
    def energy=(val : Number)
      set_energy(val.to_f64)
    end
    # Property `bias` getter
    def bias
      get_bias
    end
    # Property `bias` setter
    def bias=(val : Number)
      set_bias(val.to_f64)
    end
    # Property `normal_bias` getter
    def normal_bias
      get_normal_bias
    end
    # Property `normal_bias` setter
    def normal_bias=(val : Number)
      set_normal_bias(val.to_f64)
    end
    # Property `propagation` getter
    def propagation
      get_propagation
    end
    # Property `propagation` setter
    def propagation=(val : Number)
      set_propagation(val.to_f64)
    end
    # Property `use_two_bounces` getter
    def use_two_bounces
      is_using_two_bounces
    end
    def use_two_bounces?
      use_two_bounces
    end
    # Property `use_two_bounces` setter
    def use_two_bounces=(val)
      set_use_two_bounces(val)
    end
    # Property `interior` getter
    def interior
      is_interior
    end
    def interior?
      interior
    end
    # Property `interior` setter
    def interior=(val)
      set_interior(val)
    end
  end
  class WeakRef < Godot::RefCounted
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_get_ref : Void* = Pointer(Void).null
    def get_ref() : Pointer(Void)
      godot_bind(@@mb_get_ref, "WeakRef", "get_ref", 1214101251_i64)
      ret_var = StaticArray(UInt8, 24).new(0_u8)
      godot_ptrcall(@@mb_get_ref, @pointer, Pointer(Pointer(Void)).null, ret_var.to_unsafe.as(Void*))
      ret_ptr = Pointer(Void).null
      Bridge.type_from_variant(24, pointerof(ret_ptr).as(Void*), ret_var.to_unsafe.as(Void*))
      ret_ptr
    end
  end
  class WebRTCDataChannel < Godot::PacketPeer
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum WriteMode : Int64
      WriteModeText = 0_i64
      WriteModeBinary = 1_i64
    end
    enum ChannelState : Int64
      StateConnecting = 0_i64
      StateOpen = 1_i64
      StateClosing = 2_i64
      StateClosed = 3_i64
    end
    @@mb_poll : Void* = Pointer(Void).null
    def poll() : Godot::Error
      godot_bind(@@mb_poll, "WebRTCDataChannel", "poll", 166280745_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_poll, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_close : Void* = Pointer(Void).null
    def close() : Void
      godot_bind(@@mb_close, "WebRTCDataChannel", "close", 3218959716_i64)
      godot_ptrcall(@@mb_close, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_was_string_packet : Void* = Pointer(Void).null
    def was_string_packet() : Bool
      godot_bind(@@mb_was_string_packet, "WebRTCDataChannel", "was_string_packet", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_was_string_packet, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_write_mode : Void* = Pointer(Void).null
    def set_write_mode(write_mode : WriteMode | Int) : Void
      godot_bind(@@mb_set_write_mode, "WebRTCDataChannel", "set_write_mode", 1999768052_i64)
      val_0 = write_mode.is_a?(Int) ? write_mode.to_i64 : write_mode.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_write_mode, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_write_mode : Void* = Pointer(Void).null
    def get_write_mode() : WriteMode
      godot_bind(@@mb_get_write_mode, "WebRTCDataChannel", "get_write_mode", 2848495172_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_write_mode, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(WriteMode, ret)
    end
    @@mb_get_ready_state : Void* = Pointer(Void).null
    def get_ready_state() : ChannelState
      godot_bind(@@mb_get_ready_state, "WebRTCDataChannel", "get_ready_state", 3501143017_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_ready_state, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(ChannelState, ret)
    end
    @@mb_get_label : Void* = Pointer(Void).null
    def get_label() : String
      godot_bind(@@mb_get_label, "WebRTCDataChannel", "get_label", 201670096_i64)
      godot_call_str("get_label")
    end
    @@mb_is_ordered : Void* = Pointer(Void).null
    def is_ordered() : Bool
      godot_bind(@@mb_is_ordered, "WebRTCDataChannel", "is_ordered", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_ordered, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_id : Void* = Pointer(Void).null
    def get_id() : Int64
      godot_bind(@@mb_get_id, "WebRTCDataChannel", "get_id", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_id, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_max_packet_life_time : Void* = Pointer(Void).null
    def get_max_packet_life_time() : Int64
      godot_bind(@@mb_get_max_packet_life_time, "WebRTCDataChannel", "get_max_packet_life_time", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_max_packet_life_time, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_max_retransmits : Void* = Pointer(Void).null
    def get_max_retransmits() : Int64
      godot_bind(@@mb_get_max_retransmits, "WebRTCDataChannel", "get_max_retransmits", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_max_retransmits, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_protocol : Void* = Pointer(Void).null
    def get_protocol() : String
      godot_bind(@@mb_get_protocol, "WebRTCDataChannel", "get_protocol", 201670096_i64)
      godot_call_str("get_protocol")
    end
    @@mb_is_negotiated : Void* = Pointer(Void).null
    def is_negotiated() : Bool
      godot_bind(@@mb_is_negotiated, "WebRTCDataChannel", "is_negotiated", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_negotiated, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_buffered_amount : Void* = Pointer(Void).null
    def get_buffered_amount() : Int64
      godot_bind(@@mb_get_buffered_amount, "WebRTCDataChannel", "get_buffered_amount", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_buffered_amount, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `write_mode` getter
    def write_mode
      get_write_mode
    end
    # Property `write_mode` setter
    def write_mode=(val : Int)
      set_write_mode(val.to_i64)
    end
  end
  class WebRTCDataChannelExtension < Godot::WebRTCDataChannel
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class WebRTCMultiplayerPeer < Godot::MultiplayerPeer
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_create_server : Void* = Pointer(Void).null
    def create_server(channels_config : Pointer(Void)) : Godot::Error
      godot_bind(@@mb_create_server, "WebRTCMultiplayerPeer", "create_server", 2865356025_i64)
      val_0 = channels_config
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_create_server, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_create_client : Void* = Pointer(Void).null
    def create_client(peer_id : Int64, channels_config : Pointer(Void)) : Godot::Error
      godot_bind(@@mb_create_client, "WebRTCMultiplayerPeer", "create_client", 2641732907_i64)
      val_0 = peer_id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = channels_config
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_create_client, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_create_mesh : Void* = Pointer(Void).null
    def create_mesh(peer_id : Int64, channels_config : Pointer(Void)) : Godot::Error
      godot_bind(@@mb_create_mesh, "WebRTCMultiplayerPeer", "create_mesh", 2641732907_i64)
      val_0 = peer_id
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = channels_config
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_create_mesh, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_add_peer : Void* = Pointer(Void).null
    def add_peer(peer : WebRTCPeerConnection, peer_id : Int64, unreliable_lifetime : Int64 = 1_i64) : Godot::Error
      godot_bind(@@mb_add_peer, "WebRTCMultiplayerPeer", "add_peer", 4078953270_i64)
      arg_ptr_0 = peer ? peer.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      val_1 = peer_id
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = unreliable_lifetime
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      ret = 0_i64
      godot_ptrcall(@@mb_add_peer, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_remove_peer : Void* = Pointer(Void).null
    def remove_peer(peer_id : Int64) : Void
      godot_bind(@@mb_remove_peer, "WebRTCMultiplayerPeer", "remove_peer", 1286410249_i64)
      val_0 = peer_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_peer, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_has_peer : Void* = Pointer(Void).null
    def has_peer(peer_id : Int64) : Bool
      godot_bind(@@mb_has_peer, "WebRTCMultiplayerPeer", "has_peer", 3067735520_i64)
      val_0 = peer_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_has_peer, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_peer : Void* = Pointer(Void).null
    def get_peer(peer_id : Int64) : Pointer(Void)
      godot_bind(@@mb_get_peer, "WebRTCMultiplayerPeer", "get_peer", 3554694381_i64)
      val_0 = peer_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_peer, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_get_peers : Void* = Pointer(Void).null
    def get_peers() : Pointer(Void)
      godot_bind(@@mb_get_peers, "WebRTCMultiplayerPeer", "get_peers", 2382534195_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_peers, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
  end
  class WebRTCPeerConnection < Godot::RefCounted
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum ConnectionState : Int64
      StateNew = 0_i64
      StateConnecting = 1_i64
      StateConnected = 2_i64
      StateDisconnected = 3_i64
      StateFailed = 4_i64
      StateClosed = 5_i64
    end
    enum GatheringState : Int64
      GatheringStateNew = 0_i64
      GatheringStateGathering = 1_i64
      GatheringStateComplete = 2_i64
    end
    enum SignalingState : Int64
      SignalingStateStable = 0_i64
      SignalingStateHaveLocalOffer = 1_i64
      SignalingStateHaveRemoteOffer = 2_i64
      SignalingStateHaveLocalPranswer = 3_i64
      SignalingStateHaveRemotePranswer = 4_i64
      SignalingStateClosed = 5_i64
    end
    @@mb_set_default_extension : Void* = Pointer(Void).null
    def self.set_default_extension(extension_class : String) : Void
      godot_bind(@@mb_set_default_extension, "WebRTCPeerConnection", "set_default_extension", 3304788590_i64)
      sn_0 = Bridge.make_string_name(extension_class)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_default_extension, Pointer(Void).null, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    # Instance convenience delegator for static method `set_default_extension`
    def set_default_extension(extension_class : String) : Void
      self.class.set_default_extension(extension_class)
    end
    @@mb_initialize : Void* = Pointer(Void).null
    def godot_initialize(configuration : Pointer(Void)) : Godot::Error
      godot_bind(@@mb_initialize, "WebRTCPeerConnection", "initialize", 2625064318_i64)
      val_0 = configuration
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_initialize, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_create_data_channel : Void* = Pointer(Void).null
    def create_data_channel(label : String, options : Pointer(Void)) : WebRTCDataChannel
      godot_bind(@@mb_create_data_channel, "WebRTCPeerConnection", "create_data_channel", 1288557393_i64)
      str_0 = Bridge.make_string(label)
      arg_0 = str_0
      val_1 = options
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_create_data_channel, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      godot_return_obj(WebRTCDataChannel, ret_ptr)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_create_offer : Void* = Pointer(Void).null
    def create_offer() : Godot::Error
      godot_bind(@@mb_create_offer, "WebRTCPeerConnection", "create_offer", 166280745_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_create_offer, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_set_local_description : Void* = Pointer(Void).null
    def set_local_description(get_type : String, sdp : String) : Godot::Error
      godot_bind(@@mb_set_local_description, "WebRTCPeerConnection", "set_local_description", 852856452_i64)
      str_0 = Bridge.make_string(get_type)
      arg_0 = str_0
      str_1 = Bridge.make_string(sdp)
      arg_1 = str_1
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_set_local_description, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
      Bridge.free_string(str_1)
    end
    @@mb_set_remote_description : Void* = Pointer(Void).null
    def set_remote_description(get_type : String, sdp : String) : Godot::Error
      godot_bind(@@mb_set_remote_description, "WebRTCPeerConnection", "set_remote_description", 852856452_i64)
      str_0 = Bridge.make_string(get_type)
      arg_0 = str_0
      str_1 = Bridge.make_string(sdp)
      arg_1 = str_1
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_set_remote_description, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
      Bridge.free_string(str_1)
    end
    @@mb_add_ice_candidate : Void* = Pointer(Void).null
    def add_ice_candidate(media : String, index : Int64, name : String) : Godot::Error
      godot_bind(@@mb_add_ice_candidate, "WebRTCPeerConnection", "add_ice_candidate", 3958950400_i64)
      str_0 = Bridge.make_string(media)
      arg_0 = str_0
      val_1 = index
      arg_1 = pointerof(val_1).as(Void*)
      str_2 = Bridge.make_string(name)
      arg_2 = str_2
      args = [arg_0, arg_1, arg_2]
      ret = 0_i64
      godot_ptrcall(@@mb_add_ice_candidate, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
      Bridge.free_string(str_2)
    end
    @@mb_poll : Void* = Pointer(Void).null
    def poll() : Godot::Error
      godot_bind(@@mb_poll, "WebRTCPeerConnection", "poll", 166280745_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_poll, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_close : Void* = Pointer(Void).null
    def close() : Void
      godot_bind(@@mb_close, "WebRTCPeerConnection", "close", 3218959716_i64)
      godot_ptrcall(@@mb_close, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_get_connection_state : Void* = Pointer(Void).null
    def get_connection_state() : ConnectionState
      godot_bind(@@mb_get_connection_state, "WebRTCPeerConnection", "get_connection_state", 2275710506_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_connection_state, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(ConnectionState, ret)
    end
    @@mb_get_gathering_state : Void* = Pointer(Void).null
    def get_gathering_state() : GatheringState
      godot_bind(@@mb_get_gathering_state, "WebRTCPeerConnection", "get_gathering_state", 4262591401_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_gathering_state, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(GatheringState, ret)
    end
    @@mb_get_signaling_state : Void* = Pointer(Void).null
    def get_signaling_state() : SignalingState
      godot_bind(@@mb_get_signaling_state, "WebRTCPeerConnection", "get_signaling_state", 3342956226_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_signaling_state, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(SignalingState, ret)
    end
    godot_signal session_description_created, String, String
    godot_signal ice_candidate_created, String, Int64, String
    godot_signal data_channel_received, WebRTCDataChannel
  end
  class WebRTCPeerConnectionExtension < Godot::WebRTCPeerConnection
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class WebSocketMultiplayerPeer < Godot::MultiplayerPeer
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_create_client : Void* = Pointer(Void).null
    def create_client(url : String, tls_client_options : TLSOptions? = nil) : Godot::Error
      godot_bind(@@mb_create_client, "WebSocketMultiplayerPeer", "create_client", 1966198364_i64)
      str_0 = Bridge.make_string(url)
      arg_0 = str_0
      arg_ptr_1 = tls_client_options ? tls_client_options.pointer : Pointer(Void).null
      arg_1 = pointerof(arg_ptr_1).as(Void*)
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_create_client, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_create_server : Void* = Pointer(Void).null
    def create_server(port : Int64, bind_address : String = "*", tls_server_options : TLSOptions? = nil) : Godot::Error
      godot_bind(@@mb_create_server, "WebSocketMultiplayerPeer", "create_server", 2400822951_i64)
      val_0 = port
      arg_0 = pointerof(val_0).as(Void*)
      str_1 = Bridge.make_string(bind_address)
      arg_1 = str_1
      arg_ptr_2 = tls_server_options ? tls_server_options.pointer : Pointer(Void).null
      arg_2 = pointerof(arg_ptr_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      ret = 0_i64
      godot_ptrcall(@@mb_create_server, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_1)
    end
    @@mb_get_peer : Void* = Pointer(Void).null
    def get_peer(peer_id : Int64) : WebSocketPeer
      godot_bind(@@mb_get_peer, "WebSocketMultiplayerPeer", "get_peer", 1381378851_i64)
      val_0 = peer_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_peer, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      godot_return_obj(WebSocketPeer, ret_ptr)
    end
    @@mb_get_peer_address : Void* = Pointer(Void).null
    def get_peer_address(id : Int64) : String
      godot_bind(@@mb_get_peer_address, "WebSocketMultiplayerPeer", "get_peer_address", 844755477_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_call_str("get_peer_address", id)
    end
    @@mb_get_peer_port : Void* = Pointer(Void).null
    def get_peer_port(id : Int64) : Int64
      godot_bind(@@mb_get_peer_port, "WebSocketMultiplayerPeer", "get_peer_port", 923996154_i64)
      val_0 = id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_peer_port, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_supported_protocols : Void* = Pointer(Void).null
    def get_supported_protocols() : Pointer(Void)
      godot_bind(@@mb_get_supported_protocols, "WebSocketMultiplayerPeer", "get_supported_protocols", 1139954409_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_supported_protocols, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_set_supported_protocols : Void* = Pointer(Void).null
    def set_supported_protocols(protocols : Pointer(Void)) : Void
      godot_bind(@@mb_set_supported_protocols, "WebSocketMultiplayerPeer", "set_supported_protocols", 4015028928_i64)
      val_0 = protocols
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_supported_protocols, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_handshake_headers : Void* = Pointer(Void).null
    def get_handshake_headers() : Pointer(Void)
      godot_bind(@@mb_get_handshake_headers, "WebSocketMultiplayerPeer", "get_handshake_headers", 1139954409_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_handshake_headers, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_set_handshake_headers : Void* = Pointer(Void).null
    def set_handshake_headers(protocols : Pointer(Void)) : Void
      godot_bind(@@mb_set_handshake_headers, "WebSocketMultiplayerPeer", "set_handshake_headers", 4015028928_i64)
      val_0 = protocols
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_handshake_headers, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_inbound_buffer_size : Void* = Pointer(Void).null
    def get_inbound_buffer_size() : Int64
      godot_bind(@@mb_get_inbound_buffer_size, "WebSocketMultiplayerPeer", "get_inbound_buffer_size", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_inbound_buffer_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_inbound_buffer_size : Void* = Pointer(Void).null
    def set_inbound_buffer_size(buffer_size : Int64) : Void
      godot_bind(@@mb_set_inbound_buffer_size, "WebSocketMultiplayerPeer", "set_inbound_buffer_size", 1286410249_i64)
      val_0 = buffer_size
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_inbound_buffer_size, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_outbound_buffer_size : Void* = Pointer(Void).null
    def get_outbound_buffer_size() : Int64
      godot_bind(@@mb_get_outbound_buffer_size, "WebSocketMultiplayerPeer", "get_outbound_buffer_size", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_outbound_buffer_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_outbound_buffer_size : Void* = Pointer(Void).null
    def set_outbound_buffer_size(buffer_size : Int64) : Void
      godot_bind(@@mb_set_outbound_buffer_size, "WebSocketMultiplayerPeer", "set_outbound_buffer_size", 1286410249_i64)
      val_0 = buffer_size
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_outbound_buffer_size, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_handshake_timeout : Void* = Pointer(Void).null
    def get_handshake_timeout() : Float64
      godot_bind(@@mb_get_handshake_timeout, "WebSocketMultiplayerPeer", "get_handshake_timeout", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_handshake_timeout, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_handshake_timeout : Void* = Pointer(Void).null
    def set_handshake_timeout(timeout : Float64) : Void
      godot_bind(@@mb_set_handshake_timeout, "WebSocketMultiplayerPeer", "set_handshake_timeout", 373806689_i64)
      val_0 = timeout
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_handshake_timeout, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_set_max_queued_packets : Void* = Pointer(Void).null
    def set_max_queued_packets(max_queued_packets : Int64) : Void
      godot_bind(@@mb_set_max_queued_packets, "WebSocketMultiplayerPeer", "set_max_queued_packets", 1286410249_i64)
      val_0 = max_queued_packets
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_max_queued_packets, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_max_queued_packets : Void* = Pointer(Void).null
    def get_max_queued_packets() : Int64
      godot_bind(@@mb_get_max_queued_packets, "WebSocketMultiplayerPeer", "get_max_queued_packets", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_max_queued_packets, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `supported_protocols` getter
    def supported_protocols
      get_supported_protocols
    end
    # Property `supported_protocols` setter
    def supported_protocols=(val)
      set_supported_protocols(val)
    end
    # Property `handshake_headers` getter
    def handshake_headers
      get_handshake_headers
    end
    # Property `handshake_headers` setter
    def handshake_headers=(val)
      set_handshake_headers(val)
    end
    # Property `inbound_buffer_size` getter
    def inbound_buffer_size
      get_inbound_buffer_size
    end
    # Property `inbound_buffer_size` setter
    def inbound_buffer_size=(val : Int)
      set_inbound_buffer_size(val.to_i64)
    end
    # Property `outbound_buffer_size` getter
    def outbound_buffer_size
      get_outbound_buffer_size
    end
    # Property `outbound_buffer_size` setter
    def outbound_buffer_size=(val : Int)
      set_outbound_buffer_size(val.to_i64)
    end
    # Property `handshake_timeout` getter
    def handshake_timeout
      get_handshake_timeout
    end
    # Property `handshake_timeout` setter
    def handshake_timeout=(val : Number)
      set_handshake_timeout(val.to_f64)
    end
    # Property `max_queued_packets` getter
    def max_queued_packets
      get_max_queued_packets
    end
    # Property `max_queued_packets` setter
    def max_queued_packets=(val : Int)
      set_max_queued_packets(val.to_i64)
    end
  end
  class WebSocketPeer < Godot::PacketPeer
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum WriteMode : Int64
      WriteModeText = 0_i64
      WriteModeBinary = 1_i64
    end
    enum State : Int64
      StateConnecting = 0_i64
      StateOpen = 1_i64
      StateClosing = 2_i64
      StateClosed = 3_i64
    end
    @@mb_connect_to_url : Void* = Pointer(Void).null
    def connect_to_url(url : String, tls_client_options : TLSOptions? = nil) : Godot::Error
      godot_bind(@@mb_connect_to_url, "WebSocketPeer", "connect_to_url", 1966198364_i64)
      str_0 = Bridge.make_string(url)
      arg_0 = str_0
      arg_ptr_1 = tls_client_options ? tls_client_options.pointer : Pointer(Void).null
      arg_1 = pointerof(arg_ptr_1).as(Void*)
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_connect_to_url, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_accept_stream : Void* = Pointer(Void).null
    def accept_stream(stream : StreamPeer) : Godot::Error
      godot_bind(@@mb_accept_stream, "WebSocketPeer", "accept_stream", 255125695_i64)
      arg_ptr_0 = stream ? stream.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_accept_stream, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_send : Void* = Pointer(Void).null
    def send(message : Pointer(Void), write_mode : WriteMode | Int = 1) : Godot::Error
      godot_bind(@@mb_send, "WebSocketPeer", "send", 2780360567_i64)
      val_0 = message
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = write_mode.is_a?(Int) ? write_mode.to_i64 : write_mode.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_send, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_send_text : Void* = Pointer(Void).null
    def send_text(message : String) : Godot::Error
      godot_bind(@@mb_send_text, "WebSocketPeer", "send_text", 166001499_i64)
      str_0 = Bridge.make_string(message)
      arg_0 = str_0
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_send_text, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_was_string_packet : Void* = Pointer(Void).null
    def was_string_packet() : Bool
      godot_bind(@@mb_was_string_packet, "WebSocketPeer", "was_string_packet", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_was_string_packet, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_poll : Void* = Pointer(Void).null
    def poll() : Void
      godot_bind(@@mb_poll, "WebSocketPeer", "poll", 3218959716_i64)
      godot_ptrcall(@@mb_poll, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_close : Void* = Pointer(Void).null
    def close(code : Int64 = 1000_i64, reason : String = "") : Void
      godot_bind(@@mb_close, "WebSocketPeer", "close", 1047156615_i64)
      val_0 = code
      arg_0 = pointerof(val_0).as(Void*)
      str_1 = Bridge.make_string(reason)
      arg_1 = str_1
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_close, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_1)
    end
    @@mb_get_connected_host : Void* = Pointer(Void).null
    def get_connected_host() : String
      godot_bind(@@mb_get_connected_host, "WebSocketPeer", "get_connected_host", 201670096_i64)
      godot_call_str("get_connected_host")
    end
    @@mb_get_connected_port : Void* = Pointer(Void).null
    def get_connected_port() : Int64
      godot_bind(@@mb_get_connected_port, "WebSocketPeer", "get_connected_port", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_connected_port, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_selected_protocol : Void* = Pointer(Void).null
    def get_selected_protocol() : String
      godot_bind(@@mb_get_selected_protocol, "WebSocketPeer", "get_selected_protocol", 201670096_i64)
      godot_call_str("get_selected_protocol")
    end
    @@mb_get_requested_url : Void* = Pointer(Void).null
    def get_requested_url() : String
      godot_bind(@@mb_get_requested_url, "WebSocketPeer", "get_requested_url", 201670096_i64)
      godot_call_str("get_requested_url")
    end
    @@mb_set_no_delay : Void* = Pointer(Void).null
    def set_no_delay(enabled : Bool) : Void
      godot_bind(@@mb_set_no_delay, "WebSocketPeer", "set_no_delay", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_no_delay, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_current_outbound_buffered_amount : Void* = Pointer(Void).null
    def get_current_outbound_buffered_amount() : Int64
      godot_bind(@@mb_get_current_outbound_buffered_amount, "WebSocketPeer", "get_current_outbound_buffered_amount", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_current_outbound_buffered_amount, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_ready_state : Void* = Pointer(Void).null
    def get_ready_state() : State
      godot_bind(@@mb_get_ready_state, "WebSocketPeer", "get_ready_state", 346482985_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_ready_state, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(State, ret)
    end
    @@mb_get_close_code : Void* = Pointer(Void).null
    def get_close_code() : Int64
      godot_bind(@@mb_get_close_code, "WebSocketPeer", "get_close_code", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_close_code, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_close_reason : Void* = Pointer(Void).null
    def get_close_reason() : String
      godot_bind(@@mb_get_close_reason, "WebSocketPeer", "get_close_reason", 201670096_i64)
      godot_call_str("get_close_reason")
    end
    @@mb_get_supported_protocols : Void* = Pointer(Void).null
    def get_supported_protocols() : Pointer(Void)
      godot_bind(@@mb_get_supported_protocols, "WebSocketPeer", "get_supported_protocols", 1139954409_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_supported_protocols, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_set_supported_protocols : Void* = Pointer(Void).null
    def set_supported_protocols(protocols : Pointer(Void)) : Void
      godot_bind(@@mb_set_supported_protocols, "WebSocketPeer", "set_supported_protocols", 4015028928_i64)
      val_0 = protocols
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_supported_protocols, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_handshake_headers : Void* = Pointer(Void).null
    def get_handshake_headers() : Pointer(Void)
      godot_bind(@@mb_get_handshake_headers, "WebSocketPeer", "get_handshake_headers", 1139954409_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_handshake_headers, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_set_handshake_headers : Void* = Pointer(Void).null
    def set_handshake_headers(protocols : Pointer(Void)) : Void
      godot_bind(@@mb_set_handshake_headers, "WebSocketPeer", "set_handshake_headers", 4015028928_i64)
      val_0 = protocols
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_handshake_headers, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_inbound_buffer_size : Void* = Pointer(Void).null
    def get_inbound_buffer_size() : Int64
      godot_bind(@@mb_get_inbound_buffer_size, "WebSocketPeer", "get_inbound_buffer_size", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_inbound_buffer_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_inbound_buffer_size : Void* = Pointer(Void).null
    def set_inbound_buffer_size(buffer_size : Int64) : Void
      godot_bind(@@mb_set_inbound_buffer_size, "WebSocketPeer", "set_inbound_buffer_size", 1286410249_i64)
      val_0 = buffer_size
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_inbound_buffer_size, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_outbound_buffer_size : Void* = Pointer(Void).null
    def get_outbound_buffer_size() : Int64
      godot_bind(@@mb_get_outbound_buffer_size, "WebSocketPeer", "get_outbound_buffer_size", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_outbound_buffer_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_outbound_buffer_size : Void* = Pointer(Void).null
    def set_outbound_buffer_size(buffer_size : Int64) : Void
      godot_bind(@@mb_set_outbound_buffer_size, "WebSocketPeer", "set_outbound_buffer_size", 1286410249_i64)
      val_0 = buffer_size
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_outbound_buffer_size, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_set_max_queued_packets : Void* = Pointer(Void).null
    def set_max_queued_packets(buffer_size : Int64) : Void
      godot_bind(@@mb_set_max_queued_packets, "WebSocketPeer", "set_max_queued_packets", 1286410249_i64)
      val_0 = buffer_size
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_max_queued_packets, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_max_queued_packets : Void* = Pointer(Void).null
    def get_max_queued_packets() : Int64
      godot_bind(@@mb_get_max_queued_packets, "WebSocketPeer", "get_max_queued_packets", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_max_queued_packets, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_heartbeat_interval : Void* = Pointer(Void).null
    def set_heartbeat_interval(interval : Float64) : Void
      godot_bind(@@mb_set_heartbeat_interval, "WebSocketPeer", "set_heartbeat_interval", 373806689_i64)
      val_0 = interval
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_heartbeat_interval, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_heartbeat_interval : Void* = Pointer(Void).null
    def get_heartbeat_interval() : Float64
      godot_bind(@@mb_get_heartbeat_interval, "WebSocketPeer", "get_heartbeat_interval", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_heartbeat_interval, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `supported_protocols` getter
    def supported_protocols
      get_supported_protocols
    end
    # Property `supported_protocols` setter
    def supported_protocols=(val)
      set_supported_protocols(val)
    end
    # Property `handshake_headers` getter
    def handshake_headers
      get_handshake_headers
    end
    # Property `handshake_headers` setter
    def handshake_headers=(val)
      set_handshake_headers(val)
    end
    # Property `inbound_buffer_size` getter
    def inbound_buffer_size
      get_inbound_buffer_size
    end
    # Property `inbound_buffer_size` setter
    def inbound_buffer_size=(val : Int)
      set_inbound_buffer_size(val.to_i64)
    end
    # Property `outbound_buffer_size` getter
    def outbound_buffer_size
      get_outbound_buffer_size
    end
    # Property `outbound_buffer_size` setter
    def outbound_buffer_size=(val : Int)
      set_outbound_buffer_size(val.to_i64)
    end
    # Property `max_queued_packets` getter
    def max_queued_packets
      get_max_queued_packets
    end
    # Property `max_queued_packets` setter
    def max_queued_packets=(val : Int)
      set_max_queued_packets(val.to_i64)
    end
    # Property `heartbeat_interval` getter
    def heartbeat_interval
      get_heartbeat_interval
    end
    # Property `heartbeat_interval` setter
    def heartbeat_interval=(val : Int)
      set_heartbeat_interval(val.to_i64)
    end
  end
  class WebXRInterface < Godot::XRInterface
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum TargetRayMode : Int64
      TargetRayModeUnknown = 0_i64
      TargetRayModeGaze = 1_i64
      TargetRayModeTrackedPointer = 2_i64
      TargetRayModeScreen = 3_i64
    end
    @@mb_is_session_supported : Void* = Pointer(Void).null
    def is_session_supported(session_mode : String) : Void
      godot_bind(@@mb_is_session_supported, "WebXRInterface", "is_session_supported", 83702148_i64)
      str_0 = Bridge.make_string(session_mode)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_is_session_supported, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_set_session_mode : Void* = Pointer(Void).null
    def set_session_mode(session_mode : String) : Void
      godot_bind(@@mb_set_session_mode, "WebXRInterface", "set_session_mode", 83702148_i64)
      str_0 = Bridge.make_string(session_mode)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_session_mode, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_session_mode : Void* = Pointer(Void).null
    def get_session_mode() : String
      godot_bind(@@mb_get_session_mode, "WebXRInterface", "get_session_mode", 201670096_i64)
      godot_call_str("get_session_mode")
    end
    @@mb_set_required_features : Void* = Pointer(Void).null
    def set_required_features(required_features : String) : Void
      godot_bind(@@mb_set_required_features, "WebXRInterface", "set_required_features", 83702148_i64)
      str_0 = Bridge.make_string(required_features)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_required_features, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_required_features : Void* = Pointer(Void).null
    def get_required_features() : String
      godot_bind(@@mb_get_required_features, "WebXRInterface", "get_required_features", 201670096_i64)
      godot_call_str("get_required_features")
    end
    @@mb_set_optional_features : Void* = Pointer(Void).null
    def set_optional_features(optional_features : String) : Void
      godot_bind(@@mb_set_optional_features, "WebXRInterface", "set_optional_features", 83702148_i64)
      str_0 = Bridge.make_string(optional_features)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_optional_features, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_optional_features : Void* = Pointer(Void).null
    def get_optional_features() : String
      godot_bind(@@mb_get_optional_features, "WebXRInterface", "get_optional_features", 201670096_i64)
      godot_call_str("get_optional_features")
    end
    @@mb_get_reference_space_type : Void* = Pointer(Void).null
    def get_reference_space_type() : String
      godot_bind(@@mb_get_reference_space_type, "WebXRInterface", "get_reference_space_type", 201670096_i64)
      godot_call_str("get_reference_space_type")
    end
    @@mb_get_enabled_features : Void* = Pointer(Void).null
    def get_enabled_features() : String
      godot_bind(@@mb_get_enabled_features, "WebXRInterface", "get_enabled_features", 201670096_i64)
      godot_call_str("get_enabled_features")
    end
    @@mb_set_requested_reference_space_types : Void* = Pointer(Void).null
    def set_requested_reference_space_types(requested_reference_space_types : String) : Void
      godot_bind(@@mb_set_requested_reference_space_types, "WebXRInterface", "set_requested_reference_space_types", 83702148_i64)
      str_0 = Bridge.make_string(requested_reference_space_types)
      arg_0 = str_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_requested_reference_space_types, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_requested_reference_space_types : Void* = Pointer(Void).null
    def get_requested_reference_space_types() : String
      godot_bind(@@mb_get_requested_reference_space_types, "WebXRInterface", "get_requested_reference_space_types", 201670096_i64)
      godot_call_str("get_requested_reference_space_types")
    end
    @@mb_is_input_source_active : Void* = Pointer(Void).null
    def is_input_source_active(input_source_id : Int64) : Bool
      godot_bind(@@mb_is_input_source_active, "WebXRInterface", "is_input_source_active", 1116898809_i64)
      val_0 = input_source_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_is_input_source_active, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_input_source_tracker : Void* = Pointer(Void).null
    def get_input_source_tracker(input_source_id : Int64) : XRControllerTracker
      godot_bind(@@mb_get_input_source_tracker, "WebXRInterface", "get_input_source_tracker", 399776966_i64)
      val_0 = input_source_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_input_source_tracker, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      godot_return_obj(XRControllerTracker, ret_ptr)
    end
    @@mb_get_input_source_target_ray_mode : Void* = Pointer(Void).null
    def get_input_source_target_ray_mode(input_source_id : Int64) : TargetRayMode
      godot_bind(@@mb_get_input_source_target_ray_mode, "WebXRInterface", "get_input_source_target_ray_mode", 2852387453_i64)
      val_0 = input_source_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_input_source_target_ray_mode, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(TargetRayMode, ret)
    end
    @@mb_get_visibility_state : Void* = Pointer(Void).null
    def get_visibility_state() : String
      godot_bind(@@mb_get_visibility_state, "WebXRInterface", "get_visibility_state", 201670096_i64)
      godot_call_str("get_visibility_state")
    end
    @@mb_get_display_refresh_rate : Void* = Pointer(Void).null
    def get_display_refresh_rate() : Float64
      godot_bind(@@mb_get_display_refresh_rate, "WebXRInterface", "get_display_refresh_rate", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_display_refresh_rate, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_display_refresh_rate : Void* = Pointer(Void).null
    def set_display_refresh_rate(refresh_rate : Float64) : Void
      godot_bind(@@mb_set_display_refresh_rate, "WebXRInterface", "set_display_refresh_rate", 373806689_i64)
      val_0 = refresh_rate
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_display_refresh_rate, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_available_display_refresh_rates : Void* = Pointer(Void).null
    def get_available_display_refresh_rates() : Pointer(Void)
      godot_bind(@@mb_get_available_display_refresh_rates, "WebXRInterface", "get_available_display_refresh_rates", 3995934104_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_available_display_refresh_rates, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    # Property `session_mode` getter
    def session_mode
      get_session_mode
    end
    # Property `session_mode` setter
    def session_mode=(val)
      set_session_mode(val)
    end
    # Property `required_features` getter
    def required_features
      get_required_features
    end
    # Property `required_features` setter
    def required_features=(val)
      set_required_features(val)
    end
    # Property `optional_features` getter
    def optional_features
      get_optional_features
    end
    # Property `optional_features` setter
    def optional_features=(val)
      set_optional_features(val)
    end
    # Property `requested_reference_space_types` getter
    def requested_reference_space_types
      get_requested_reference_space_types
    end
    # Property `requested_reference_space_types` setter
    def requested_reference_space_types=(val)
      set_requested_reference_space_types(val)
    end
    # Property `reference_space_type` getter
    def reference_space_type
      get_reference_space_type
    end
    # Property `enabled_features` getter
    def enabled_features
      get_enabled_features
    end
    # Property `visibility_state` getter
    def visibility_state
      get_visibility_state
    end
    godot_signal session_supported, String, Bool
    godot_signal session_started
    godot_signal session_ended
    godot_signal session_failed, String
    godot_signal selectstart, Int64
    godot_signal selectend, Int64
    godot_signal squeezestart, Int64
    godot_signal squeeze, Int64
    godot_signal squeezeend, Int64
    godot_signal visibility_state_changed
    godot_signal reference_space_reset
    godot_signal display_refresh_rate_changed
  end
  class WorkerThreadPool < Godot::Object
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_add_task : Void* = Pointer(Void).null
    def add_task(action : Pointer(Void), high_priority : Bool = false, description : String = "") : Int64
      godot_bind(@@mb_add_task, "WorkerThreadPool", "add_task", 3745067146_i64)
      val_0 = action
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = high_priority
      arg_1 = pointerof(val_1).as(Void*)
      str_2 = Bridge.make_string(description)
      arg_2 = str_2
      args = [arg_0, arg_1, arg_2]
      ret = 0_i64
      godot_ptrcall(@@mb_add_task, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    ensure
      Bridge.free_string(str_2)
    end
    @@mb_is_task_completed : Void* = Pointer(Void).null
    def is_task_completed(task_id : Int64) : Bool
      godot_bind(@@mb_is_task_completed, "WorkerThreadPool", "is_task_completed", 1116898809_i64)
      val_0 = task_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_is_task_completed, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_wait_for_task_completion : Void* = Pointer(Void).null
    def wait_for_task_completion(task_id : Int64) : Godot::Error
      godot_bind(@@mb_wait_for_task_completion, "WorkerThreadPool", "wait_for_task_completion", 844576869_i64)
      val_0 = task_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_wait_for_task_completion, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_get_caller_task_id : Void* = Pointer(Void).null
    def get_caller_task_id() : Int64
      godot_bind(@@mb_get_caller_task_id, "WorkerThreadPool", "get_caller_task_id", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_caller_task_id, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_add_group_task : Void* = Pointer(Void).null
    def add_group_task(action : Pointer(Void), elements : Int64, tasks_needed : Int64 = -1_i64, high_priority : Bool = false, description : String = "") : Int64
      godot_bind(@@mb_add_group_task, "WorkerThreadPool", "add_group_task", 1801953219_i64)
      val_0 = action
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = elements
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = tasks_needed
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = high_priority
      arg_3 = pointerof(val_3).as(Void*)
      str_4 = Bridge.make_string(description)
      arg_4 = str_4
      args = [arg_0, arg_1, arg_2, arg_3, arg_4]
      ret = 0_i64
      godot_ptrcall(@@mb_add_group_task, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    ensure
      Bridge.free_string(str_4)
    end
    @@mb_is_group_task_completed : Void* = Pointer(Void).null
    def is_group_task_completed(group_id : Int64) : Bool
      godot_bind(@@mb_is_group_task_completed, "WorkerThreadPool", "is_group_task_completed", 1116898809_i64)
      val_0 = group_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_is_group_task_completed, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_group_processed_element_count : Void* = Pointer(Void).null
    def get_group_processed_element_count(group_id : Int64) : Int64
      godot_bind(@@mb_get_group_processed_element_count, "WorkerThreadPool", "get_group_processed_element_count", 923996154_i64)
      val_0 = group_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_group_processed_element_count, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_wait_for_group_task_completion : Void* = Pointer(Void).null
    def wait_for_group_task_completion(group_id : Int64) : Void
      godot_bind(@@mb_wait_for_group_task_completion, "WorkerThreadPool", "wait_for_group_task_completion", 1286410249_i64)
      val_0 = group_id
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_wait_for_group_task_completion, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_caller_group_id : Void* = Pointer(Void).null
    def get_caller_group_id() : Int64
      godot_bind(@@mb_get_caller_group_id, "WorkerThreadPool", "get_caller_group_id", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_caller_group_id, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
  end
  class World2D < Godot::Resource
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_get_canvas : Void* = Pointer(Void).null
    def get_canvas() : Int64
      godot_bind(@@mb_get_canvas, "World2D", "get_canvas", 2944877500_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_canvas, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_navigation_map : Void* = Pointer(Void).null
    def get_navigation_map() : Int64
      godot_bind(@@mb_get_navigation_map, "World2D", "get_navigation_map", 2944877500_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_navigation_map, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_space : Void* = Pointer(Void).null
    def get_space() : Int64
      godot_bind(@@mb_get_space, "World2D", "get_space", 2944877500_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_space, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_direct_space_state : Void* = Pointer(Void).null
    def get_direct_space_state() : PhysicsDirectSpaceState2D
      godot_bind(@@mb_get_direct_space_state, "World2D", "get_direct_space_state", 2506717822_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_direct_space_state, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(PhysicsDirectSpaceState2D, ret_ptr)
    end
    # Property `canvas` getter
    def canvas
      get_canvas
    end
    # Property `navigation_map` getter
    def navigation_map
      get_navigation_map
    end
    # Property `space` getter
    def space
      get_space
    end
    # Property `direct_space_state` getter
    def direct_space_state
      get_direct_space_state
    end
  end
  class World3D < Godot::Resource
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_get_space : Void* = Pointer(Void).null
    def get_space() : Int64
      godot_bind(@@mb_get_space, "World3D", "get_space", 2944877500_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_space, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_navigation_map : Void* = Pointer(Void).null
    def get_navigation_map() : Int64
      godot_bind(@@mb_get_navigation_map, "World3D", "get_navigation_map", 2944877500_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_navigation_map, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_scenario : Void* = Pointer(Void).null
    def get_scenario() : Int64
      godot_bind(@@mb_get_scenario, "World3D", "get_scenario", 2944877500_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_scenario, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_environment : Void* = Pointer(Void).null
    def set_environment(env : Environment) : Void
      godot_bind(@@mb_set_environment, "World3D", "set_environment", 4143518816_i64)
      arg_ptr_0 = env ? env.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_environment, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_environment : Void* = Pointer(Void).null
    def get_environment() : Environment
      godot_bind(@@mb_get_environment, "World3D", "get_environment", 3082064660_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_environment, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Environment, ret_ptr)
    end
    @@mb_set_fallback_environment : Void* = Pointer(Void).null
    def set_fallback_environment(env : Environment) : Void
      godot_bind(@@mb_set_fallback_environment, "World3D", "set_fallback_environment", 4143518816_i64)
      arg_ptr_0 = env ? env.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_fallback_environment, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_fallback_environment : Void* = Pointer(Void).null
    def get_fallback_environment() : Environment
      godot_bind(@@mb_get_fallback_environment, "World3D", "get_fallback_environment", 3082064660_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_fallback_environment, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Environment, ret_ptr)
    end
    @@mb_set_camera_attributes : Void* = Pointer(Void).null
    def set_camera_attributes(attributes : CameraAttributes) : Void
      godot_bind(@@mb_set_camera_attributes, "World3D", "set_camera_attributes", 2817810567_i64)
      arg_ptr_0 = attributes ? attributes.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_camera_attributes, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_camera_attributes : Void* = Pointer(Void).null
    def get_camera_attributes() : CameraAttributes
      godot_bind(@@mb_get_camera_attributes, "World3D", "get_camera_attributes", 3921283215_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_camera_attributes, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(CameraAttributes, ret_ptr)
    end
    @@mb_get_direct_space_state : Void* = Pointer(Void).null
    def get_direct_space_state() : PhysicsDirectSpaceState3D
      godot_bind(@@mb_get_direct_space_state, "World3D", "get_direct_space_state", 2069328350_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_direct_space_state, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(PhysicsDirectSpaceState3D, ret_ptr)
    end
    # Property `environment` getter
    def environment
      get_environment
    end
    # Property `environment` setter
    def environment=(val)
      set_environment(val)
    end
    # Property `fallback_environment` getter
    def fallback_environment
      get_fallback_environment
    end
    # Property `fallback_environment` setter
    def fallback_environment=(val)
      set_fallback_environment(val)
    end
    # Property `camera_attributes` getter
    def camera_attributes
      get_camera_attributes
    end
    # Property `camera_attributes` setter
    def camera_attributes=(val)
      set_camera_attributes(val)
    end
    # Property `space` getter
    def space
      get_space
    end
    # Property `navigation_map` getter
    def navigation_map
      get_navigation_map
    end
    # Property `scenario` getter
    def scenario
      get_scenario
    end
    # Property `direct_space_state` getter
    def direct_space_state
      get_direct_space_state
    end
  end
  class WorldBoundaryShape2D < Godot::Shape2D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_normal : Void* = Pointer(Void).null
    def set_normal(normal : Vector2) : Void
      godot_bind(@@mb_set_normal, "WorldBoundaryShape2D", "set_normal", 743155724_i64)
      val_0 = normal
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_normal, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_normal : Void* = Pointer(Void).null
    def get_normal() : Vector2
      godot_bind(@@mb_get_normal, "WorldBoundaryShape2D", "get_normal", 3341600327_i64)
      ret = Vector2.new
      godot_ptrcall(@@mb_get_normal, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_distance : Void* = Pointer(Void).null
    def set_distance(distance : Float64) : Void
      godot_bind(@@mb_set_distance, "WorldBoundaryShape2D", "set_distance", 373806689_i64)
      val_0 = distance
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_distance, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_distance : Void* = Pointer(Void).null
    def get_distance() : Float64
      godot_bind(@@mb_get_distance, "WorldBoundaryShape2D", "get_distance", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_distance, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    # Property `normal` getter
    def normal
      get_normal
    end
    # Property `normal` setter
    def normal=(val)
      set_normal(val)
    end
    # Property `distance` getter
    def distance
      get_distance
    end
    # Property `distance` setter
    def distance=(val : Number)
      set_distance(val.to_f64)
    end
  end
  class WorldBoundaryShape3D < Godot::Shape3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_plane : Void* = Pointer(Void).null
    def set_plane(plane : Plane) : Void
      godot_bind(@@mb_set_plane, "WorldBoundaryShape3D", "set_plane", 3505987427_i64)
      val_0 = plane
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_plane, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_plane : Void* = Pointer(Void).null
    def get_plane() : Plane
      godot_bind(@@mb_get_plane, "WorldBoundaryShape3D", "get_plane", 2753500971_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_plane, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Plane, ret_ptr)
    end
    # Property `plane` getter
    def plane
      get_plane
    end
    # Property `plane` setter
    def plane=(val)
      set_plane(val)
    end
  end
  class WorldEnvironment < Godot::Node
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_environment : Void* = Pointer(Void).null
    def set_environment(env : Environment) : Void
      godot_bind(@@mb_set_environment, "WorldEnvironment", "set_environment", 4143518816_i64)
      arg_ptr_0 = env ? env.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_environment, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_environment : Void* = Pointer(Void).null
    def get_environment() : Environment
      godot_bind(@@mb_get_environment, "WorldEnvironment", "get_environment", 3082064660_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_environment, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Environment, ret_ptr)
    end
    @@mb_set_camera_attributes : Void* = Pointer(Void).null
    def set_camera_attributes(camera_attributes : CameraAttributes) : Void
      godot_bind(@@mb_set_camera_attributes, "WorldEnvironment", "set_camera_attributes", 2817810567_i64)
      arg_ptr_0 = camera_attributes ? camera_attributes.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_camera_attributes, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_camera_attributes : Void* = Pointer(Void).null
    def get_camera_attributes() : CameraAttributes
      godot_bind(@@mb_get_camera_attributes, "WorldEnvironment", "get_camera_attributes", 3921283215_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_camera_attributes, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(CameraAttributes, ret_ptr)
    end
    @@mb_set_compositor : Void* = Pointer(Void).null
    def set_compositor(compositor : Compositor) : Void
      godot_bind(@@mb_set_compositor, "WorldEnvironment", "set_compositor", 1586754307_i64)
      arg_ptr_0 = compositor ? compositor.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_compositor, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_compositor : Void* = Pointer(Void).null
    def get_compositor() : Compositor
      godot_bind(@@mb_get_compositor, "WorldEnvironment", "get_compositor", 3647707413_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_compositor, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Compositor, ret_ptr)
    end
    # Property `environment` getter
    def environment
      get_environment
    end
    # Property `environment` setter
    def environment=(val)
      set_environment(val)
    end
    # Property `camera_attributes` getter
    def camera_attributes
      get_camera_attributes
    end
    # Property `camera_attributes` setter
    def camera_attributes=(val)
      set_camera_attributes(val)
    end
    # Property `compositor` getter
    def compositor
      get_compositor
    end
    # Property `compositor` setter
    def compositor=(val)
      set_compositor(val)
    end
  end
  class X509Certificate < Godot::Resource
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_save : Void* = Pointer(Void).null
    def save(path : String) : Godot::Error
      godot_bind(@@mb_save, "X509Certificate", "save", 166001499_i64)
      str_0 = Bridge.make_string(path)
      arg_0 = str_0
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_save, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_load : Void* = Pointer(Void).null
    def load(path : String) : Godot::Error
      godot_bind(@@mb_load, "X509Certificate", "load", 166001499_i64)
      str_0 = Bridge.make_string(path)
      arg_0 = str_0
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_load, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_save_to_string : Void* = Pointer(Void).null
    def save_to_string() : String
      godot_bind(@@mb_save_to_string, "X509Certificate", "save_to_string", 2841200299_i64)
      godot_call_str("save_to_string")
    end
    @@mb_load_from_string : Void* = Pointer(Void).null
    def load_from_string(string : String) : Godot::Error
      godot_bind(@@mb_load_from_string, "X509Certificate", "load_from_string", 166001499_i64)
      str_0 = Bridge.make_string(string)
      arg_0 = str_0
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_load_from_string, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
  end
  class XMLParser < Godot::RefCounted
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum NodeType : Int64
      NodeNone = 0_i64
      NodeElement = 1_i64
      NodeElementEnd = 2_i64
      NodeText = 3_i64
      NodeComment = 4_i64
      NodeCdata = 5_i64
      NodeUnknown = 6_i64
    end
    @@mb_read : Void* = Pointer(Void).null
    def read() : Godot::Error
      godot_bind(@@mb_read, "XMLParser", "read", 166280745_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_read, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_get_node_type : Void* = Pointer(Void).null
    def get_node_type() : NodeType
      godot_bind(@@mb_get_node_type, "XMLParser", "get_node_type", 2984359541_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_node_type, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(NodeType, ret)
    end
    @@mb_get_node_name : Void* = Pointer(Void).null
    def get_node_name() : String
      godot_bind(@@mb_get_node_name, "XMLParser", "get_node_name", 201670096_i64)
      godot_call_str("get_node_name")
    end
    @@mb_get_node_data : Void* = Pointer(Void).null
    def get_node_data() : String
      godot_bind(@@mb_get_node_data, "XMLParser", "get_node_data", 201670096_i64)
      godot_call_str("get_node_data")
    end
    @@mb_get_node_offset : Void* = Pointer(Void).null
    def get_node_offset() : Int64
      godot_bind(@@mb_get_node_offset, "XMLParser", "get_node_offset", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_node_offset, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_attribute_count : Void* = Pointer(Void).null
    def get_attribute_count() : Int64
      godot_bind(@@mb_get_attribute_count, "XMLParser", "get_attribute_count", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_attribute_count, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_attribute_name : Void* = Pointer(Void).null
    def get_attribute_name(idx : Int64) : String
      godot_bind(@@mb_get_attribute_name, "XMLParser", "get_attribute_name", 844755477_i64)
      val_0 = idx
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_call_str("get_attribute_name", idx)
    end
    @@mb_get_attribute_value : Void* = Pointer(Void).null
    def get_attribute_value(idx : Int64) : String
      godot_bind(@@mb_get_attribute_value, "XMLParser", "get_attribute_value", 844755477_i64)
      val_0 = idx
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_call_str("get_attribute_value", idx)
    end
    @@mb_has_attribute : Void* = Pointer(Void).null
    def has_attribute(name : String) : Bool
      godot_bind(@@mb_has_attribute, "XMLParser", "has_attribute", 3927539163_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_has_attribute, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_named_attribute_value : Void* = Pointer(Void).null
    def get_named_attribute_value(name : String) : String
      godot_bind(@@mb_get_named_attribute_value, "XMLParser", "get_named_attribute_value", 3135753539_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      godot_call_str("get_named_attribute_value", name)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_named_attribute_value_safe : Void* = Pointer(Void).null
    def get_named_attribute_value_safe(name : String) : String
      godot_bind(@@mb_get_named_attribute_value_safe, "XMLParser", "get_named_attribute_value_safe", 3135753539_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      godot_call_str("get_named_attribute_value_safe", name)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_is_empty : Void* = Pointer(Void).null
    def is_empty() : Bool
      godot_bind(@@mb_is_empty, "XMLParser", "is_empty", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_empty, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_current_line : Void* = Pointer(Void).null
    def get_current_line() : Int64
      godot_bind(@@mb_get_current_line, "XMLParser", "get_current_line", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_current_line, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_skip_section : Void* = Pointer(Void).null
    def skip_section() : Void
      godot_bind(@@mb_skip_section, "XMLParser", "skip_section", 3218959716_i64)
      godot_ptrcall(@@mb_skip_section, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_seek : Void* = Pointer(Void).null
    def seek(position : Int64) : Godot::Error
      godot_bind(@@mb_seek, "XMLParser", "seek", 844576869_i64)
      val_0 = position
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_seek, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_open : Void* = Pointer(Void).null
    def open(file : String) : Godot::Error
      godot_bind(@@mb_open, "XMLParser", "open", 166001499_i64)
      str_0 = Bridge.make_string(file)
      arg_0 = str_0
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_open, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_open_buffer : Void* = Pointer(Void).null
    def open_buffer(buffer : Pointer(Void)) : Godot::Error
      godot_bind(@@mb_open_buffer, "XMLParser", "open_buffer", 680677267_i64)
      val_0 = buffer
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_open_buffer, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
  end
  class XRNode3D < Godot::Node3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_tracker : Void* = Pointer(Void).null
    def set_tracker(tracker_name : String) : Void
      godot_bind(@@mb_set_tracker, "XRNode3D", "set_tracker", 3304788590_i64)
      sn_0 = Bridge.make_string_name(tracker_name)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_tracker, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_tracker : Void* = Pointer(Void).null
    def get_tracker() : String
      godot_bind(@@mb_get_tracker, "XRNode3D", "get_tracker", 2002593661_i64)
      godot_call_str("get_tracker")
    end
    @@mb_set_pose_name : Void* = Pointer(Void).null
    def set_pose_name(pose : String) : Void
      godot_bind(@@mb_set_pose_name, "XRNode3D", "set_pose_name", 3304788590_i64)
      sn_0 = Bridge.make_string_name(pose)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_pose_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_pose_name : Void* = Pointer(Void).null
    def get_pose_name() : String
      godot_bind(@@mb_get_pose_name, "XRNode3D", "get_pose_name", 2002593661_i64)
      godot_call_str("get_pose_name")
    end
    @@mb_set_show_when_tracked : Void* = Pointer(Void).null
    def set_show_when_tracked(show : Bool) : Void
      godot_bind(@@mb_set_show_when_tracked, "XRNode3D", "set_show_when_tracked", 2586408642_i64)
      val_0 = show
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_show_when_tracked, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_show_when_tracked : Void* = Pointer(Void).null
    def get_show_when_tracked() : Bool
      godot_bind(@@mb_get_show_when_tracked, "XRNode3D", "get_show_when_tracked", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_get_show_when_tracked, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_is_active : Void* = Pointer(Void).null
    def get_is_active() : Bool
      godot_bind(@@mb_get_is_active, "XRNode3D", "get_is_active", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_get_is_active, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_has_tracking_data : Void* = Pointer(Void).null
    def get_has_tracking_data() : Bool
      godot_bind(@@mb_get_has_tracking_data, "XRNode3D", "get_has_tracking_data", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_get_has_tracking_data, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_get_pose : Void* = Pointer(Void).null
    def get_pose() : XRPose
      godot_bind(@@mb_get_pose, "XRNode3D", "get_pose", 2806551826_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_pose, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(XRPose, ret_ptr)
    end
    @@mb_trigger_haptic_pulse : Void* = Pointer(Void).null
    def trigger_haptic_pulse(action_name : String, frequency : Float64, amplitude : Float64, duration_sec : Float64, delay_sec : Float64) : Void
      godot_bind(@@mb_trigger_haptic_pulse, "XRNode3D", "trigger_haptic_pulse", 508576839_i64)
      str_0 = Bridge.make_string(action_name)
      arg_0 = str_0
      val_1 = frequency
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = amplitude
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = duration_sec
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = delay_sec
      arg_4 = pointerof(val_4).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3, arg_4]
      godot_ptrcall(@@mb_trigger_haptic_pulse, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string(str_0)
    end
    # Property `tracker` getter
    def tracker
      get_tracker
    end
    # Property `tracker` setter
    def tracker=(val)
      set_tracker(val)
    end
    # Property `pose` getter
    def pose
      get_pose_name
    end
    # Property `pose` setter
    def pose=(val)
      set_pose_name(val)
    end
    # Property `show_when_tracked` getter
    def show_when_tracked
      get_show_when_tracked
    end
    def show_when_tracked?
      show_when_tracked
    end
    # Property `show_when_tracked` setter
    def show_when_tracked=(val)
      set_show_when_tracked(val)
    end
    godot_signal tracking_changed, Bool
  end
  class XRAnchor3D < Godot::XRNode3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_get_size : Void* = Pointer(Void).null
    def get_size() : Vector3
      godot_bind(@@mb_get_size, "XRAnchor3D", "get_size", 3360562783_i64)
      ret = Vector3.new
      godot_ptrcall(@@mb_get_size, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_plane : Void* = Pointer(Void).null
    def get_plane() : Plane
      godot_bind(@@mb_get_plane, "XRAnchor3D", "get_plane", 2753500971_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_plane, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Plane, ret_ptr)
    end
  end
  class XRBodyModifier3D < Godot::SkeletonModifier3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum BodyUpdate : Int64
      BodyUpdateUpperBody = 1_i64
      BodyUpdateLowerBody = 2_i64
      BodyUpdateHands = 4_i64
    end
    enum BoneUpdate : Int64
      BoneUpdateFull = 0_i64
      BoneUpdateRotationOnly = 1_i64
      BoneUpdateMax = 2_i64
    end
    @@mb_set_body_tracker : Void* = Pointer(Void).null
    def set_body_tracker(tracker_name : String) : Void
      godot_bind(@@mb_set_body_tracker, "XRBodyModifier3D", "set_body_tracker", 3304788590_i64)
      sn_0 = Bridge.make_string_name(tracker_name)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_body_tracker, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_body_tracker : Void* = Pointer(Void).null
    def get_body_tracker() : String
      godot_bind(@@mb_get_body_tracker, "XRBodyModifier3D", "get_body_tracker", 2002593661_i64)
      godot_call_str("get_body_tracker")
    end
    @@mb_set_body_update : Void* = Pointer(Void).null
    def set_body_update(body_update : BodyUpdate | Int) : Void
      godot_bind(@@mb_set_body_update, "XRBodyModifier3D", "set_body_update", 2211199417_i64)
      val_0 = body_update.is_a?(Int) ? body_update.to_i64 : body_update.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_body_update, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_body_update : Void* = Pointer(Void).null
    def get_body_update() : BodyUpdate
      godot_bind(@@mb_get_body_update, "XRBodyModifier3D", "get_body_update", 2642335328_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_body_update, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(BodyUpdate, ret)
    end
    @@mb_set_bone_update : Void* = Pointer(Void).null
    def set_bone_update(bone_update : BoneUpdate | Int) : Void
      godot_bind(@@mb_set_bone_update, "XRBodyModifier3D", "set_bone_update", 3356796943_i64)
      val_0 = bone_update.is_a?(Int) ? bone_update.to_i64 : bone_update.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_bone_update, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_bone_update : Void* = Pointer(Void).null
    def get_bone_update() : BoneUpdate
      godot_bind(@@mb_get_bone_update, "XRBodyModifier3D", "get_bone_update", 1309305964_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_bone_update, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(BoneUpdate, ret)
    end
    # Property `body_tracker` getter
    def body_tracker
      get_body_tracker
    end
    # Property `body_tracker` setter
    def body_tracker=(val)
      set_body_tracker(val)
    end
    # Property `body_update` getter
    def body_update
      get_body_update
    end
    # Property `body_update` setter
    def body_update=(val : Int)
      set_body_update(val.to_i64)
    end
    # Property `bone_update` getter
    def bone_update
      get_bone_update
    end
    # Property `bone_update` setter
    def bone_update=(val : Int)
      set_bone_update(val.to_i64)
    end
  end
  class XRBodyTracker < Godot::XRPositionalTracker
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum BodyFlags : Int64
      BodyFlagUpperBodySupported = 1_i64
      BodyFlagLowerBodySupported = 2_i64
      BodyFlagHandsSupported = 4_i64
    end
    enum Joint : Int64
      JointRoot = 0_i64
      JointHips = 1_i64
      JointSpine = 2_i64
      JointChest = 3_i64
      JointUpperChest = 4_i64
      JointNeck = 5_i64
      JointHead = 6_i64
      JointHeadTip = 7_i64
      JointLeftShoulder = 8_i64
      JointLeftUpperArm = 9_i64
      JointLeftLowerArm = 10_i64
      JointRightShoulder = 11_i64
      JointRightUpperArm = 12_i64
      JointRightLowerArm = 13_i64
      JointLeftUpperLeg = 14_i64
      JointLeftLowerLeg = 15_i64
      JointLeftFoot = 16_i64
      JointLeftToes = 17_i64
      JointRightUpperLeg = 18_i64
      JointRightLowerLeg = 19_i64
      JointRightFoot = 20_i64
      JointRightToes = 21_i64
      JointLeftHand = 22_i64
      JointLeftPalm = 23_i64
      JointLeftWrist = 24_i64
      JointLeftThumbMetacarpal = 25_i64
      JointLeftThumbPhalanxProximal = 26_i64
      JointLeftThumbPhalanxDistal = 27_i64
      JointLeftThumbTip = 28_i64
      JointLeftIndexFingerMetacarpal = 29_i64
      JointLeftIndexFingerPhalanxProximal = 30_i64
      JointLeftIndexFingerPhalanxIntermediate = 31_i64
      JointLeftIndexFingerPhalanxDistal = 32_i64
      JointLeftIndexFingerTip = 33_i64
      JointLeftMiddleFingerMetacarpal = 34_i64
      JointLeftMiddleFingerPhalanxProximal = 35_i64
      JointLeftMiddleFingerPhalanxIntermediate = 36_i64
      JointLeftMiddleFingerPhalanxDistal = 37_i64
      JointLeftMiddleFingerTip = 38_i64
      JointLeftRingFingerMetacarpal = 39_i64
      JointLeftRingFingerPhalanxProximal = 40_i64
      JointLeftRingFingerPhalanxIntermediate = 41_i64
      JointLeftRingFingerPhalanxDistal = 42_i64
      JointLeftRingFingerTip = 43_i64
      JointLeftPinkyFingerMetacarpal = 44_i64
      JointLeftPinkyFingerPhalanxProximal = 45_i64
      JointLeftPinkyFingerPhalanxIntermediate = 46_i64
      JointLeftPinkyFingerPhalanxDistal = 47_i64
      JointLeftPinkyFingerTip = 48_i64
      JointRightHand = 49_i64
      JointRightPalm = 50_i64
      JointRightWrist = 51_i64
      JointRightThumbMetacarpal = 52_i64
      JointRightThumbPhalanxProximal = 53_i64
      JointRightThumbPhalanxDistal = 54_i64
      JointRightThumbTip = 55_i64
      JointRightIndexFingerMetacarpal = 56_i64
      JointRightIndexFingerPhalanxProximal = 57_i64
      JointRightIndexFingerPhalanxIntermediate = 58_i64
      JointRightIndexFingerPhalanxDistal = 59_i64
      JointRightIndexFingerTip = 60_i64
      JointRightMiddleFingerMetacarpal = 61_i64
      JointRightMiddleFingerPhalanxProximal = 62_i64
      JointRightMiddleFingerPhalanxIntermediate = 63_i64
      JointRightMiddleFingerPhalanxDistal = 64_i64
      JointRightMiddleFingerTip = 65_i64
      JointRightRingFingerMetacarpal = 66_i64
      JointRightRingFingerPhalanxProximal = 67_i64
      JointRightRingFingerPhalanxIntermediate = 68_i64
      JointRightRingFingerPhalanxDistal = 69_i64
      JointRightRingFingerTip = 70_i64
      JointRightPinkyFingerMetacarpal = 71_i64
      JointRightPinkyFingerPhalanxProximal = 72_i64
      JointRightPinkyFingerPhalanxIntermediate = 73_i64
      JointRightPinkyFingerPhalanxDistal = 74_i64
      JointRightPinkyFingerTip = 75_i64
      JointLowerChest = 76_i64
      JointLeftScapula = 77_i64
      JointLeftWristTwist = 78_i64
      JointRightScapula = 79_i64
      JointRightWristTwist = 80_i64
      JointLeftFootTwist = 81_i64
      JointLeftHeel = 82_i64
      JointLeftMiddleFoot = 83_i64
      JointRightFootTwist = 84_i64
      JointRightHeel = 85_i64
      JointRightMiddleFoot = 86_i64
      JointMax = 87_i64
    end
    enum JointFlags : Int64
      JointFlagOrientationValid = 1_i64
      JointFlagOrientationTracked = 2_i64
      JointFlagPositionValid = 4_i64
      JointFlagPositionTracked = 8_i64
    end
    @@mb_set_has_tracking_data : Void* = Pointer(Void).null
    def set_has_tracking_data(has_data : Bool) : Void
      godot_bind(@@mb_set_has_tracking_data, "XRBodyTracker", "set_has_tracking_data", 2586408642_i64)
      val_0 = has_data
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_has_tracking_data, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_has_tracking_data : Void* = Pointer(Void).null
    def get_has_tracking_data() : Bool
      godot_bind(@@mb_get_has_tracking_data, "XRBodyTracker", "get_has_tracking_data", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_get_has_tracking_data, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_body_flags : Void* = Pointer(Void).null
    def set_body_flags(flags : BodyFlags | Int) : Void
      godot_bind(@@mb_set_body_flags, "XRBodyTracker", "set_body_flags", 2103235750_i64)
      val_0 = flags.is_a?(Int) ? flags.to_i64 : flags.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_body_flags, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_body_flags : Void* = Pointer(Void).null
    def get_body_flags() : BodyFlags
      godot_bind(@@mb_get_body_flags, "XRBodyTracker", "get_body_flags", 3543166366_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_body_flags, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(BodyFlags, ret)
    end
    @@mb_set_joint_flags : Void* = Pointer(Void).null
    def set_joint_flags(joint : Joint | Int, flags : JointFlags | Int) : Void
      godot_bind(@@mb_set_joint_flags, "XRBodyTracker", "set_joint_flags", 592144999_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = flags.is_a?(Int) ? flags.to_i64 : flags.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_joint_flags, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_joint_flags : Void* = Pointer(Void).null
    def get_joint_flags(joint : Joint | Int) : JointFlags
      godot_bind(@@mb_get_joint_flags, "XRBodyTracker", "get_joint_flags", 1030162609_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_joint_flags, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(JointFlags, ret)
    end
    @@mb_set_joint_transform : Void* = Pointer(Void).null
    def set_joint_transform(joint : Joint | Int, transform : Transform3D) : Void
      godot_bind(@@mb_set_joint_transform, "XRBodyTracker", "set_joint_transform", 2635424328_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = transform
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_joint_transform, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_joint_transform : Void* = Pointer(Void).null
    def get_joint_transform(joint : Joint | Int) : Transform3D
      godot_bind(@@mb_get_joint_transform, "XRBodyTracker", "get_joint_transform", 3474811534_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_joint_transform, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    # Property `has_tracking_data` getter
    def has_tracking_data
      get_has_tracking_data
    end
    def has_tracking_data?
      has_tracking_data
    end
    # Property `has_tracking_data` setter
    def has_tracking_data=(val)
      set_has_tracking_data(val)
    end
    # Property `body_flags` getter
    def body_flags
      get_body_flags
    end
    # Property `body_flags` setter
    def body_flags=(val : Int)
      set_body_flags(val.to_i64)
    end
  end
  class XRCamera3D < Godot::Camera3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_tracker : Void* = Pointer(Void).null
    def set_tracker(tracker_name : String) : Void
      godot_bind(@@mb_set_tracker, "XRCamera3D", "set_tracker", 3304788590_i64)
      sn_0 = Bridge.make_string_name(tracker_name)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_tracker, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_tracker : Void* = Pointer(Void).null
    def get_tracker() : String
      godot_bind(@@mb_get_tracker, "XRCamera3D", "get_tracker", 2002593661_i64)
      godot_call_str("get_tracker")
    end
    # Property `tracker` getter
    def tracker
      get_tracker
    end
    # Property `tracker` setter
    def tracker=(val)
      set_tracker(val)
    end
  end
  class XRController3D < Godot::XRNode3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_is_button_pressed : Void* = Pointer(Void).null
    def is_button_pressed(name : String) : Bool
      godot_bind(@@mb_is_button_pressed, "XRController3D", "is_button_pressed", 2619796661_i64)
      sn_0 = Bridge.make_string_name(name)
      arg_0 = sn_0
      args = [arg_0]
      ret = 0_u8
      godot_ptrcall(@@mb_is_button_pressed, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_input : Void* = Pointer(Void).null
    def get_input(name : String) : Pointer(Void)
      godot_bind(@@mb_get_input, "XRController3D", "get_input", 2760726917_i64)
      sn_0 = Bridge.make_string_name(name)
      arg_0 = sn_0
      args = [arg_0]
      ret_var = StaticArray(UInt8, 24).new(0_u8)
      godot_ptrcall(@@mb_get_input, @pointer, args.to_unsafe.as(Void**), ret_var.to_unsafe.as(Void*))
      ret_ptr = Pointer(Void).null
      Bridge.type_from_variant(24, pointerof(ret_ptr).as(Void*), ret_var.to_unsafe.as(Void*))
      ret_ptr
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_float : Void* = Pointer(Void).null
    def get_float(name : String) : Float64
      godot_bind(@@mb_get_float, "XRController3D", "get_float", 2349060816_i64)
      sn_0 = Bridge.make_string_name(name)
      arg_0 = sn_0
      args = [arg_0]
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_float, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_vector2 : Void* = Pointer(Void).null
    def get_vector2(name : String) : Vector2
      godot_bind(@@mb_get_vector2, "XRController3D", "get_vector2", 3100822709_i64)
      sn_0 = Bridge.make_string_name(name)
      arg_0 = sn_0
      args = [arg_0]
      ret = Vector2.new
      godot_ptrcall(@@mb_get_vector2, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_tracker_hand : Void* = Pointer(Void).null
    def get_tracker_hand() : Godot::XRPositionalTracker::TrackerHand
      godot_bind(@@mb_get_tracker_hand, "XRController3D", "get_tracker_hand", 4181770860_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_tracker_hand, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::XRPositionalTracker::TrackerHand, ret)
    end
    godot_signal button_pressed, String
    godot_signal button_released, String
    godot_signal input_float_changed, String, Float64
    godot_signal input_vector2_changed, String, Vector2
    godot_signal profile_changed, String
  end
  class XRControllerTracker < Godot::XRPositionalTracker
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
  end
  class XRFaceModifier3D < Godot::Node3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_face_tracker : Void* = Pointer(Void).null
    def set_face_tracker(tracker_name : String) : Void
      godot_bind(@@mb_set_face_tracker, "XRFaceModifier3D", "set_face_tracker", 3304788590_i64)
      sn_0 = Bridge.make_string_name(tracker_name)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_face_tracker, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_face_tracker : Void* = Pointer(Void).null
    def get_face_tracker() : String
      godot_bind(@@mb_get_face_tracker, "XRFaceModifier3D", "get_face_tracker", 2002593661_i64)
      godot_call_str("get_face_tracker")
    end
    @@mb_set_target : Void* = Pointer(Void).null
    def set_target(target : NodePath | String) : Void
      godot_bind(@@mb_set_target, "XRFaceModifier3D", "set_target", 1348162250_i64)
      np_0 = Bridge.make_nodepath(target.to_s)
      arg_0 = np_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_target, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_nodepath(np_0)
    end
    @@mb_get_target : Void* = Pointer(Void).null
    def get_target() : NodePath
      godot_bind(@@mb_get_target, "XRFaceModifier3D", "get_target", 4075236667_i64)
      NodePath.new(godot_call_str("get_target"))
    end
    # Property `face_tracker` getter
    def face_tracker
      get_face_tracker
    end
    # Property `face_tracker` setter
    def face_tracker=(val)
      set_face_tracker(val)
    end
    # Property `target` getter
    def target
      get_target
    end
    # Property `target` setter
    def target=(val)
      set_target(val)
    end
  end
  class XRFaceTracker < Godot::XRTracker
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum BlendShapeEntry : Int64
      FtEyeLookOutRight = 0_i64
      FtEyeLookInRight = 1_i64
      FtEyeLookUpRight = 2_i64
      FtEyeLookDownRight = 3_i64
      FtEyeLookOutLeft = 4_i64
      FtEyeLookInLeft = 5_i64
      FtEyeLookUpLeft = 6_i64
      FtEyeLookDownLeft = 7_i64
      FtEyeClosedRight = 8_i64
      FtEyeClosedLeft = 9_i64
      FtEyeSquintRight = 10_i64
      FtEyeSquintLeft = 11_i64
      FtEyeWideRight = 12_i64
      FtEyeWideLeft = 13_i64
      FtEyeDilationRight = 14_i64
      FtEyeDilationLeft = 15_i64
      FtEyeConstrictRight = 16_i64
      FtEyeConstrictLeft = 17_i64
      FtBrowPinchRight = 18_i64
      FtBrowPinchLeft = 19_i64
      FtBrowLowererRight = 20_i64
      FtBrowLowererLeft = 21_i64
      FtBrowInnerUpRight = 22_i64
      FtBrowInnerUpLeft = 23_i64
      FtBrowOuterUpRight = 24_i64
      FtBrowOuterUpLeft = 25_i64
      FtNoseSneerRight = 26_i64
      FtNoseSneerLeft = 27_i64
      FtNasalDilationRight = 28_i64
      FtNasalDilationLeft = 29_i64
      FtNasalConstrictRight = 30_i64
      FtNasalConstrictLeft = 31_i64
      FtCheekSquintRight = 32_i64
      FtCheekSquintLeft = 33_i64
      FtCheekPuffRight = 34_i64
      FtCheekPuffLeft = 35_i64
      FtCheekSuckRight = 36_i64
      FtCheekSuckLeft = 37_i64
      FtJawOpen = 38_i64
      FtMouthClosed = 39_i64
      FtJawRight = 40_i64
      FtJawLeft = 41_i64
      FtJawForward = 42_i64
      FtJawBackward = 43_i64
      FtJawClench = 44_i64
      FtJawMandibleRaise = 45_i64
      FtLipSuckUpperRight = 46_i64
      FtLipSuckUpperLeft = 47_i64
      FtLipSuckLowerRight = 48_i64
      FtLipSuckLowerLeft = 49_i64
      FtLipSuckCornerRight = 50_i64
      FtLipSuckCornerLeft = 51_i64
      FtLipFunnelUpperRight = 52_i64
      FtLipFunnelUpperLeft = 53_i64
      FtLipFunnelLowerRight = 54_i64
      FtLipFunnelLowerLeft = 55_i64
      FtLipPuckerUpperRight = 56_i64
      FtLipPuckerUpperLeft = 57_i64
      FtLipPuckerLowerRight = 58_i64
      FtLipPuckerLowerLeft = 59_i64
      FtMouthUpperUpRight = 60_i64
      FtMouthUpperUpLeft = 61_i64
      FtMouthLowerDownRight = 62_i64
      FtMouthLowerDownLeft = 63_i64
      FtMouthUpperDeepenRight = 64_i64
      FtMouthUpperDeepenLeft = 65_i64
      FtMouthUpperRight = 66_i64
      FtMouthUpperLeft = 67_i64
      FtMouthLowerRight = 68_i64
      FtMouthLowerLeft = 69_i64
      FtMouthCornerPullRight = 70_i64
      FtMouthCornerPullLeft = 71_i64
      FtMouthCornerSlantRight = 72_i64
      FtMouthCornerSlantLeft = 73_i64
      FtMouthFrownRight = 74_i64
      FtMouthFrownLeft = 75_i64
      FtMouthStretchRight = 76_i64
      FtMouthStretchLeft = 77_i64
      FtMouthDimpleRight = 78_i64
      FtMouthDimpleLeft = 79_i64
      FtMouthRaiserUpper = 80_i64
      FtMouthRaiserLower = 81_i64
      FtMouthPressRight = 82_i64
      FtMouthPressLeft = 83_i64
      FtMouthTightenerRight = 84_i64
      FtMouthTightenerLeft = 85_i64
      FtTongueOut = 86_i64
      FtTongueUp = 87_i64
      FtTongueDown = 88_i64
      FtTongueRight = 89_i64
      FtTongueLeft = 90_i64
      FtTongueRoll = 91_i64
      FtTongueBlendDown = 92_i64
      FtTongueCurlUp = 93_i64
      FtTongueSquish = 94_i64
      FtTongueFlat = 95_i64
      FtTongueTwistRight = 96_i64
      FtTongueTwistLeft = 97_i64
      FtSoftPalateClose = 98_i64
      FtThroatSwallow = 99_i64
      FtNeckFlexRight = 100_i64
      FtNeckFlexLeft = 101_i64
      FtEyeClosed = 102_i64
      FtEyeWide = 103_i64
      FtEyeSquint = 104_i64
      FtEyeDilation = 105_i64
      FtEyeConstrict = 106_i64
      FtBrowDownRight = 107_i64
      FtBrowDownLeft = 108_i64
      FtBrowDown = 109_i64
      FtBrowUpRight = 110_i64
      FtBrowUpLeft = 111_i64
      FtBrowUp = 112_i64
      FtNoseSneer = 113_i64
      FtNasalDilation = 114_i64
      FtNasalConstrict = 115_i64
      FtCheekPuff = 116_i64
      FtCheekSuck = 117_i64
      FtCheekSquint = 118_i64
      FtLipSuckUpper = 119_i64
      FtLipSuckLower = 120_i64
      FtLipSuck = 121_i64
      FtLipFunnelUpper = 122_i64
      FtLipFunnelLower = 123_i64
      FtLipFunnel = 124_i64
      FtLipPuckerUpper = 125_i64
      FtLipPuckerLower = 126_i64
      FtLipPucker = 127_i64
      FtMouthUpperUp = 128_i64
      FtMouthLowerDown = 129_i64
      FtMouthOpen = 130_i64
      FtMouthRight = 131_i64
      FtMouthLeft = 132_i64
      FtMouthSmileRight = 133_i64
      FtMouthSmileLeft = 134_i64
      FtMouthSmile = 135_i64
      FtMouthSadRight = 136_i64
      FtMouthSadLeft = 137_i64
      FtMouthSad = 138_i64
      FtMouthStretch = 139_i64
      FtMouthDimple = 140_i64
      FtMouthTightener = 141_i64
      FtMouthPress = 142_i64
      FtMax = 143_i64
    end
    @@mb_get_blend_shape : Void* = Pointer(Void).null
    def get_blend_shape(blend_shape : BlendShapeEntry | Int) : Float64
      godot_bind(@@mb_get_blend_shape, "XRFaceTracker", "get_blend_shape", 330010046_i64)
      val_0 = blend_shape.is_a?(Int) ? blend_shape.to_i64 : blend_shape.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_blend_shape, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_blend_shape : Void* = Pointer(Void).null
    def set_blend_shape(blend_shape : BlendShapeEntry | Int, weight : Float64) : Void
      godot_bind(@@mb_set_blend_shape, "XRFaceTracker", "set_blend_shape", 2352588791_i64)
      val_0 = blend_shape.is_a?(Int) ? blend_shape.to_i64 : blend_shape.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = weight
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_blend_shape, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_blend_shapes : Void* = Pointer(Void).null
    def get_blend_shapes() : Pointer(Void)
      godot_bind(@@mb_get_blend_shapes, "XRFaceTracker", "get_blend_shapes", 675695659_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_blend_shapes, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_set_blend_shapes : Void* = Pointer(Void).null
    def set_blend_shapes(weights : Pointer(Void)) : Void
      godot_bind(@@mb_set_blend_shapes, "XRFaceTracker", "set_blend_shapes", 2899603908_i64)
      val_0 = weights
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_blend_shapes, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    # Property `blend_shapes` getter
    def blend_shapes
      get_blend_shapes
    end
    # Property `blend_shapes` setter
    def blend_shapes=(val)
      set_blend_shapes(val)
    end
  end
  class XRHandModifier3D < Godot::SkeletonModifier3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum BoneUpdate : Int64
      BoneUpdateFull = 0_i64
      BoneUpdateRotationOnly = 1_i64
      BoneUpdateMax = 2_i64
    end
    @@mb_set_hand_tracker : Void* = Pointer(Void).null
    def set_hand_tracker(tracker_name : String) : Void
      godot_bind(@@mb_set_hand_tracker, "XRHandModifier3D", "set_hand_tracker", 3304788590_i64)
      sn_0 = Bridge.make_string_name(tracker_name)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_hand_tracker, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_hand_tracker : Void* = Pointer(Void).null
    def get_hand_tracker() : String
      godot_bind(@@mb_get_hand_tracker, "XRHandModifier3D", "get_hand_tracker", 2002593661_i64)
      godot_call_str("get_hand_tracker")
    end
    @@mb_set_bone_update : Void* = Pointer(Void).null
    def set_bone_update(bone_update : BoneUpdate | Int) : Void
      godot_bind(@@mb_set_bone_update, "XRHandModifier3D", "set_bone_update", 3635701455_i64)
      val_0 = bone_update.is_a?(Int) ? bone_update.to_i64 : bone_update.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_bone_update, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_bone_update : Void* = Pointer(Void).null
    def get_bone_update() : BoneUpdate
      godot_bind(@@mb_get_bone_update, "XRHandModifier3D", "get_bone_update", 2873665691_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_bone_update, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(BoneUpdate, ret)
    end
    # Property `hand_tracker` getter
    def hand_tracker
      get_hand_tracker
    end
    # Property `hand_tracker` setter
    def hand_tracker=(val)
      set_hand_tracker(val)
    end
    # Property `bone_update` getter
    def bone_update
      get_bone_update
    end
    # Property `bone_update` setter
    def bone_update=(val : Int)
      set_bone_update(val.to_i64)
    end
  end
  class XRHandTracker < Godot::XRPositionalTracker
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum HandTrackingSource : Int64
      HandTrackingSourceUnknown = 0_i64
      HandTrackingSourceUnobstructed = 1_i64
      HandTrackingSourceController = 2_i64
      HandTrackingSourceNotTracked = 3_i64
      HandTrackingSourceMax = 4_i64
    end
    enum HandJoint : Int64
      HandJointPalm = 0_i64
      HandJointWrist = 1_i64
      HandJointThumbMetacarpal = 2_i64
      HandJointThumbPhalanxProximal = 3_i64
      HandJointThumbPhalanxDistal = 4_i64
      HandJointThumbTip = 5_i64
      HandJointIndexFingerMetacarpal = 6_i64
      HandJointIndexFingerPhalanxProximal = 7_i64
      HandJointIndexFingerPhalanxIntermediate = 8_i64
      HandJointIndexFingerPhalanxDistal = 9_i64
      HandJointIndexFingerTip = 10_i64
      HandJointMiddleFingerMetacarpal = 11_i64
      HandJointMiddleFingerPhalanxProximal = 12_i64
      HandJointMiddleFingerPhalanxIntermediate = 13_i64
      HandJointMiddleFingerPhalanxDistal = 14_i64
      HandJointMiddleFingerTip = 15_i64
      HandJointRingFingerMetacarpal = 16_i64
      HandJointRingFingerPhalanxProximal = 17_i64
      HandJointRingFingerPhalanxIntermediate = 18_i64
      HandJointRingFingerPhalanxDistal = 19_i64
      HandJointRingFingerTip = 20_i64
      HandJointPinkyFingerMetacarpal = 21_i64
      HandJointPinkyFingerPhalanxProximal = 22_i64
      HandJointPinkyFingerPhalanxIntermediate = 23_i64
      HandJointPinkyFingerPhalanxDistal = 24_i64
      HandJointPinkyFingerTip = 25_i64
      HandJointMax = 26_i64
    end
    enum HandJointFlags : Int64
      HandJointFlagOrientationValid = 1_i64
      HandJointFlagOrientationTracked = 2_i64
      HandJointFlagPositionValid = 4_i64
      HandJointFlagPositionTracked = 8_i64
      HandJointFlagLinearVelocityValid = 16_i64
      HandJointFlagAngularVelocityValid = 32_i64
    end
    @@mb_set_has_tracking_data : Void* = Pointer(Void).null
    def set_has_tracking_data(has_data : Bool) : Void
      godot_bind(@@mb_set_has_tracking_data, "XRHandTracker", "set_has_tracking_data", 2586408642_i64)
      val_0 = has_data
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_has_tracking_data, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_has_tracking_data : Void* = Pointer(Void).null
    def get_has_tracking_data() : Bool
      godot_bind(@@mb_get_has_tracking_data, "XRHandTracker", "get_has_tracking_data", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_get_has_tracking_data, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_hand_tracking_source : Void* = Pointer(Void).null
    def set_hand_tracking_source(source : HandTrackingSource | Int) : Void
      godot_bind(@@mb_set_hand_tracking_source, "XRHandTracker", "set_hand_tracking_source", 2958308861_i64)
      val_0 = source.is_a?(Int) ? source.to_i64 : source.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_hand_tracking_source, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_hand_tracking_source : Void* = Pointer(Void).null
    def get_hand_tracking_source() : HandTrackingSource
      godot_bind(@@mb_get_hand_tracking_source, "XRHandTracker", "get_hand_tracking_source", 2475045250_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_hand_tracking_source, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(HandTrackingSource, ret)
    end
    @@mb_set_hand_joint_flags : Void* = Pointer(Void).null
    def set_hand_joint_flags(joint : HandJoint | Int, flags : HandJointFlags | Int) : Void
      godot_bind(@@mb_set_hand_joint_flags, "XRHandTracker", "set_hand_joint_flags", 3028437365_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = flags.is_a?(Int) ? flags.to_i64 : flags.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_hand_joint_flags, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_hand_joint_flags : Void* = Pointer(Void).null
    def get_hand_joint_flags(joint : HandJoint | Int) : HandJointFlags
      godot_bind(@@mb_get_hand_joint_flags, "XRHandTracker", "get_hand_joint_flags", 1730972401_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_hand_joint_flags, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(HandJointFlags, ret)
    end
    @@mb_set_hand_joint_transform : Void* = Pointer(Void).null
    def set_hand_joint_transform(joint : HandJoint | Int, transform : Transform3D) : Void
      godot_bind(@@mb_set_hand_joint_transform, "XRHandTracker", "set_hand_joint_transform", 2529959613_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = transform
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_hand_joint_transform, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_hand_joint_transform : Void* = Pointer(Void).null
    def get_hand_joint_transform(joint : HandJoint | Int) : Transform3D
      godot_bind(@@mb_get_hand_joint_transform, "XRHandTracker", "get_hand_joint_transform", 1090840196_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_hand_joint_transform, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_hand_joint_radius : Void* = Pointer(Void).null
    def set_hand_joint_radius(joint : HandJoint | Int, radius : Float64) : Void
      godot_bind(@@mb_set_hand_joint_radius, "XRHandTracker", "set_hand_joint_radius", 2723659615_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = radius
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_hand_joint_radius, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_hand_joint_radius : Void* = Pointer(Void).null
    def get_hand_joint_radius(joint : HandJoint | Int) : Float64
      godot_bind(@@mb_get_hand_joint_radius, "XRHandTracker", "get_hand_joint_radius", 3400025734_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_hand_joint_radius, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_hand_joint_linear_velocity : Void* = Pointer(Void).null
    def set_hand_joint_linear_velocity(joint : HandJoint | Int, linear_velocity : Vector3) : Void
      godot_bind(@@mb_set_hand_joint_linear_velocity, "XRHandTracker", "set_hand_joint_linear_velocity", 1978646737_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = linear_velocity
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_hand_joint_linear_velocity, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_hand_joint_linear_velocity : Void* = Pointer(Void).null
    def get_hand_joint_linear_velocity(joint : HandJoint | Int) : Vector3
      godot_bind(@@mb_get_hand_joint_linear_velocity, "XRHandTracker", "get_hand_joint_linear_velocity", 547240792_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = Vector3.new
      godot_ptrcall(@@mb_get_hand_joint_linear_velocity, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_hand_joint_angular_velocity : Void* = Pointer(Void).null
    def set_hand_joint_angular_velocity(joint : HandJoint | Int, angular_velocity : Vector3) : Void
      godot_bind(@@mb_set_hand_joint_angular_velocity, "XRHandTracker", "set_hand_joint_angular_velocity", 1978646737_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = angular_velocity
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_set_hand_joint_angular_velocity, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_hand_joint_angular_velocity : Void* = Pointer(Void).null
    def get_hand_joint_angular_velocity(joint : HandJoint | Int) : Vector3
      godot_bind(@@mb_get_hand_joint_angular_velocity, "XRHandTracker", "get_hand_joint_angular_velocity", 547240792_i64)
      val_0 = joint.is_a?(Int) ? joint.to_i64 : joint.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = Vector3.new
      godot_ptrcall(@@mb_get_hand_joint_angular_velocity, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    # Property `has_tracking_data` getter
    def has_tracking_data
      get_has_tracking_data
    end
    def has_tracking_data?
      has_tracking_data
    end
    # Property `has_tracking_data` setter
    def has_tracking_data=(val)
      set_has_tracking_data(val)
    end
    # Property `hand_tracking_source` getter
    def hand_tracking_source
      get_hand_tracking_source
    end
    # Property `hand_tracking_source` setter
    def hand_tracking_source=(val : Int)
      set_hand_tracking_source(val.to_i64)
    end
  end
  class XRInterfaceExtension < Godot::XRInterface
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_get_color_texture : Void* = Pointer(Void).null
    def get_color_texture() : Int64
      godot_bind(@@mb_get_color_texture, "XRInterfaceExtension", "get_color_texture", 529393457_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_color_texture, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_depth_texture : Void* = Pointer(Void).null
    def get_depth_texture() : Int64
      godot_bind(@@mb_get_depth_texture, "XRInterfaceExtension", "get_depth_texture", 529393457_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_depth_texture, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_velocity_texture : Void* = Pointer(Void).null
    def get_velocity_texture() : Int64
      godot_bind(@@mb_get_velocity_texture, "XRInterfaceExtension", "get_velocity_texture", 529393457_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_velocity_texture, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_add_blit : Void* = Pointer(Void).null
    def add_blit(render_target : Int64, src_rect : Rect2, dst_rect : Rect2i, use_layer : Bool, layer : Int64, apply_lens_distortion : Bool, eye_center : Vector2, k1 : Float64, k2 : Float64, upscale : Float64, aspect_ratio : Float64) : Void
      godot_bind(@@mb_add_blit, "XRInterfaceExtension", "add_blit", 258596971_i64)
      val_0 = render_target
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = src_rect
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = dst_rect
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = use_layer
      arg_3 = pointerof(val_3).as(Void*)
      val_4 = layer
      arg_4 = pointerof(val_4).as(Void*)
      val_5 = apply_lens_distortion
      arg_5 = pointerof(val_5).as(Void*)
      val_6 = eye_center
      arg_6 = pointerof(val_6).as(Void*)
      val_7 = k1
      arg_7 = pointerof(val_7).as(Void*)
      val_8 = k2
      arg_8 = pointerof(val_8).as(Void*)
      val_9 = upscale
      arg_9 = pointerof(val_9).as(Void*)
      val_10 = aspect_ratio
      arg_10 = pointerof(val_10).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3, arg_4, arg_5, arg_6, arg_7, arg_8, arg_9, arg_10]
      godot_ptrcall(@@mb_add_blit, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_render_target_texture : Void* = Pointer(Void).null
    def get_render_target_texture(render_target : Int64) : Int64
      godot_bind(@@mb_get_render_target_texture, "XRInterfaceExtension", "get_render_target_texture", 41030802_i64)
      val_0 = render_target
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_get_render_target_texture, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
  end
  class XROrigin3D < Godot::Node3D
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_set_world_scale : Void* = Pointer(Void).null
    def set_world_scale(world_scale : Float64) : Void
      godot_bind(@@mb_set_world_scale, "XROrigin3D", "set_world_scale", 373806689_i64)
      val_0 = world_scale
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_world_scale, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_world_scale : Void* = Pointer(Void).null
    def get_world_scale() : Float64
      godot_bind(@@mb_get_world_scale, "XROrigin3D", "get_world_scale", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_world_scale, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_current : Void* = Pointer(Void).null
    def set_current(enabled : Bool) : Void
      godot_bind(@@mb_set_current, "XROrigin3D", "set_current", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_current, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_current : Void* = Pointer(Void).null
    def is_current() : Bool
      godot_bind(@@mb_is_current, "XROrigin3D", "is_current", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_current, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    # Property `world_scale` getter
    def world_scale
      get_world_scale
    end
    # Property `world_scale` setter
    def world_scale=(val : Number)
      set_world_scale(val.to_f64)
    end
    # Property `current` getter
    def current
      is_current
    end
    def current?
      current
    end
    # Property `current` setter
    def current=(val)
      set_current(val)
    end
  end
  class XRPose < Godot::RefCounted
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum TrackingConfidence : Int64
      XrTrackingConfidenceNone = 0_i64
      XrTrackingConfidenceLow = 1_i64
      XrTrackingConfidenceHigh = 2_i64
    end
    @@mb_set_has_tracking_data : Void* = Pointer(Void).null
    def set_has_tracking_data(has_tracking_data : Bool) : Void
      godot_bind(@@mb_set_has_tracking_data, "XRPose", "set_has_tracking_data", 2586408642_i64)
      val_0 = has_tracking_data
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_has_tracking_data, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_has_tracking_data : Void* = Pointer(Void).null
    def get_has_tracking_data() : Bool
      godot_bind(@@mb_get_has_tracking_data, "XRPose", "get_has_tracking_data", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_get_has_tracking_data, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_set_name : Void* = Pointer(Void).null
    def set_name(name : String) : Void
      godot_bind(@@mb_set_name, "XRPose", "set_name", 3304788590_i64)
      sn_0 = Bridge.make_string_name(name)
      arg_0 = sn_0
      args = [arg_0]
      godot_ptrcall(@@mb_set_name, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_name : Void* = Pointer(Void).null
    def get_name() : String
      godot_bind(@@mb_get_name, "XRPose", "get_name", 2002593661_i64)
      godot_call_str("get_name")
    end
    @@mb_set_transform : Void* = Pointer(Void).null
    def set_transform(transform : Transform3D) : Void
      godot_bind(@@mb_set_transform, "XRPose", "set_transform", 2952846383_i64)
      val_0 = transform
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_transform, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_transform : Void* = Pointer(Void).null
    def get_transform() : Transform3D
      godot_bind(@@mb_get_transform, "XRPose", "get_transform", 3229777777_i64)
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_transform, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_get_adjusted_transform : Void* = Pointer(Void).null
    def get_adjusted_transform() : Transform3D
      godot_bind(@@mb_get_adjusted_transform, "XRPose", "get_adjusted_transform", 3229777777_i64)
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_adjusted_transform, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_linear_velocity : Void* = Pointer(Void).null
    def set_linear_velocity(velocity : Vector3) : Void
      godot_bind(@@mb_set_linear_velocity, "XRPose", "set_linear_velocity", 3460891852_i64)
      val_0 = velocity
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_linear_velocity, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_linear_velocity : Void* = Pointer(Void).null
    def get_linear_velocity() : Vector3
      godot_bind(@@mb_get_linear_velocity, "XRPose", "get_linear_velocity", 3360562783_i64)
      ret = Vector3.new
      godot_ptrcall(@@mb_get_linear_velocity, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_angular_velocity : Void* = Pointer(Void).null
    def set_angular_velocity(velocity : Vector3) : Void
      godot_bind(@@mb_set_angular_velocity, "XRPose", "set_angular_velocity", 3460891852_i64)
      val_0 = velocity
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_angular_velocity, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_angular_velocity : Void* = Pointer(Void).null
    def get_angular_velocity() : Vector3
      godot_bind(@@mb_get_angular_velocity, "XRPose", "get_angular_velocity", 3360562783_i64)
      ret = Vector3.new
      godot_ptrcall(@@mb_get_angular_velocity, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_tracking_confidence : Void* = Pointer(Void).null
    def set_tracking_confidence(tracking_confidence : TrackingConfidence | Int) : Void
      godot_bind(@@mb_set_tracking_confidence, "XRPose", "set_tracking_confidence", 4171656666_i64)
      val_0 = tracking_confidence.is_a?(Int) ? tracking_confidence.to_i64 : tracking_confidence.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_tracking_confidence, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_tracking_confidence : Void* = Pointer(Void).null
    def get_tracking_confidence() : TrackingConfidence
      godot_bind(@@mb_get_tracking_confidence, "XRPose", "get_tracking_confidence", 2064923680_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_tracking_confidence, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(TrackingConfidence, ret)
    end
    # Property `has_tracking_data` getter
    def has_tracking_data
      get_has_tracking_data
    end
    def has_tracking_data?
      has_tracking_data
    end
    # Property `has_tracking_data` setter
    def has_tracking_data=(val)
      set_has_tracking_data(val)
    end
    # Property `name` getter
    def name
      get_name
    end
    # Property `name` setter
    def name=(val)
      set_name(val)
    end
    # Property `transform` getter
    def transform
      get_transform
    end
    # Property `transform` setter
    def transform=(val)
      set_transform(val)
    end
    # Property `linear_velocity` getter
    def linear_velocity
      get_linear_velocity
    end
    # Property `linear_velocity` setter
    def linear_velocity=(val)
      set_linear_velocity(val)
    end
    # Property `angular_velocity` getter
    def angular_velocity
      get_angular_velocity
    end
    # Property `angular_velocity` setter
    def angular_velocity=(val)
      set_angular_velocity(val)
    end
    # Property `tracking_confidence` getter
    def tracking_confidence
      get_tracking_confidence
    end
    # Property `tracking_confidence` setter
    def tracking_confidence=(val : Int)
      set_tracking_confidence(val.to_i64)
    end
  end
  class XRServer < Godot::Object
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum TrackerType : Int64
      TrackerCamera = 1_i64
      TrackerController = 2_i64
      TrackerBasestation = 4_i64
      TrackerAnchor = 8_i64
      TrackerHand = 16_i64
      TrackerBody = 32_i64
      TrackerFace = 64_i64
      TrackerAnyKnown = 127_i64
      TrackerUnknown = 128_i64
      TrackerAny = 255_i64
      TrackerHead = 1_i64
    end
    enum RotationMode : Int64
      ResetFullRotation = 0_i64
      ResetButKeepTilt = 1_i64
      DontResetRotation = 2_i64
    end
    @@mb_get_world_scale : Void* = Pointer(Void).null
    def get_world_scale() : Float64
      godot_bind(@@mb_get_world_scale, "XRServer", "get_world_scale", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_world_scale, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_world_scale : Void* = Pointer(Void).null
    def set_world_scale(scale : Float64) : Void
      godot_bind(@@mb_set_world_scale, "XRServer", "set_world_scale", 373806689_i64)
      val_0 = scale
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_world_scale, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_world_origin : Void* = Pointer(Void).null
    def get_world_origin() : Transform3D
      godot_bind(@@mb_get_world_origin, "XRServer", "get_world_origin", 3229777777_i64)
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_world_origin, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_world_origin : Void* = Pointer(Void).null
    def set_world_origin(world_origin : Transform3D) : Void
      godot_bind(@@mb_set_world_origin, "XRServer", "set_world_origin", 2952846383_i64)
      val_0 = world_origin
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_world_origin, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_reference_frame : Void* = Pointer(Void).null
    def get_reference_frame() : Transform3D
      godot_bind(@@mb_get_reference_frame, "XRServer", "get_reference_frame", 3229777777_i64)
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_reference_frame, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_clear_reference_frame : Void* = Pointer(Void).null
    def clear_reference_frame() : Void
      godot_bind(@@mb_clear_reference_frame, "XRServer", "clear_reference_frame", 3218959716_i64)
      godot_ptrcall(@@mb_clear_reference_frame, @pointer, Pointer(Pointer(Void)).null, Pointer(Void).null)
    end
    @@mb_center_on_hmd : Void* = Pointer(Void).null
    def center_on_hmd(rotation_mode : RotationMode | Int, keep_height : Bool) : Void
      godot_bind(@@mb_center_on_hmd, "XRServer", "center_on_hmd", 1450904707_i64)
      val_0 = rotation_mode.is_a?(Int) ? rotation_mode.to_i64 : rotation_mode.value.to_i64
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = keep_height
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      godot_ptrcall(@@mb_center_on_hmd, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_hmd_transform : Void* = Pointer(Void).null
    def get_hmd_transform() : Transform3D
      godot_bind(@@mb_get_hmd_transform, "XRServer", "get_hmd_transform", 4183770049_i64)
      ret = Transform3D.new
      godot_ptrcall(@@mb_get_hmd_transform, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_camera_locked_to_origin : Void* = Pointer(Void).null
    def set_camera_locked_to_origin(enabled : Bool) : Void
      godot_bind(@@mb_set_camera_locked_to_origin, "XRServer", "set_camera_locked_to_origin", 2586408642_i64)
      val_0 = enabled
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_camera_locked_to_origin, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_is_camera_locked_to_origin : Void* = Pointer(Void).null
    def is_camera_locked_to_origin() : Bool
      godot_bind(@@mb_is_camera_locked_to_origin, "XRServer", "is_camera_locked_to_origin", 36873697_i64)
      ret = 0_u8
      godot_ptrcall(@@mb_is_camera_locked_to_origin, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end
    @@mb_add_interface : Void* = Pointer(Void).null
    def add_interface(interface : XRInterface) : Void
      godot_bind(@@mb_add_interface, "XRServer", "add_interface", 1898711491_i64)
      arg_ptr_0 = interface ? interface.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_add_interface, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_interface_count : Void* = Pointer(Void).null
    def get_interface_count() : Int64
      godot_bind(@@mb_get_interface_count, "XRServer", "get_interface_count", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_interface_count, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_remove_interface : Void* = Pointer(Void).null
    def remove_interface(interface : XRInterface) : Void
      godot_bind(@@mb_remove_interface, "XRServer", "remove_interface", 1898711491_i64)
      arg_ptr_0 = interface ? interface.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_interface, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_interface : Void* = Pointer(Void).null
    def get_interface(idx : Int64) : XRInterface
      godot_bind(@@mb_get_interface, "XRServer", "get_interface", 4237347919_i64)
      val_0 = idx
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_interface, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      godot_return_obj(XRInterface, ret_ptr)
    end
    @@mb_get_interfaces : Void* = Pointer(Void).null
    def get_interfaces() : Pointer(Void)
      godot_bind(@@mb_get_interfaces, "XRServer", "get_interfaces", 3995934104_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_interfaces, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_find_interface : Void* = Pointer(Void).null
    def find_interface(name : String) : XRInterface
      godot_bind(@@mb_find_interface, "XRServer", "find_interface", 1395192955_i64)
      str_0 = Bridge.make_string(name)
      arg_0 = str_0
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_find_interface, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      godot_return_obj(XRInterface, ret_ptr)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_add_tracker : Void* = Pointer(Void).null
    def add_tracker(tracker : XRTracker) : Void
      godot_bind(@@mb_add_tracker, "XRServer", "add_tracker", 684804553_i64)
      arg_ptr_0 = tracker ? tracker.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_add_tracker, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_remove_tracker : Void* = Pointer(Void).null
    def remove_tracker(tracker : XRTracker) : Void
      godot_bind(@@mb_remove_tracker, "XRServer", "remove_tracker", 684804553_i64)
      arg_ptr_0 = tracker ? tracker.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_remove_tracker, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_trackers : Void* = Pointer(Void).null
    def get_trackers(tracker_types : Int64) : Pointer(Void)
      godot_bind(@@mb_get_trackers, "XRServer", "get_trackers", 3554694381_i64)
      val_0 = tracker_types
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_trackers, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_get_tracker : Void* = Pointer(Void).null
    def get_tracker(tracker_name : String) : XRTracker
      godot_bind(@@mb_get_tracker, "XRServer", "get_tracker", 147382240_i64)
      sn_0 = Bridge.make_string_name(tracker_name)
      arg_0 = sn_0
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_tracker, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      godot_return_obj(XRTracker, ret_ptr)
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_camera_projections : Void* = Pointer(Void).null
    def get_camera_projections(tracker_name : String, aspect : Float64, near : Float64, far : Float64) : Pointer(Void)
      godot_bind(@@mb_get_camera_projections, "XRServer", "get_camera_projections", 2969235509_i64)
      sn_0 = Bridge.make_string_name(tracker_name)
      arg_0 = sn_0
      val_1 = aspect
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = near
      arg_2 = pointerof(val_2).as(Void*)
      val_3 = far
      arg_3 = pointerof(val_3).as(Void*)
      args = [arg_0, arg_1, arg_2, arg_3]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_camera_projections, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      ret_ptr
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_camera_offsets : Void* = Pointer(Void).null
    def get_camera_offsets(tracker_name : String) : Pointer(Void)
      godot_bind(@@mb_get_camera_offsets, "XRServer", "get_camera_offsets", 689397652_i64)
      sn_0 = Bridge.make_string_name(tracker_name)
      arg_0 = sn_0
      args = [arg_0]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_camera_offsets, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      ret_ptr
    ensure
      Bridge.free_string_name(sn_0)
    end
    @@mb_get_primary_interface : Void* = Pointer(Void).null
    def get_primary_interface() : XRInterface
      godot_bind(@@mb_get_primary_interface, "XRServer", "get_primary_interface", 2143545064_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_primary_interface, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(XRInterface, ret_ptr)
    end
    @@mb_set_primary_interface : Void* = Pointer(Void).null
    def set_primary_interface(interface : XRInterface) : Void
      godot_bind(@@mb_set_primary_interface, "XRServer", "set_primary_interface", 1898711491_i64)
      arg_ptr_0 = interface ? interface.pointer : Pointer(Void).null
      arg_0 = pointerof(arg_ptr_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_primary_interface, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    # Property `world_scale` getter
    def world_scale
      get_world_scale
    end
    # Property `world_scale` setter
    def world_scale=(val : Number)
      set_world_scale(val.to_f64)
    end
    # Property `world_origin` getter
    def world_origin
      get_world_origin
    end
    # Property `world_origin` setter
    def world_origin=(val)
      set_world_origin(val)
    end
    # Property `camera_locked_to_origin` getter
    def camera_locked_to_origin
      is_camera_locked_to_origin
    end
    def camera_locked_to_origin?
      camera_locked_to_origin
    end
    # Property `camera_locked_to_origin` setter
    def camera_locked_to_origin=(val)
      set_camera_locked_to_origin(val)
    end
    # Property `primary_interface` getter
    def primary_interface
      get_primary_interface
    end
    # Property `primary_interface` setter
    def primary_interface=(val)
      set_primary_interface(val)
    end
    godot_signal reference_frame_changed
    godot_signal interface_added, String
    godot_signal interface_removed, String
    godot_signal tracker_added, String, Int64
    godot_signal tracker_updated, String, Int64
    godot_signal tracker_removed, String, Int64
    godot_signal world_origin_changed
  end
  class XRVRS < Godot::Object
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_get_vrs_min_radius : Void* = Pointer(Void).null
    def get_vrs_min_radius() : Float64
      godot_bind(@@mb_get_vrs_min_radius, "XRVRS", "get_vrs_min_radius", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_vrs_min_radius, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_vrs_min_radius : Void* = Pointer(Void).null
    def set_vrs_min_radius(radius : Float64) : Void
      godot_bind(@@mb_set_vrs_min_radius, "XRVRS", "set_vrs_min_radius", 373806689_i64)
      val_0 = radius
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_vrs_min_radius, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_vrs_strength : Void* = Pointer(Void).null
    def get_vrs_strength() : Float64
      godot_bind(@@mb_get_vrs_strength, "XRVRS", "get_vrs_strength", 1740695150_i64)
      ret = 0.0_f64
      godot_ptrcall(@@mb_get_vrs_strength, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_set_vrs_strength : Void* = Pointer(Void).null
    def set_vrs_strength(strength : Float64) : Void
      godot_bind(@@mb_set_vrs_strength, "XRVRS", "set_vrs_strength", 373806689_i64)
      val_0 = strength
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_vrs_strength, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_vrs_render_region : Void* = Pointer(Void).null
    def get_vrs_render_region() : Rect2i
      godot_bind(@@mb_get_vrs_render_region, "XRVRS", "get_vrs_render_region", 410525958_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_vrs_render_region, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      godot_return_obj(Rect2i, ret_ptr)
    end
    @@mb_set_vrs_render_region : Void* = Pointer(Void).null
    def set_vrs_render_region(render_region : Rect2i) : Void
      godot_bind(@@mb_set_vrs_render_region, "XRVRS", "set_vrs_render_region", 1763793166_i64)
      val_0 = render_region
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_vrs_render_region, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_make_vrs_texture : Void* = Pointer(Void).null
    def make_vrs_texture(target_size : Vector2, eye_foci : Pointer(Void)) : Int64
      godot_bind(@@mb_make_vrs_texture, "XRVRS", "make_vrs_texture", 3647044786_i64)
      val_0 = target_size
      arg_0 = pointerof(val_0).as(Void*)
      val_1 = eye_foci
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_make_vrs_texture, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    end
    # Property `vrs_min_radius` getter
    def vrs_min_radius
      get_vrs_min_radius
    end
    # Property `vrs_min_radius` setter
    def vrs_min_radius=(val : Number)
      set_vrs_min_radius(val.to_f64)
    end
    # Property `vrs_strength` getter
    def vrs_strength
      get_vrs_strength
    end
    # Property `vrs_strength` setter
    def vrs_strength=(val : Number)
      set_vrs_strength(val.to_f64)
    end
    # Property `vrs_render_region` getter
    def vrs_render_region
      get_vrs_render_region
    end
    # Property `vrs_render_region` setter
    def vrs_render_region=(val)
      set_vrs_render_region(val)
    end
  end
  class ZIPPacker < Godot::RefCounted
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    enum ZipAppend : Int64
      AppendCreate = 0_i64
      AppendCreateafter = 1_i64
      AppendAddinzip = 2_i64
    end
    enum CompressionLevel : Int64
      CompressionDefault = -1_i64
      CompressionNone = 0_i64
      CompressionFast = 1_i64
      CompressionBest = 9_i64
    end
    @@mb_open : Void* = Pointer(Void).null
    def open(path : String, append : ZipAppend | Int = 0) : Godot::Error
      godot_bind(@@mb_open, "ZIPPacker", "open", 1936816515_i64)
      str_0 = Bridge.make_string(path)
      arg_0 = str_0
      val_1 = append.is_a?(Int) ? append.to_i64 : append.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_open, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_set_compression_level : Void* = Pointer(Void).null
    def set_compression_level(compression_level : Int64) : Void
      godot_bind(@@mb_set_compression_level, "ZIPPacker", "set_compression_level", 1286410249_i64)
      val_0 = compression_level
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      godot_ptrcall(@@mb_set_compression_level, @pointer, args.to_unsafe.as(Void**), Pointer(Void).null)
    end
    @@mb_get_compression_level : Void* = Pointer(Void).null
    def get_compression_level() : Int64
      godot_bind(@@mb_get_compression_level, "ZIPPacker", "get_compression_level", 3905245786_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_get_compression_level, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret
    end
    @@mb_add_directory : Void* = Pointer(Void).null
    def add_directory(path : String, permissions : Godot::FileAccess::UnixPermissionFlags | Int = 493, modified_time : Int64 = 0_i64) : Godot::Error
      godot_bind(@@mb_add_directory, "ZIPPacker", "add_directory", 934773537_i64)
      str_0 = Bridge.make_string(path)
      arg_0 = str_0
      val_1 = permissions.is_a?(Int) ? permissions.to_i64 : permissions.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = modified_time
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      ret = 0_i64
      godot_ptrcall(@@mb_add_directory, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_start_file : Void* = Pointer(Void).null
    def start_file(path : String, permissions : Godot::FileAccess::UnixPermissionFlags | Int = 420, modified_time : Int64 = 0_i64) : Godot::Error
      godot_bind(@@mb_start_file, "ZIPPacker", "start_file", 4260848715_i64)
      str_0 = Bridge.make_string(path)
      arg_0 = str_0
      val_1 = permissions.is_a?(Int) ? permissions.to_i64 : permissions.value.to_i64
      arg_1 = pointerof(val_1).as(Void*)
      val_2 = modified_time
      arg_2 = pointerof(val_2).as(Void*)
      args = [arg_0, arg_1, arg_2]
      ret = 0_i64
      godot_ptrcall(@@mb_start_file, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_write_file : Void* = Pointer(Void).null
    def write_file(data : Pointer(Void)) : Godot::Error
      godot_bind(@@mb_write_file, "ZIPPacker", "write_file", 680677267_i64)
      val_0 = data
      arg_0 = pointerof(val_0).as(Void*)
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_write_file, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_close_file : Void* = Pointer(Void).null
    def close_file() : Godot::Error
      godot_bind(@@mb_close_file, "ZIPPacker", "close_file", 166280745_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_close_file, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_close : Void* = Pointer(Void).null
    def close() : Godot::Error
      godot_bind(@@mb_close, "ZIPPacker", "close", 166280745_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_close, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    # Property `compression_level` getter
    def compression_level
      get_compression_level
    end
    # Property `compression_level` setter
    def compression_level=(val : Int)
      set_compression_level(val.to_i64)
    end
  end
  class ZIPReader < Godot::RefCounted
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end
    @@mb_open : Void* = Pointer(Void).null
    def open(path : String) : Godot::Error
      godot_bind(@@mb_open, "ZIPReader", "open", 166001499_i64)
      str_0 = Bridge.make_string(path)
      arg_0 = str_0
      args = [arg_0]
      ret = 0_i64
      godot_ptrcall(@@mb_open, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_close : Void* = Pointer(Void).null
    def close() : Godot::Error
      godot_bind(@@mb_close, "ZIPReader", "close", 166280745_i64)
      ret = 0_i64
      godot_ptrcall(@@mb_close, @pointer, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      godot_return_enum(Godot::Error, ret)
    end
    @@mb_get_files : Void* = Pointer(Void).null
    def get_files() : Pointer(Void)
      godot_bind(@@mb_get_files, "ZIPReader", "get_files", 2981934095_i64)
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_get_files, @pointer, Pointer(Pointer(Void)).null, pointerof(ret_ptr).as(Void*))
      ret_ptr
    end
    @@mb_read_file : Void* = Pointer(Void).null
    def read_file(path : String, case_sensitive : Bool = true) : Pointer(Void)
      godot_bind(@@mb_read_file, "ZIPReader", "read_file", 740857591_i64)
      str_0 = Bridge.make_string(path)
      arg_0 = str_0
      val_1 = case_sensitive
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret_ptr = Pointer(Void).null
      godot_ptrcall(@@mb_read_file, @pointer, args.to_unsafe.as(Void**), pointerof(ret_ptr).as(Void*))
      ret_ptr
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_file_exists : Void* = Pointer(Void).null
    def file_exists(path : String, case_sensitive : Bool = true) : Bool
      godot_bind(@@mb_file_exists, "ZIPReader", "file_exists", 35364943_i64)
      str_0 = Bridge.make_string(path)
      arg_0 = str_0
      val_1 = case_sensitive
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret = 0_u8
      godot_ptrcall(@@mb_file_exists, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret != 0_u8
    ensure
      Bridge.free_string(str_0)
    end
    @@mb_get_compression_level : Void* = Pointer(Void).null
    def get_compression_level(path : String, case_sensitive : Bool = true) : Int64
      godot_bind(@@mb_get_compression_level, "ZIPReader", "get_compression_level", 3694577386_i64)
      str_0 = Bridge.make_string(path)
      arg_0 = str_0
      val_1 = case_sensitive
      arg_1 = pointerof(val_1).as(Void*)
      args = [arg_0, arg_1]
      ret = 0_i64
      godot_ptrcall(@@mb_get_compression_level, @pointer, args.to_unsafe.as(Void**), pointerof(ret).as(Void*))
      ret
    ensure
      Bridge.free_string(str_0)
    end
  end
end
