module Godot
  lib LibBridge
    struct CrystalPropertyDesc
      name : LibC::Char*
      type_name : LibC::Char*
      variant_type : Int32
      hint : UInt32
      hint_string : LibC::Char*
      usage : UInt32
    end

    struct CrystalSignalArgDesc
      name : LibC::Char*
      variant_type : Int32
    end

    struct CrystalSignalDesc
      name : LibC::Char*
      arg_count : Int32
      args : CrystalSignalArgDesc*
    end

    struct CrystalConstantDesc
      enum_name : LibC::Char*
      constant_name : LibC::Char*
      value : Int64
      is_bitfield : Bool
    end

    struct CrystalClassDesc
      name : LibC::Char*
      parent_name : LibC::Char*
      icon_path : LibC::Char*
      is_virtual : Bool
      is_abstract : Bool
      is_tool : Bool
      has_ready : Bool
      has_process : Bool
      has_physics_process : Bool
      has_enter_tree : Bool
      has_exit_tree : Bool
      has_input : Bool
      has_unhandled_input : Bool
      has_unhandled_key_input : Bool
      has_shortcut_input : Bool
      has_gui_input : Bool

      create_instance : (CrystalClassDesc*, Void* -> Void*)
      free_instance : (Void* -> Void)
      call_virtual : (Void*, LibC::Char*, Float64 -> Void)
      set_property : (Void*, LibC::Char*, Void* -> Void)
      get_property : (Void*, LibC::Char*, Void* -> Void)

      has_virtual_method : (CrystalClassDesc*, LibC::Char* -> Int32)
      call_virtual_with_data : (Void*, LibC::Char*, Void**, Void* -> Void)
      call_tool_button : (Void*, LibC::Char* -> Void)

      property_count : Int32
      properties : CrystalPropertyDesc*

      signal_count : Int32
      signals : CrystalSignalDesc*

      constant_count : Int32
      constants : CrystalConstantDesc*

      parent_desc : Void*
    end

    struct CrystalSignalArg
      arg_type : Int32
      data : Void*
    end

    struct VariantArg
      type : Int32
      extra_flags : Int32
      int_val : Int64
      float_val : Float64
      ptr_val : Void*
      instance_id : UInt64
      vec_val : StaticArray(Float32, 4)
    end

    struct BridgeCompletionOption
      kind : Int64
      display : LibC::Char*
      insert_text : LibC::Char*
      default_value : LibC::Char*
      location : Int64
    end

    struct BridgeAPI
      register_class : (CrystalClassDesc* -> Int32)
      get_method_bind : (LibC::Char*, LibC::Char*, Int64 -> Void*)
      method_bind_ptrcall : (Void*, Void*, Void**, Void* -> Void)
      method_bind_call : (Void*, Void*, Void**, Int64, Void*, Void* -> Void)
      load_editor_help_xml : (LibC::Char* -> Void)
      get_singleton : (LibC::Char* -> Void*)
      make_string_name : (LibC::Char* -> Void*)
      free_string_name : (Void* -> Void)
      make_string : (LibC::Char* -> Void*)
      free_string : (Void* -> Void)
      make_nodepath : (LibC::Char* -> Void*)
      free_nodepath : (Void* -> Void)
      type_from_variant : (Int32, Void*, Void* -> Void)
      variant_from_type : (Int32, Void*, Void* -> Void)
      log_print : (LibC::Char* -> Void)
      log_error : (LibC::Char*, LibC::Char*, LibC::Char*, LibC::Char*, Int32 -> Void)
      log_warning : (LibC::Char*, LibC::Char*, LibC::Char*, LibC::Char*, Int32 -> Void)
      object_emit_signal : (Void*, LibC::Char*, CrystalSignalArg*, Int32 -> Void)
      object_call_deferred : (Void*, LibC::Char*, CrystalSignalArg*, Int32 -> Void)
      object_call : (Void*, LibC::Char*, CrystalSignalArg*, Int32 -> Void)
      node_find_child : (Void*, LibC::Char*, Bool, Bool -> Void*)
      node_get_node : (Void*, LibC::Char* -> Void*)
      range_set_value : (Void*, Float64 -> Void)
      node_rpc_config : (Void*, LibC::Char*, Int32, Int32, Bool, Int32 -> Void)
      resource_loader_load : (LibC::Char*, LibC::Char*, Int64 -> Void*)
      packed_scene_instantiate : (Void*, Int64 -> Void*)
      node_get_name : (Void* -> LibC::Char*)
      classdb_construct_object : (LibC::Char* -> Void*)
      object_call_ret_object : (Void*, LibC::Char*, CrystalSignalArg*, Int32 -> Void*)
      object_call_ret_int : (Void*, LibC::Char*, CrystalSignalArg*, Int32 -> Int64)
      object_call_ret_float : (Void*, LibC::Char*, CrystalSignalArg*, Int32 -> Float64)
      object_call_ret_bool : (Void*, LibC::Char*, CrystalSignalArg*, Int32 -> Bool)
      object_call_ret_string : (Void*, LibC::Char*, CrystalSignalArg*, Int32 -> LibC::Char*)
      object_destroy : (Void* -> Void)
      object_get_instance_id : (Void* -> UInt64)
      object_get_instance_from_id : (UInt64 -> Void*)
      is_instance_valid : (UInt64 -> UInt8)
      ret_string : (Void*, LibC::Char* -> Void)
      ret_string_name : (Void*, LibC::Char* -> Void)
      ret_packed_string_array : (Void*, LibC::Char**, Int32 -> Void)
      ret_dictionary_empty : (Void* -> Void)
      ret_array_empty : (Void* -> Void)
      ret_object : (Void*, Void* -> Void)
      ret_ref : (Void*, Void* -> Void)
      ret_variant_object : (Void*, Void* -> Void)
      ret_variant_nil : (Void* -> Void)
      highlighter_add_span : (Void*, Int64, Float32, Float32, Float32, Float32 -> Void)
      arg_to_string : (Void*, LibC::Char*, Int32 -> Int32)
      arg_to_string_name : (Void*, LibC::Char*, Int32 -> Int32)
      ret_dictionary_validate : (Void*, UInt8 -> Void)
      ret_dictionary_complete_code : (Void* -> Void)
      ret_dictionary_lookup_code : (Void* -> Void)
      ret_dictionary_complete_code_ex : (Void*, Int64, UInt8, LibC::Char*, BridgeCompletionOption*, Int32 -> Void)
      ret_dictionary_lookup_code_ex : (Void*, Int64, Int64, LibC::Char*, LibC::Char*, LibC::Char*, LibC::Char*, Int64 -> Void)
      ret_dictionary_global_class : (Void*, LibC::Char*, LibC::Char*, LibC::Char* -> Void)
      placeholder_script_instance_create : (Void*, Void*, Void* -> Void*)
      text_edit_get_line : (Void*, Int64, LibC::Char*, Int32 -> Int32)
      object_connect_signal : (Void*, LibC::Char*, UInt32 -> Void)
      object_disconnect_signal : (Void*, LibC::Char* -> Void)
      register_signal_callback : ((UInt64, LibC::Char*, VariantArg*, Int32 -> Void) -> Void)
      register_deinit_callback : ((-> Void) -> Void)
      is_loader_registered : (-> Int32)
      set_loader_registered : (Int32 -> Void)
      is_saver_registered : (-> Int32)
      set_saver_registered : (Int32 -> Void)
      is_language_registered : (-> Int32)
      set_language_registered : (Int32 -> Void)
      get_language_object : (-> Void*)
      set_language_object : (Void* -> Void)
      set_reloading : (Int32 -> Void)
      set_debugger_cleanup : ((-> Void) -> Void)
      trigger_debugger_cleanup : (-> Void)
      ref_get_object : (Void* -> Void*)
      script_get_source_code : (Void* -> LibC::Char*)
      resource_get_path : (Void* -> LibC::Char*)
      object_is_class : (Void*, LibC::Char* -> Bool)
      register_gc_functions : (BridgeGCFunctions* -> Void)
      get_gc_signals : (LibC::Int*, LibC::Int* -> Void)
      object_get_class_name : (Void*, LibC::Char*, Int32 -> Void)
      log_verbose : (LibC::Char* -> Void)
      is_verbose : (-> Int32)
      ret_signal_list : (Void*, CrystalSignalDesc*, Int32 -> Void)
      ret_property_list : (Void*, CrystalPropertyDesc*, Int32 -> Void)
    end

    struct BridgeGCFunctions
      gc_init : (-> Void)
      register_my_thread : (Void* -> LibC::Int)
      unregister_my_thread : (-> Void)
      thread_is_registered : (-> LibC::Int)
      allow_register_threads : (-> Void)
      get_stack_base : (Void* -> LibC::Int)
      get_suspend_signal : (-> LibC::Int)
      get_thr_restart_signal : (-> LibC::Int)
    end
  end

  struct LibBridge::BridgeCompletionOption
    def initialize(
      @kind : Int64,
      @display : LibC::Char*,
      @insert_text : LibC::Char*,
      @default_value : LibC::Char*,
      @location : Int64
    )
    end
  end

  module Bridge
    alias BridgeCompletionOption = LibBridge::BridgeCompletionOption

    @@api : LibBridge::BridgeAPI* = Pointer(LibBridge::BridgeAPI).null

    # Method Binds Cache
    @@mb_cb3d_move_and_slide : Void* = Pointer(Void).null
    @@mb_cb3d_is_on_floor : Void* = Pointer(Void).null
    @@mb_cb3d_get_velocity : Void* = Pointer(Void).null
    @@mb_cb3d_set_velocity : Void* = Pointer(Void).null

    @@singleton_input : Void* = Pointer(Void).null
    @@mb_input_is_key_pressed : Void* = Pointer(Void).null
    @@mb_input_is_physical_key_pressed : Void* = Pointer(Void).null
    @@mb_input_is_action_just_pressed : Void* = Pointer(Void).null
    @@mb_input_is_action_pressed : Void* = Pointer(Void).null
    @@mb_input_is_action_just_released : Void* = Pointer(Void).null
    @@mb_input_get_axis : Void* = Pointer(Void).null
    @@mb_input_get_vector : Void* = Pointer(Void).null
    @@mb_input_is_mouse_button_pressed : Void* = Pointer(Void).null
    @@mb_input_use_accumulated_input : Void* = Pointer(Void).null
    @@mb_input_set_use_accumulated_input : Void* = Pointer(Void).null
    @@cached_string_names = Hash(String, Void*).new
    @@string_name_mutex = ::Thread::Mutex.new

    # Retain descriptions so their C strings and descriptors stay alive in memory
    @@registered_descs = Array(LibBridge::CrystalClassDesc).new
    # Active instance table rooting living Crystal nodes to protect against premature Boehm GC deallocation
    @@alive_instances = Hash(Void*, Godot::Object).new
    @@alive_instances_by_ptr = Hash(Void*, Godot::Object).new
    @@alive_mutex = ::Thread::Mutex.new
    @@native_signal_cb : (UInt64, LibC::Char*, LibBridge::VariantArg*, Int32 -> Void)? = nil
    @@native_deinit_cb : (-> Void)? = nil

    # Retrieves the active Crystal instance root table for testing and diagnostics
    def self.alive_instances : Hash(Void*, Godot::Object)
      @@alive_instances
    end

    def self.alive_mutex : ::Thread::Mutex
      @@alive_mutex
    end

    def self.register_alive_instance(boxed : Void*, inst : Godot::Object) : Void
      @@alive_mutex.synchronize do
        @@alive_instances[boxed] = inst
        @@alive_instances_by_ptr[inst.pointer] = inst if !inst.pointer.null?
      end
    end

    def self.unregister_alive_instance(boxed : Void*) : Void
      @@alive_mutex.synchronize do
        if inst = @@alive_instances.delete(boxed)
          @@alive_instances_by_ptr.delete(inst.pointer)
        end
      end
    end

    def self.has_alive_instance?(boxed : Void*) : Bool
      @@alive_mutex.synchronize do
        @@alive_instances.has_key?(boxed)
      end
    end

    def self.alive_instance_count : Int32
      @@alive_mutex.synchronize do
        @@alive_instances.size
      end
    end

    def self.api : LibBridge::BridgeAPI*
      @@api
    end

    class_property? init_done : Bool = false
    @@initialized : Bool = false

    def self.init(api : LibBridge::BridgeAPI*)
      @@api = api
      return if @@initialized
      @@initialized = true
      debug "[CrystalBridge] Initializing Crystal runtime from game.dll..."

      # Cache CharacterBody3D Method Binds
      debug "[CrystalBridge] Step 1: Getting CharacterBody3D method binds..."
      if !api.value.get_method_bind.pointer.null?
        @@mb_cb3d_move_and_slide = api.value.get_method_bind.call("CharacterBody3D".to_unsafe, "move_and_slide".to_unsafe, 2240911060_i64)
        debug "[CrystalBridge]   move_and_slide: #{@@mb_cb3d_move_and_slide}"
        @@mb_cb3d_is_on_floor = api.value.get_method_bind.call("CharacterBody3D".to_unsafe, "is_on_floor".to_unsafe, 36873697_i64)
        debug "[CrystalBridge]   is_on_floor: #{@@mb_cb3d_is_on_floor}"
        @@mb_cb3d_get_velocity = api.value.get_method_bind.call("CharacterBody3D".to_unsafe, "get_velocity".to_unsafe, 3360562783_i64)
        debug "[CrystalBridge]   get_velocity: #{@@mb_cb3d_get_velocity}"
        @@mb_cb3d_set_velocity = api.value.get_method_bind.call("CharacterBody3D".to_unsafe, "set_velocity".to_unsafe, 3460891852_i64)
        debug "[CrystalBridge]   set_velocity: #{@@mb_cb3d_set_velocity}"
      end

      # Cache Input Singleton and Method Binds
      debug "[CrystalBridge] Step 2: Getting Input singleton..."
      if !api.value.get_singleton.pointer.null?
        @@singleton_input = api.value.get_singleton.call("Input".to_unsafe)
        debug "[CrystalBridge]   singleton_input: #{@@singleton_input}"
      end

      if !api.value.get_method_bind.pointer.null?
        @@mb_input_is_key_pressed = api.value.get_method_bind.call("Input".to_unsafe, "is_key_pressed".to_unsafe, 1938909964_i64)
        debug "[CrystalBridge]   is_key_pressed: #{@@mb_input_is_key_pressed}"
        @@mb_input_is_physical_key_pressed = api.value.get_method_bind.call("Input".to_unsafe, "is_physical_key_pressed".to_unsafe, 1938909964_i64)
        debug "[CrystalBridge]   is_physical_key_pressed: #{@@mb_input_is_physical_key_pressed}"
        @@mb_input_is_action_just_pressed = api.value.get_method_bind.call("Input".to_unsafe, "is_action_just_pressed".to_unsafe, 1558498928_i64)
        debug "[CrystalBridge]   is_action_just_pressed: #{@@mb_input_is_action_just_pressed}"
        @@mb_input_is_action_pressed = api.value.get_method_bind.call("Input".to_unsafe, "is_action_pressed".to_unsafe, 1558498928_i64)
        debug "[CrystalBridge]   is_action_pressed: #{@@mb_input_is_action_pressed}"
        @@mb_input_is_action_just_released = api.value.get_method_bind.call("Input".to_unsafe, "is_action_just_released".to_unsafe, 1558498928_i64)
        debug "[CrystalBridge]   is_action_just_released: #{@@mb_input_is_action_just_released}"
        @@mb_input_get_axis = api.value.get_method_bind.call("Input".to_unsafe, "get_axis".to_unsafe, 1958752504_i64)
        debug "[CrystalBridge]   get_axis: #{@@mb_input_get_axis}"
        @@mb_input_get_vector = api.value.get_method_bind.call("Input".to_unsafe, "get_vector".to_unsafe, 2479607902_i64)
        debug "[CrystalBridge]   get_vector: #{@@mb_input_get_vector}"
        @@mb_input_is_mouse_button_pressed = api.value.get_method_bind.call("Input".to_unsafe, "is_mouse_button_pressed".to_unsafe, 1821097125_i64)
        debug "[CrystalBridge]   is_mouse_button_pressed: #{@@mb_input_is_mouse_button_pressed}"
        @@mb_input_use_accumulated_input = api.value.get_method_bind.call("Input".to_unsafe, "is_using_accumulated_input".to_unsafe, 2240911060_i64)
        debug "[CrystalBridge]   is_using_accumulated_input: #{@@mb_input_use_accumulated_input}"
        @@mb_input_set_use_accumulated_input = api.value.get_method_bind.call("Input".to_unsafe, "set_use_accumulated_input".to_unsafe, 2586408642_i64)
        debug "[CrystalBridge]   set_use_accumulated_input: #{@@mb_input_set_use_accumulated_input}"
      end

      # Callbacks for C host
      create_fn = ->(desc : LibBridge::CrystalClassDesc*, godot_obj : Void*) : Void* {
        class_name = String.new(desc.value.name)
        Godot.print("[create_fn] ENTERED: class_name='#{class_name}', godot_obj=#{godot_obj}")
        if entry = Godot::ClassRegistry.find(class_name)
          inst = entry.create_proc.call(godot_obj)
          Godot.print("[create_fn] inst=#{inst.class.name} (#{inst}) for class_name='#{class_name}'")
          inst.pointer = godot_obj
          boxed = Box(Godot::Object).box(inst)
          @@alive_mutex.synchronize do
            @@alive_instances[boxed] = inst
            @@alive_instances_by_ptr[godot_obj] = inst
          end
          return boxed
        end
        Godot.print("[create_fn] FAILED: class '#{class_name}' not found in ClassRegistry!")
        Pointer(Void).null
      }

      free_fn = ->(crystal_inst : Void*) {
        if !crystal_inst.null?
          @@alive_mutex.synchronize do
            if inst = @@alive_instances.delete(crystal_inst)
              @@alive_instances_by_ptr.delete(inst.pointer)
            end
          end
        end
      }

      virtual_fn = ->(crystal_inst : Void*, method_name : LibC::Char*, delta : Float64) {
        if !crystal_inst.null?
          inst = Box(Godot::Object).unbox(crystal_inst)
          m = String.new(method_name)
          {% unless flag?(:release) %}
            if (m == "_ready" || m == "_enter_tree") && !Godot::Debugger::Agent.initialized?
              Godot::Debugger::Agent.initialize_agent rescue nil
            end
          {% end %}
          inst._godot_call_virtual(m, delta)
        end
      }

      set_prop_fn = ->(crystal_inst : Void*, prop_name : LibC::Char*, val_ptr : Void*) {
        if !crystal_inst.null?
          inst = Box(Godot::Object).unbox(crystal_inst)
          inst._godot_set_property(String.new(prop_name), val_ptr)
        end
      }

      get_prop_fn = ->(crystal_inst : Void*, prop_name : LibC::Char*, ret_ptr : Void*) {
        if !crystal_inst.null?
          inst = Box(Godot::Object).unbox(crystal_inst)
          inst._godot_get_property(String.new(prop_name), ret_ptr)
        end
      }

      has_virtual_fn = ->(desc : LibBridge::CrystalClassDesc*, method_name : LibC::Char*) : Int32 {
        class_name = String.new(desc.value.name)
        m_name = String.new(method_name)
        if entry = Godot::ClassRegistry.find(class_name)
          entry.has_virtual_method?(m_name) ? 1 : 0
        else
          0
        end
      }

      virtual_with_data_fn = ->(crystal_inst : Void*, method_name : LibC::Char*, args : Void**, ret : Void*) {
        m_name = String.new(method_name)
        inst : Godot::Object? = nil
        if !crystal_inst.null?
          inst = if @@alive_mutex.synchronize { @@alive_instances.has_key?(crystal_inst) }
                   @@alive_mutex.synchronize { @@alive_instances[crystal_inst]? }
                 else
                   Box(Godot::Object).unbox(crystal_inst) rescue nil
                 end
        end
        {% unless flag?(:release) || flag?(:libgodot_addon) || flag?(:no_editor) %}
          if !inst || !inst.is_a?(Godot::CrystalLanguage)
            if m_name == "_complete_code" || m_name == "complete_code" ||
               m_name == "_lookup_code" || m_name == "lookup_code" ||
               m_name == "_make_template" || m_name == "make_template" ||
               m_name == "_create_script" || m_name == "create_script" ||
               m_name == "_auto_indent_code" || m_name == "auto_indent_code"
              inst = Godot::CrystalLanguage.singleton_instance
            end
          end
        {% end %}
        if inst
          begin
            inst._godot_call_virtual_with_data(m_name, args, ret)
          rescue ex
            Godot.printerr("[CrystalBridge] Unhandled exception in virtual method '#{m_name}': #{ex.message}")
          end
        end
      }

      call_tool_button_fn = ->(crystal_inst : Void*, btn_name : LibC::Char*) {
        if !crystal_inst.null?
          inst = Box(Godot::Object).unbox(crystal_inst)
          b_name = String.new(btn_name)
          begin
            inst._godot_call_tool_button(b_name)
          rescue ex
            Godot.printerr("[CrystalBridge] Unhandled exception in tool button '#{b_name}': #{ex.message}")
          end
        end
      }

      # Register every class defined in Crystal
      debug "[CrystalBridge] Step 3: ClassRegistry has #{Godot::ClassRegistry.entries.size} entries"
      Godot::ClassRegistry.entries.each do |entry|
        debug "[CrystalBridge]   Registering entry: #{entry.class_name} < #{entry.parent_name} (props=#{entry.properties.size}, sigs=#{entry.signals.size})..."
        # Populate properties dynamically without fixed limits
        p_count = entry.properties.size
        props = Pointer(LibBridge::CrystalPropertyDesc).malloc(p_count > 0 ? p_count : 1)
        entry.properties.each_with_index do |p, idx|
          item = LibBridge::CrystalPropertyDesc.new
          item.name = p.name.to_unsafe
          item.type_name = p.type_name.to_unsafe
          item.variant_type = p.variant_type
          item.hint = p.hint
          item.hint_string = p.hint_string.to_unsafe
          item.usage = p.usage
          props[idx] = item
        end

        # Populate signals dynamically without fixed limits
        s_count = entry.signals.size
        sigs = Pointer(LibBridge::CrystalSignalDesc).malloc(s_count > 0 ? s_count : 1)
        entry.signals.each_with_index do |s, idx|
          sig_item = LibBridge::CrystalSignalDesc.new
          sig_item.name = s.name.to_unsafe
          sig_item.arg_count = s.args.size
          a_count = s.args.size
          args_ptr = Pointer(LibBridge::CrystalSignalArgDesc).malloc(a_count > 0 ? a_count : 1)
          s.args.each_with_index do |a, aidx|
            arg_item = LibBridge::CrystalSignalArgDesc.new
            arg_item.name = a.name.to_unsafe
            arg_item.variant_type = a.variant_type
            args_ptr[aidx] = arg_item
          end
          sig_item.args = args_ptr
          sigs[idx] = sig_item
        end

        # Populate class integer / enum constants
        c_count = entry.constants.size
        consts = Pointer(LibBridge::CrystalConstantDesc).malloc(c_count > 0 ? c_count : 1)
        entry.constants.each_with_index do |c, idx|
          c_item = LibBridge::CrystalConstantDesc.new
          c_item.enum_name = c.enum_name.to_unsafe
          c_item.constant_name = c.name.to_unsafe
          c_item.value = c.value
          c_item.is_bitfield = c.is_bitfield?
          consts[idx] = c_item
        end

        desc = LibBridge::CrystalClassDesc.new
        desc.name = entry.class_name.to_unsafe
        desc.parent_name = entry.parent_name.to_unsafe
        desc.icon_path = entry.icon_path.empty? ? Pointer(LibC::Char).null : entry.icon_path.to_unsafe
        desc.is_virtual = false
        desc.is_abstract = entry.is_abstract
        desc.is_tool = entry.is_tool
        desc.has_ready = entry.has_ready
        desc.has_process = entry.has_process
        desc.has_physics_process = entry.has_physics_process
        desc.has_enter_tree = entry.has_enter_tree
        desc.has_exit_tree = entry.has_exit_tree
        desc.has_input = entry.has_input
        desc.has_unhandled_input = entry.has_unhandled_input
        desc.has_unhandled_key_input = entry.has_unhandled_key_input
        desc.has_shortcut_input = entry.has_shortcut_input
        desc.has_gui_input = entry.has_gui_input

        desc.create_instance = create_fn
        desc.free_instance = free_fn
        desc.call_virtual = virtual_fn
        desc.set_property = set_prop_fn
        desc.get_property = get_prop_fn
        desc.has_virtual_method = has_virtual_fn
        desc.call_virtual_with_data = virtual_with_data_fn
        desc.call_tool_button = call_tool_button_fn

        desc.property_count = p_count
        desc.properties = props

        desc.signal_count = s_count
        desc.signals = sigs

        desc.constant_count = c_count
        desc.constants = consts

        desc_ptr = Pointer(LibBridge::CrystalClassDesc).malloc(1)
        desc_ptr.value = desc
        @@registered_descs << desc

        debug "[CrystalBridge]   Calling api.register_class for #{entry.class_name}..."
        api.value.register_class.call(desc_ptr)
        debug "[CrystalBridge]   Done registering #{entry.class_name}!"
      end

      debug "[CrystalBridge] Successfully registered #{Godot::ClassRegistry.entries.size} Crystal classes with Godot!"
      # Load all compile-time generated XML documentation into Godot Editor Help & Inspector
      Godot::EditorDocRegistry.load_all

      # Register native signal callback from C++ bridge into Crystal signal dispatcher
      if !api.value.register_signal_callback.pointer.null?
        cb = ->(target_id : UInt64, sig_ptr : LibC::Char*, args_ptr : LibBridge::VariantArg*, count : Int32) {
          sig_name = String.new(sig_ptr)
          arr = Array(Godot::Variant).new(count)
          if !args_ptr.null? && count > 0
            count.times do |i|
              arr << Godot::Variant.from_arg(args_ptr[i])
            end
          end
          Godot.notify_signal(target_id, sig_name, arr)
        }
        @@native_signal_cb = cb
        api.value.register_signal_callback.call(cb)
      end

      # Register deinitialization callback so Godot cleanly unregisters language, loader, and saver
      if !api.value.register_deinit_callback.pointer.null?
        deinit_cb = -> {
          Bridge.deinit
        }
        @@native_deinit_cb = deinit_cb
        api.value.register_deinit_callback.call(deinit_cb)
      end

      # Early-register language, loader, and saver so Godot can load .cr files during editor layout restore
      early_register_component("CrystalLanguage")
      early_register_component("ResourceFormatLoaderCrystal")
      early_register_component("ResourceFormatSaverCrystal")
    end

    # Early-registers an engine component if it is defined in the current compilation unit
    macro early_register_component(class_name)
      {% if @top_level.has_constant?("Godot") && @top_level.constant("Godot").has_constant?(class_name) %}
        Godot.print("[early_register_component] Registering {{class_name.id}}...")
        Godot::{{class_name.id}}.ensure_registered
      {% else %}
        Godot.print("[early_register_component] {{class_name.id}} NOT FOUND in Godot constant!")
      {% end %}
    end

    # Unregisters an engine component during bridge deinitialization if defined in the current compilation unit
    macro unregister_component(class_name, display_name = nil)
      {% if @top_level.has_constant?("Godot") && @top_level.constant("Godot").has_constant?(class_name) %}
        Godot.debug("[Bridge.deinit] Unregistering {{ (display_name || class_name).id }}...")
        Godot::{{class_name.id}}.unregister rescue nil
      {% end %}
    end

    @@shutdown_callbacks = [] of (-> Void)

    def self.register_shutdown_callback(&block : -> Void)
      @@shutdown_callbacks << block
    end

    @@deinitialized : Bool = false

    def self.deinit : Void
      return if @@deinitialized
      @@deinitialized = true

      Godot.debug("[Bridge.deinit] Cleaning up registered shutdown callbacks...")
      @@shutdown_callbacks.each do |cb|
        begin
          cb.call
        rescue ex
          Godot.debug("[Bridge.deinit] Error in shutdown callback: #{ex.message}")
        end
      end
      @@shutdown_callbacks.clear

      Godot.debug("[Bridge.deinit] Cleaning up script cache...")
      ClassRegistry.cleanup rescue nil
      unregister_component("ResourceFormatLoaderCrystal", "loader")
      unregister_component("ResourceFormatSaverCrystal", "saver")
      unregister_component("CrystalLanguage", "language")
      Godot.debug("[Bridge.deinit] Completed successfully!")
    end

    # Engine Logging Helpers
    def self.verbose? : Bool
      if !@@api.null? && !@@api.value.is_verbose.pointer.null?
        return @@api.value.is_verbose.call == 1
      end
      ENV["LIBGODOT_VERBOSE"]? == "1" || ENV["GODOT_VERBOSE"]? == "1"
    end

    def self.print_verbose(msg : String) : Void
      if !@@api.null? && !@@api.value.log_verbose.pointer.null?
        @@api.value.log_verbose.call(msg.to_unsafe)
      elsif verbose?
        puts msg
      end
    end

    def self.debug(msg : String) : Void
      print_verbose(msg)
    end

    def self.print(msg : String) : Void
      if !@@api.null? && !@@api.value.log_print.pointer.null?
        @@api.value.log_print.call(msg.to_unsafe)
      else
        puts msg
      end
    end

    def self.printerr(msg : String) : Void
      if !@@api.null? && !@@api.value.log_error.pointer.null?
        @@api.value.log_error.call(msg.to_unsafe, "".to_unsafe, "".to_unsafe, "".to_unsafe, 0)
      else
        STDERR.puts msg
      end
    end

    def self.error(desc : String, msg : String = "", func : String = "", file : String = "", line : Int32 = 0) : Void
      if !@@api.null? && !@@api.value.log_error.pointer.null?
        @@api.value.log_error.call(desc.to_unsafe, msg.to_unsafe, func.to_unsafe, file.to_unsafe, line)
      else
        STDERR.puts "[ERROR] #{desc}: #{msg} (#{file}:#{line} in #{func})"
      end
    end

    def self.warning(desc : String, msg : String = "", func : String = "", file : String = "", line : Int32 = 0) : Void
      if !@@api.null? && !@@api.value.log_warning.pointer.null?
        @@api.value.log_warning.call(desc.to_unsafe, msg.to_unsafe, func.to_unsafe, file.to_unsafe, line)
      else
        STDERR.puts "[WARNING] #{desc}: #{msg}"
      end
    end

    # Generic Engine Dispatchers
    def self.get_method_bind(class_name : String, method_name : String, hash : Int64) : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.get_method_bind.pointer.null?
      @@api.value.get_method_bind.call(class_name.to_unsafe, method_name.to_unsafe, hash)
    end

    def self.ptrcall(method_bind : Void*, instance : Void*, args : Void**, ret : Void*) : Void
      return if @@api.null? || @@api.value.method_bind_ptrcall.pointer.null? || method_bind.null? || instance.null?
      @@api.value.method_bind_ptrcall.call(method_bind, instance, args, ret)
    end

    def self.static_ptrcall(method_bind : Void*, args : Void**, ret : Void*) : Void
      return if @@api.null? || @@api.value.method_bind_ptrcall.pointer.null? || method_bind.null?
      @@api.value.method_bind_ptrcall.call(method_bind, Pointer(Void).null, args, ret)
    end

    def self.get_singleton(name : String) : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.get_singleton.pointer.null?
      @@api.value.get_singleton.call(name.to_unsafe)
    end

    def self.load_editor_help(xml : String) : Void
      return if @@api.null? || @@api.value.load_editor_help_xml.pointer.null?
      @@api.value.load_editor_help_xml.call(xml.to_unsafe)
    end

    # Engine Method Calls
    def self.is_on_floor(godot_obj : Void*) : Bool
      return true if godot_obj.null? || @@mb_cb3d_is_on_floor.null? || @@api.null?
      ret = 0_u8
      @@api.value.method_bind_ptrcall.call(@@mb_cb3d_is_on_floor, godot_obj, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end

    def self.get_velocity(godot_obj : Void*) : Vector3
      return Vector3.new if godot_obj.null? || @@mb_cb3d_get_velocity.null? || @@api.null?
      vec = Vector3.new
      @@api.value.method_bind_ptrcall.call(@@mb_cb3d_get_velocity, godot_obj, Pointer(Pointer(Void)).null, pointerof(vec).as(Void*))
      vec
    end

    def self.set_velocity(godot_obj : Void*, v : Vector3) : Void
      return if godot_obj.null? || @@mb_cb3d_set_velocity.null? || @@api.null?
      val = v
      arg = pointerof(val).as(Void*)
      args = pointerof(arg)
      @@api.value.method_bind_ptrcall.call(@@mb_cb3d_set_velocity, godot_obj, args, Pointer(Void).null)
    end

    def self.move_and_slide(godot_obj : Void*) : Bool
      return true if godot_obj.null? || @@mb_cb3d_move_and_slide.null? || @@api.null?
      ret = 0_u8
      @@api.value.method_bind_ptrcall.call(@@mb_cb3d_move_and_slide, godot_obj, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end

    def self.is_key_pressed(key : Int32) : Bool
      return false if @@singleton_input.null? || @@mb_input_is_key_pressed.null? || @@api.null?
      k = key.to_i64
      arg = pointerof(k).as(Void*)
      args = pointerof(arg)
      ret = 0_u8
      @@api.value.method_bind_ptrcall.call(@@mb_input_is_key_pressed, @@singleton_input, args, pointerof(ret).as(Void*))
      ret != 0_u8
    end

    def self.is_physical_key_pressed(key : Int32) : Bool
      return false if @@singleton_input.null? || @@mb_input_is_physical_key_pressed.null? || @@api.null?
      k = key.to_i64
      arg = pointerof(k).as(Void*)
      args = pointerof(arg)
      ret = 0_u8
      @@api.value.method_bind_ptrcall.call(@@mb_input_is_physical_key_pressed, @@singleton_input, args, pointerof(ret).as(Void*))
      ret != 0_u8
    end

    def self.cached_string_name(str : String) : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.make_string_name.pointer.null?
      @@string_name_mutex.synchronize do
        if sn = @@cached_string_names[str]?
          sn
        else
          sn = @@api.value.make_string_name.call(str.to_unsafe)
          @@cached_string_names[str] = sn
          sn
        end
      end
    end

    def self.is_action_just_pressed(action : String, exact_match : Bool = false) : Bool
      return false if @@singleton_input.null? || @@mb_input_is_action_just_pressed.null? || @@api.null?
      sn = cached_string_name(action)
      exact = exact_match ? 1_u8 : 0_u8
      args = uninitialized Void*[2]
      args[0] = sn
      args[1] = pointerof(exact).as(Void*)
      ret = 0_u8
      @@api.value.method_bind_ptrcall.call(@@mb_input_is_action_just_pressed, @@singleton_input, args.to_unsafe, pointerof(ret).as(Void*))
      ret != 0_u8
    end

    def self.is_action_pressed(action : String, exact_match : Bool = false) : Bool
      return false if @@singleton_input.null? || @@mb_input_is_action_pressed.null? || @@api.null?
      sn = cached_string_name(action)
      exact = exact_match ? 1_u8 : 0_u8
      args = uninitialized Void*[2]
      args[0] = sn
      args[1] = pointerof(exact).as(Void*)
      ret = 0_u8
      @@api.value.method_bind_ptrcall.call(@@mb_input_is_action_pressed, @@singleton_input, args.to_unsafe, pointerof(ret).as(Void*))
      ret != 0_u8
    end

    def self.is_action_just_released(action : String, exact_match : Bool = false) : Bool
      return false if @@singleton_input.null? || @@mb_input_is_action_just_released.null? || @@api.null?
      sn = cached_string_name(action)
      exact = exact_match ? 1_u8 : 0_u8
      args = uninitialized Void*[2]
      args[0] = sn
      args[1] = pointerof(exact).as(Void*)
      ret = 0_u8
      @@api.value.method_bind_ptrcall.call(@@mb_input_is_action_just_released, @@singleton_input, args.to_unsafe, pointerof(ret).as(Void*))
      ret != 0_u8
    end

    def self.get_axis(negative_action : String, positive_action : String) : Float32
      return 0.0_f32 if @@singleton_input.null? || @@mb_input_get_axis.null? || @@api.null?
      sn_neg = cached_string_name(negative_action)
      sn_pos = cached_string_name(positive_action)
      args = uninitialized Void*[2]
      args[0] = sn_neg
      args[1] = sn_pos
      ret = 0.0_f64
      @@api.value.method_bind_ptrcall.call(@@mb_input_get_axis, @@singleton_input, args.to_unsafe, pointerof(ret).as(Void*))
      ret.to_f32
    end

    def self.get_vector(negative_x : String, positive_x : String, negative_y : String, positive_y : String, deadzone : Float64 = -1.0_f64) : Vector2
      return Vector2::ZERO if @@singleton_input.null? || @@mb_input_get_vector.null? || @@api.null?
      sn_nx = cached_string_name(negative_x)
      sn_px = cached_string_name(positive_x)
      sn_ny = cached_string_name(negative_y)
      sn_py = cached_string_name(positive_y)
      dz = deadzone
      args = uninitialized Void*[5]
      args[0] = sn_nx
      args[1] = sn_px
      args[2] = sn_ny
      args[3] = sn_py
      args[4] = pointerof(dz).as(Void*)
      ret = Vector2.new
      @@api.value.method_bind_ptrcall.call(@@mb_input_get_vector, @@singleton_input, args.to_unsafe, pointerof(ret).as(Void*))
      ret
    end

    def self.is_mouse_button_pressed(button : Int64) : Bool
      return false if @@singleton_input.null? || @@mb_input_is_mouse_button_pressed.null? || @@api.null?
      b = button
      args = uninitialized Void*[1]
      args[0] = pointerof(b).as(Void*)
      ret = 0_u8
      @@api.value.method_bind_ptrcall.call(@@mb_input_is_mouse_button_pressed, @@singleton_input, args.to_unsafe, pointerof(ret).as(Void*))
      ret != 0_u8
    end

    def self.use_accumulated_input : Bool
      return true if @@singleton_input.null? || @@mb_input_use_accumulated_input.null? || @@api.null?
      ret = 0_u8
      @@api.value.method_bind_ptrcall.call(@@mb_input_use_accumulated_input, @@singleton_input, Pointer(Pointer(Void)).null, pointerof(ret).as(Void*))
      ret != 0_u8
    end

    def self.use_accumulated_input=(enable : Bool) : Void
      return if @@singleton_input.null? || @@mb_input_set_use_accumulated_input.null? || @@api.null?
      en = enable ? 1_u8 : 0_u8
      args = uninitialized Void*[1]
      args[0] = pointerof(en).as(Void*)
      @@api.value.method_bind_ptrcall.call(@@mb_input_set_use_accumulated_input, @@singleton_input, args.to_unsafe, Pointer(Void).null)
    end

    def self.available? : Bool
      !@@api.null? && !@@api.value.object_emit_signal.pointer.null?
    end

    def self.emit_signal(godot_obj : Void*, signal_name : String) : Void
      return unless available?
      return if godot_obj.null?
      @@api.value.object_emit_signal.call(godot_obj, signal_name.to_unsafe, Pointer(LibBridge::CrystalSignalArg).null, 0)
    end

    def self.emit_signal(godot_obj : Void*, signal_name : String, *args) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.object_emit_signal.pointer.null?
      if args.empty?
        emit_signal(godot_obj, signal_name)
        return
      end

      c_args = StaticArray(LibBridge::CrystalSignalArg, 16).new(LibBridge::CrystalSignalArg.new)
      int_storage = StaticArray(Int64, 16).new(0_i64)
      float_storage = StaticArray(Float64, 16).new(0.0_f64)
      bool_storage = StaticArray(UInt8, 16).new(0_u8)
      v2_storage = StaticArray(Godot::Vector2, 16).new(Godot::Vector2.new)
      v3_storage = StaticArray(Godot::Vector3, 16).new(Godot::Vector3.new)
      color_storage = StaticArray(Godot::Color, 16).new(Godot::Color.new)
      obj_storage = StaticArray(Void*, 16).new(Pointer(Void).null)

      count = [args.size, 16].min
      args.each_with_index do |arg, idx|
        break if idx >= 16
        if arg.is_a?(Bool)
          bool_storage[idx] = arg ? 1_u8 : 0_u8
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 1, data: (bool_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Int)
          int_storage[idx] = arg.to_i64
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 2, data: (int_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Float)
          float_storage[idx] = arg.to_f64
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 3, data: (float_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(String)
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 4, data: arg.to_unsafe.as(Void*))
        elsif arg.is_a?(Godot::Vector2)
          v2_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 5, data: (v2_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Vector3)
          v3_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 6, data: (v3_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Object)
          obj_storage[idx] = arg.pointer
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 7, data: (obj_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Color)
          color_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 8, data: (color_storage.to_unsafe + idx).as(Void*))
        end
      end

      @@api.value.object_emit_signal.call(godot_obj, signal_name.to_unsafe, c_args.to_unsafe, count)
    end

    def self.object_connect_signal(godot_obj : Void*, signal_name : String, flags : UInt32 = 0_u32) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.object_connect_signal.pointer.null?
      @@api.value.object_connect_signal.call(godot_obj, signal_name.to_unsafe, flags)
    end

    def self.object_disconnect_signal(godot_obj : Void*, signal_name : String) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.object_disconnect_signal.pointer.null?
      @@api.value.object_disconnect_signal.call(godot_obj, signal_name.to_unsafe)
    end

    def self.object_call_deferred(godot_obj : Void*, method_name : String) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.object_call_deferred.pointer.null?
      @@api.value.object_call_deferred.call(godot_obj, method_name.to_unsafe, Pointer(LibBridge::CrystalSignalArg).null, 0)
    end

    def self.object_call_deferred(godot_obj : Void*, method_name : String, *args) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.object_call_deferred.pointer.null?
      if args.empty?
        object_call_deferred(godot_obj, method_name)
        return
      end

      c_args = StaticArray(LibBridge::CrystalSignalArg, 16).new(LibBridge::CrystalSignalArg.new)
      int_storage = StaticArray(Int64, 16).new(0_i64)
      float_storage = StaticArray(Float64, 16).new(0.0_f64)
      bool_storage = StaticArray(UInt8, 16).new(0_u8)
      v2_storage = StaticArray(Godot::Vector2, 16).new(Godot::Vector2.new)
      v3_storage = StaticArray(Godot::Vector3, 16).new(Godot::Vector3.new)
      color_storage = StaticArray(Godot::Color, 16).new(Godot::Color.new)
      obj_storage = StaticArray(Void*, 16).new(Pointer(Void).null)

      count = [args.size, 16].min
      args.each_with_index do |arg, idx|
        break if idx >= 16
        if arg.is_a?(Bool)
          bool_storage[idx] = arg ? 1_u8 : 0_u8
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 1, data: (bool_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Int)
          int_storage[idx] = arg.to_i64
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 2, data: (int_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Float)
          float_storage[idx] = arg.to_f64
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 3, data: (float_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(String)
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 4, data: arg.to_unsafe.as(Void*))
        elsif arg.is_a?(Godot::Vector2)
          v2_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 5, data: (v2_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Vector3)
          v3_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 6, data: (v3_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Object)
          obj_storage[idx] = arg.pointer
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 7, data: (obj_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Color)
          color_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 8, data: (color_storage.to_unsafe + idx).as(Void*))
        end
      end

      @@api.value.object_call_deferred.call(godot_obj, method_name.to_unsafe, c_args.to_unsafe, count)
    end

    def self.object_call(godot_obj : Void*, method_name : String) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.object_call.pointer.null?
      @@api.value.object_call.call(godot_obj, method_name.to_unsafe, Pointer(LibBridge::CrystalSignalArg).null, 0)
    end

    def self.object_call(godot_obj : Void*, method_name : String, *args) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.object_call.pointer.null?
      if args.empty?
        object_call(godot_obj, method_name)
        return
      end

      c_args = StaticArray(LibBridge::CrystalSignalArg, 16).new(LibBridge::CrystalSignalArg.new)
      int_storage = StaticArray(Int64, 16).new(0_i64)
      float_storage = StaticArray(Float64, 16).new(0.0_f64)
      bool_storage = StaticArray(UInt8, 16).new(0_u8)
      v2_storage = StaticArray(Godot::Vector2, 16).new(Godot::Vector2.new)
      v3_storage = StaticArray(Godot::Vector3, 16).new(Godot::Vector3.new)
      color_storage = StaticArray(Godot::Color, 16).new(Godot::Color.new)
      obj_storage = StaticArray(Void*, 16).new(Pointer(Void).null)

      count = [args.size, 16].min
      args.each_with_index do |arg, idx|
        break if idx >= 16
        if arg.is_a?(Bool)
          bool_storage[idx] = arg ? 1_u8 : 0_u8
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 1, data: (bool_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Int)
          int_storage[idx] = arg.to_i64
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 2, data: (int_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Float)
          float_storage[idx] = arg.to_f64
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 3, data: (float_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(String)
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 4, data: arg.to_unsafe.as(Void*))
        elsif arg.is_a?(Godot::Vector2)
          v2_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 5, data: (v2_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Vector3)
          v3_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 6, data: (v3_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Object)
          obj_storage[idx] = arg.pointer
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 7, data: (obj_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Color)
          color_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 8, data: (color_storage.to_unsafe + idx).as(Void*))
        end
      end

      @@api.value.object_call.call(godot_obj, method_name.to_unsafe, c_args.to_unsafe, count)
    end

    def self.node_find_child(godot_obj : Void*, pattern : String, recursive : Bool = true, owned : Bool = false) : Void*
      return Pointer(Void).null if godot_obj.null? || @@api.null? || @@api.value.node_find_child.pointer.null?
      @@api.value.node_find_child.call(godot_obj, pattern.to_unsafe, recursive, owned)
    end

    def self.node_get_node(godot_obj : Void*, path : String) : Void*
      return Pointer(Void).null if godot_obj.null? || @@api.null? || @@api.value.node_get_node.pointer.null?
      @@api.value.node_get_node.call(godot_obj, path.to_unsafe)
    end

    def self.range_set_value(godot_obj : Void*, value : Float64) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.range_set_value.pointer.null?
      @@api.value.range_set_value.call(godot_obj, value)
    end

    def self.node_rpc_config(godot_obj : Void*, method : String, rpc_mode : Int32, transfer_mode : Int32, call_local : Bool, channel : Int32) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.node_rpc_config.pointer.null?
      @@api.value.node_rpc_config.call(godot_obj, method.to_unsafe, rpc_mode, transfer_mode, call_local, channel)
    end

    def self.resource_loader_load(path : String, type_hint : String = "", cache_mode : Int64 = 0_i64) : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.resource_loader_load.pointer.null?
      @@api.value.resource_loader_load.call(path.to_unsafe, type_hint.to_unsafe, cache_mode)
    end

    def self.packed_scene_instantiate(scene_ptr : Void*, edit_state : Int64 = 0_i64) : Void*
      return Pointer(Void).null if scene_ptr.null? || @@api.null? || @@api.value.packed_scene_instantiate.pointer.null?
      @@api.value.packed_scene_instantiate.call(scene_ptr, edit_state)
    end

    def self.node_get_name(godot_obj : Void*) : String
      return "" if godot_obj.null? || @@api.null? || @@api.value.node_get_name.pointer.null?
      ptr = @@api.value.node_get_name.call(godot_obj)
      ptr.null? ? "" : String.new(ptr)
    end

    def self.construct_object(class_name : String) : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.classdb_construct_object.pointer.null?
      @@api.value.classdb_construct_object.call(class_name.to_unsafe)
    end

    private def self.pack_args(args, &block : Pointer(LibBridge::CrystalSignalArg), Int32 -> T) : T forall T
      if args.empty?
        return yield Pointer(LibBridge::CrystalSignalArg).null, 0
      end
      c_args = StaticArray(LibBridge::CrystalSignalArg, 16).new(LibBridge::CrystalSignalArg.new)
      int_storage = StaticArray(Int64, 16).new(0_i64)
      float_storage = StaticArray(Float64, 16).new(0.0_f64)
      bool_storage = StaticArray(UInt8, 16).new(0_u8)
      v2_storage = StaticArray(Godot::Vector2, 16).new(Godot::Vector2.new)
      v3_storage = StaticArray(Godot::Vector3, 16).new(Godot::Vector3.new)
      color_storage = StaticArray(Godot::Color, 16).new(Godot::Color.new)
      obj_storage = StaticArray(Void*, 16).new(Pointer(Void).null)

      count = [args.size, 16].min
      args.each_with_index do |arg, idx|
        break if idx >= 16
        if arg.is_a?(Bool)
          bool_storage[idx] = arg ? 1_u8 : 0_u8
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 1, data: (bool_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Int)
          int_storage[idx] = arg.to_i64
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 2, data: (int_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Float)
          float_storage[idx] = arg.to_f64
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 3, data: (float_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(String)
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 4, data: arg.to_unsafe.as(Void*))
        elsif arg.is_a?(Godot::Vector2)
          v2_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 5, data: (v2_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Vector3)
          v3_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 6, data: (v3_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Object)
          obj_storage[idx] = arg.pointer
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 7, data: (obj_storage.to_unsafe + idx).as(Void*))
        elsif arg.is_a?(Godot::Color)
          color_storage[idx] = arg
          c_args[idx] = LibBridge::CrystalSignalArg.new(arg_type: 8, data: (color_storage.to_unsafe + idx).as(Void*))
        end
      end
      yield c_args.to_unsafe, count
    end

    def self.object_call_ret_object(godot_obj : Void*, method_name : String, *args) : Void*
      return Pointer(Void).null if godot_obj.null? || @@api.null? || @@api.value.object_call_ret_object.pointer.null?
      pack_args(args) do |c_args, count|
        @@api.value.object_call_ret_object.call(godot_obj, method_name.to_unsafe, c_args, count)
      end
    end

    def self.object_call_ret_int(godot_obj : Void*, method_name : String, *args) : Int64
      return 0_i64 if godot_obj.null? || @@api.null? || @@api.value.object_call_ret_int.pointer.null?
      pack_args(args) do |c_args, count|
        @@api.value.object_call_ret_int.call(godot_obj, method_name.to_unsafe, c_args, count)
      end
    end

    def self.object_call_ret_float(godot_obj : Void*, method_name : String, *args) : Float64
      return 0.0_f64 if godot_obj.null? || @@api.null? || @@api.value.object_call_ret_float.pointer.null?
      pack_args(args) do |c_args, count|
        @@api.value.object_call_ret_float.call(godot_obj, method_name.to_unsafe, c_args, count)
      end
    end

    def self.object_call_ret_bool(godot_obj : Void*, method_name : String, *args) : Bool
      return false if godot_obj.null? || @@api.null? || @@api.value.object_call_ret_bool.pointer.null?
      pack_args(args) do |c_args, count|
        @@api.value.object_call_ret_bool.call(godot_obj, method_name.to_unsafe, c_args, count)
      end
    end

    def self.object_call_ret_string(godot_obj : Void*, method_name : String, *args) : String
      return "" if godot_obj.null? || @@api.null? || @@api.value.object_call_ret_string.pointer.null?
      pack_args(args) do |c_args, count|
        ptr = @@api.value.object_call_ret_string.call(godot_obj, method_name.to_unsafe, c_args, count)
        ptr.null? ? "" : String.new(ptr)
      end
    end

    def self.object_destroy(godot_obj : Void*) : Void
      return if godot_obj.null? || @@api.null? || @@api.value.object_destroy.pointer.null?
      @@api.value.object_destroy.call(godot_obj)
    end

    def self.object_get_instance_id(godot_obj : Void*) : UInt64
      return 0_u64 if godot_obj.null? || @@api.null? || @@api.value.object_get_instance_id.pointer.null?
      @@api.value.object_get_instance_id.call(godot_obj)
    end

    def self.object_get_instance_from_id(id : UInt64) : Void*
      return Pointer(Void).null if id == 0 || @@api.null? || @@api.value.object_get_instance_from_id.pointer.null?
      @@api.value.object_get_instance_from_id.call(id)
    end

    def self.is_instance_valid(id : UInt64) : Bool
      return false if id == 0 || @@api.null? || @@api.value.is_instance_valid.pointer.null?
      @@api.value.is_instance_valid.call(id) != 0_u8
    end

    def self.unregister_alive_instance_by_ptr(godot_obj : Void*) : Void
      return if godot_obj.null?
      @@alive_mutex.synchronize do
        @@alive_instances_by_ptr.delete(godot_obj)
      end
    end

    def self.find_alive_instance(godot_obj : Void*) : Godot::Object?
      return nil if godot_obj.null?
      @@alive_mutex.synchronize do
        if inst = @@alive_instances_by_ptr[godot_obj]?
          if inst.destroyed? || (inst.instance_id > 0 && !is_instance_valid(inst.instance_id))
            @@alive_instances_by_ptr.delete(godot_obj)
            return nil
          end
          if inst.instance_id > 0
            cur_id = object_get_instance_id(godot_obj)
            if cur_id > 0 && cur_id != inst.instance_id
              @@alive_instances_by_ptr.delete(godot_obj)
              return nil
            end
          end
          inst
        else
          nil
        end
      end
    end

    def self.ret_string(ret : Void*, str : String) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_string.pointer.null?
      @@api.value.ret_string.call(ret, str.to_unsafe)
    end

    def self.type_from_variant(type : Int32, dst : Void*, variant_ptr : Void*) : Void
      return if @@api.null? || @@api.value.type_from_variant.pointer.null?
      @@api.value.type_from_variant.call(type, dst, variant_ptr)
    end

    def self.variant_from_type(type : Int32, variant_ptr : Void*, src : Void*) : Void
      return if @@api.null? || @@api.value.variant_from_type.pointer.null?
      @@api.value.variant_from_type.call(type, variant_ptr, src)
    end

    def self.ret_string_name(ret : Void*, str : String) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_string_name.pointer.null?
      @@api.value.ret_string_name.call(ret, str.to_unsafe)
    end

    def self.ret_packed_string_array(ret : Void*, strings : Array(String)) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_packed_string_array.pointer.null?
      c_strings = Pointer(LibC::Char*).malloc(strings.size > 0 ? strings.size : 1)
      strings.each_with_index do |s, idx|
        c_strings[idx] = s.to_unsafe
      end
      @@api.value.ret_packed_string_array.call(ret, c_strings, strings.size)
    end

    def self.ret_dictionary_empty(ret : Void*) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_dictionary_empty.pointer.null?
      @@api.value.ret_dictionary_empty.call(ret)
    end

    def self.ret_dictionary_validate(ret : Void*, valid : Bool) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_dictionary_validate.pointer.null?
      @@api.value.ret_dictionary_validate.call(ret, valid ? 1_u8 : 0_u8)
    end

    def self.ret_dictionary_complete_code(ret : Void*) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_dictionary_complete_code.pointer.null?
      @@api.value.ret_dictionary_complete_code.call(ret)
    end

    def self.ret_dictionary_lookup_code(ret : Void*) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_dictionary_lookup_code.pointer.null?
      @@api.value.ret_dictionary_lookup_code.call(ret)
    end

    def self.ret_dictionary_complete_code_ex(
      ret : Void*,
      result : Int64,
      force : Bool,
      call_hint : String,
      options : Slice(BridgeCompletionOption) | Array(BridgeCompletionOption)
    ) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_dictionary_complete_code_ex.pointer.null?
      opt_ptr = options.empty? ? Pointer(BridgeCompletionOption).null : options.to_unsafe
      @@api.value.ret_dictionary_complete_code_ex.call(
        ret,
        result,
        force ? 1_u8 : 0_u8,
        call_hint.to_unsafe,
        opt_ptr,
        options.size.to_i32
      )
    end

    def self.ret_dictionary_lookup_code_ex(
      ret : Void*,
      result : Int64,
      type : Int64,
      class_name : String,
      class_member : String,
      description : String,
      script_path : String,
      location : Int64
    ) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_dictionary_lookup_code_ex.pointer.null?
      @@api.value.ret_dictionary_lookup_code_ex.call(
        ret,
        result,
        type,
        class_name.to_unsafe,
        class_member.to_unsafe,
        description.to_unsafe,
        script_path.to_unsafe,
        location
      )
    end

    def self.ret_dictionary_global_class(ret : Void*, class_name : String, base_type : String = "Node", icon_path : String = "") : Void
      return if ret.null? || @@api.null? || @@api.value.ret_dictionary_global_class.pointer.null?
      @@api.value.ret_dictionary_global_class.call(ret, class_name.to_unsafe, base_type.to_unsafe, icon_path.to_unsafe)
    end

    def self.placeholder_script_instance_create(language : Void*, script : Void*, owner : Void*) : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.placeholder_script_instance_create.pointer.null?
      @@api.value.placeholder_script_instance_create.call(language, script, owner)
    end

    def self.text_edit_get_line(text_edit : Void*, line : Int64) : String
      return "" if text_edit.null? || @@api.null? || @@api.value.text_edit_get_line.pointer.null?
      buf = StaticArray(UInt8, 4096).new(0_u8)
      len = @@api.value.text_edit_get_line.call(text_edit, line, buf.to_unsafe.as(LibC::Char*), 4096)
      len > 0 ? String.new(buf.to_slice[0, len]) : ""
    end

    def self.ret_array_empty(ret : Void*) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_array_empty.pointer.null?
      @@api.value.ret_array_empty.call(ret)
    end

    def self.ret_signal_list(ret : Void*, signals : Slice(LibBridge::CrystalSignalDesc) | Array(LibBridge::CrystalSignalDesc)) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_signal_list.pointer.null?
      sig_ptr = signals.empty? ? Pointer(LibBridge::CrystalSignalDesc).null : signals.to_unsafe
      @@api.value.ret_signal_list.call(ret, sig_ptr, signals.size.to_i32)
    end

    def self.ret_property_list(ret : Void*, props : Slice(LibBridge::CrystalPropertyDesc) | Array(LibBridge::CrystalPropertyDesc)) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_property_list.pointer.null?
      prop_ptr = props.empty? ? Pointer(LibBridge::CrystalPropertyDesc).null : props.to_unsafe
      @@api.value.ret_property_list.call(ret, prop_ptr, props.size.to_i32)
    end

    def self.ret_object(ret : Void*, obj_ptr : Void*) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_object.pointer.null?
      @@api.value.ret_object.call(ret, obj_ptr)
    end

    def self.ret_ref(ret : Void*, obj_ptr : Void*) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_ref.pointer.null?
      @@api.value.ret_ref.call(ret, obj_ptr)
    end

    def self.ret_variant_object(ret : Void*, obj_ptr : Void*) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_variant_object.pointer.null?
      @@api.value.ret_variant_object.call(ret, obj_ptr)
    end

    def self.ret_variant_nil(ret : Void*) : Void
      return if ret.null? || @@api.null? || @@api.value.ret_variant_nil.pointer.null?
      @@api.value.ret_variant_nil.call(ret)
    end

    def self.highlighter_add_span(ret : Void*, col : Int64, r : Float32, g : Float32, b : Float32, a : Float32 = 1.0_f32) : Void
      return if ret.null? || @@api.null? || @@api.value.highlighter_add_span.pointer.null?
      @@api.value.highlighter_add_span.call(ret, col, r, g, b, a)
    end

    def self.arg_to_string(arg_ptr : Void*) : String
      return "" if arg_ptr.null? || @@api.null? || @@api.value.arg_to_string.pointer.null?
      total_len = @@api.value.arg_to_string.call(arg_ptr, Pointer(LibC::Char).null, 0)
      return "" if total_len <= 0
      buf = Bytes.new(total_len + 1)
      written = @@api.value.arg_to_string.call(arg_ptr, buf.to_unsafe.as(LibC::Char*), total_len + 1)
      written > 0 ? String.new(buf[0, written]) : ""
    end

    def self.arg_to_string_name(arg_ptr : Void*) : String
      return "" if arg_ptr.null? || @@api.null? || @@api.value.arg_to_string_name.pointer.null?
      buf = Bytes.new(512)
      len = @@api.value.arg_to_string_name.call(arg_ptr, buf.to_unsafe.as(LibC::Char*), 512)
      len > 0 ? String.new(buf[0, len]) : ""
    end

    def self.make_string_name(str : String) : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.make_string_name.pointer.null?
      @@api.value.make_string_name.call(str.to_unsafe)
    end

    def self.free_string_name(ptr : Void*?) : Void
      return if ptr.nil? || ptr.null? || @@api.null? || @@api.value.free_string_name.pointer.null?
      @@api.value.free_string_name.call(ptr)
    end

    def self.make_string(str : String) : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.make_string.pointer.null?
      @@api.value.make_string.call(str.to_unsafe)
    end

    def self.free_string(ptr : Void*?) : Void
      return if ptr.nil? || ptr.null? || @@api.null? || @@api.value.free_string.pointer.null?
      @@api.value.free_string.call(ptr)
    end

    def self.make_nodepath(path : String) : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.make_nodepath.pointer.null?
      @@api.value.make_nodepath.call(path.to_unsafe)
    end

    def self.free_nodepath(ptr : Void*?) : Void
      return if ptr.nil? || ptr.null? || @@api.null? || @@api.value.free_nodepath.pointer.null?
      @@api.value.free_nodepath.call(ptr)
    end

    def self.is_loader_registered? : Bool
      return false if @@api.null? || @@api.value.is_loader_registered.pointer.null?
      @@api.value.is_loader_registered.call != 0
    end

    def self.set_loader_registered(registered : Bool) : Void
      return if @@api.null? || @@api.value.set_loader_registered.pointer.null?
      @@api.value.set_loader_registered.call(registered ? 1 : 0)
    end

    def self.is_saver_registered? : Bool
      return false if @@api.null? || @@api.value.is_saver_registered.pointer.null?
      @@api.value.is_saver_registered.call != 0
    end

    def self.set_saver_registered(registered : Bool) : Void
      return if @@api.null? || @@api.value.set_saver_registered.pointer.null?
      @@api.value.set_saver_registered.call(registered ? 1 : 0)
    end

    def self.is_language_registered? : Bool
      return false if @@api.null? || @@api.value.is_language_registered.pointer.null?
      @@api.value.is_language_registered.call != 0
    end

    def self.set_language_registered(registered : Bool) : Void
      return if @@api.null? || @@api.value.set_language_registered.pointer.null?
      @@api.value.set_language_registered.call(registered ? 1 : 0)
    end

    def self.get_language_object : Void*
      return Pointer(Void).null if @@api.null? || @@api.value.get_language_object.pointer.null?
      @@api.value.get_language_object.call
    end

    def self.set_language_object(obj : Void*) : Void
      return if @@api.null? || @@api.value.set_language_object.pointer.null?
      @@api.value.set_language_object.call(obj)
    end

    def self.set_reloading(reloading : Bool) : Void
      return if @@api.null? || @@api.value.set_reloading.pointer.null?
      @@api.value.set_reloading.call(reloading ? 1 : 0)
    end

    def self.set_debugger_cleanup(callback : -> Void) : Void
      return if @@api.null? || @@api.value.set_debugger_cleanup.pointer.null?
      @@api.value.set_debugger_cleanup.call(callback)
    end

    def self.trigger_debugger_cleanup : Void
      return if @@api.null? || @@api.value.trigger_debugger_cleanup.pointer.null?
      @@api.value.trigger_debugger_cleanup.call
    end

    def self.ref_get_object(ref_ptr : Void*) : Void*
      return Pointer(Void).null if ref_ptr.null? || @@api.null? || @@api.value.ref_get_object.pointer.null?
      @@api.value.ref_get_object.call(ref_ptr)
    end

    def self.script_get_source_code(script_obj : Void*) : String
      return "" if script_obj.null? || @@api.null? || @@api.value.script_get_source_code.pointer.null?
      ptr = @@api.value.script_get_source_code.call(script_obj)
      ptr.null? ? "" : String.new(ptr)
    end

    def self.resource_get_path(res_obj : Void*) : String
      return "" if res_obj.null? || @@api.null? || @@api.value.resource_get_path.pointer.null?
      ptr = @@api.value.resource_get_path.call(res_obj)
      ptr.null? ? "" : String.new(ptr)
    end

    def self.object_is_class(obj : Void*, class_name : String) : Bool
      return false if obj.null? || @@api.null? || @@api.value.object_is_class.pointer.null?
      @@api.value.object_is_class.call(obj, class_name.to_unsafe)
    end

    def self.object_class_name(obj : Void*) : String
      return "" if obj.null? || @@api.null? || @@api.value.object_get_class_name.pointer.null?
      buf = uninitialized UInt8[128]
      @@api.value.object_get_class_name.call(obj, buf.to_unsafe.as(LibC::Char*), 128)
      String.new(buf.to_unsafe)
    end
  end
end

lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**) : Void
end

lib LibGCBridge
  fun init = GC_init : Void
  fun allow_register_threads = GC_allow_register_threads : Void
  fun register_my_thread = GC_register_my_thread(sb : Void*) : LibC::Int
  fun unregister_my_thread = GC_unregister_my_thread : Void
  fun get_stack_base = GC_get_stack_base(sb : Void*) : LibC::Int
  fun thread_is_registered = GC_thread_is_registered : LibC::Int
  {% unless flag?(:win32) %}
    fun get_suspend_signal = GC_get_suspend_signal : LibC::Int
    fun get_thr_restart_signal = GC_get_thr_restart_signal : LibC::Int
    fun set_suspend_signal = GC_set_suspend_signal(sig : LibC::Int) : Void
    fun set_thr_restart_signal = GC_set_thr_restart_signal(sig : LibC::Int) : Void
  {% end %}
end

# C ABI Entry point called by crystal_bridge when game library is loaded
fun crystal_godot_init(api : Godot::LibBridge::BridgeAPI*) : Void
  if Godot::Bridge.init_done?
    Godot::Bridge.init(api)
    return
  end
  Godot::Bridge.init_done = true
  {% unless flag?(:win32) %}
    if !api.null? && !api.value.get_gc_signals.pointer.null?
      sus_sig = 0
      res_sig = 0
      api.value.get_gc_signals.call(pointerof(sus_sig), pointerof(res_sig))
      if sus_sig > 0 && res_sig > 0
        LibGCBridge.set_suspend_signal(sus_sig)
        LibGCBridge.set_thr_restart_signal(res_sig)
      end
    end
  {% end %}
  if !api.null? && !api.value.register_gc_functions.pointer.null?
    gc_funcs = Godot::LibBridge::BridgeGCFunctions.new
    gc_funcs.gc_init = ->LibGCBridge.init
    gc_funcs.register_my_thread = ->LibGCBridge.register_my_thread(Void*)
    gc_funcs.unregister_my_thread = ->LibGCBridge.unregister_my_thread
    gc_funcs.thread_is_registered = ->LibGCBridge.thread_is_registered
    gc_funcs.allow_register_threads = ->LibGCBridge.allow_register_threads
    gc_funcs.get_stack_base = ->LibGCBridge.get_stack_base(Void*)
    {% unless flag?(:win32) %}
      gc_funcs.get_suspend_signal = ->LibGCBridge.get_suspend_signal
      gc_funcs.get_thr_restart_signal = ->LibGCBridge.get_thr_restart_signal
    {% end %}
    api.value.register_gc_functions.call(pointerof(gc_funcs))
  end
  GC.init
  Crystal.init_runtime
  dummy_arg = "game".to_unsafe
  dummy_argv = pointerof(dummy_arg)
  LibCrystalMain.__crystal_main(1, dummy_argv)
  Godot::Bridge.init(api)
  {% unless flag?(:release) %}
    Godot::Debugger::Agent.initialize_agent rescue nil
  {% end %}
  {% unless flag?(:release) || flag?(:libgodot_addon) || flag?(:no_editor) %}
    Godot::CrystalLanguage.ensure_registered rescue nil
    Godot::ResourceFormatLoaderCrystal.ensure_registered rescue nil
    Godot::ResourceFormatSaverCrystal.ensure_registered rescue nil
    if ::ENV["LIBGODOT_TEST_BUILD_BUTTON"]? == "1"
      Godot::CrystalIntegrationPlugin.check_test_build_button_flow rescue nil
    end
  {% end %}
end

{% if flag?(:libgodot_addon) %}
  @[NoInline]
  fun crystal_godot_is_addon : LibC::Int
    1
  end
{% end %}
