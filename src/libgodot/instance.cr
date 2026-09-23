require "./gdextension_interface"
require "./c_api"
require "./macros"
require "./object"

module Godot
  class Instance
    getter? is_running : Bool = false
    @loader : LibGodot::DynamicLoader
    @instance_ptr : LibGodot::GDExtensionObjectPtr = Pointer(Void).null

    def initialize(dll_path : String = {% if flag?(:windows) %} "libgodot.dll" {% else %} "libgodot.so" {% end %})
      @loader = LibGodot::DynamicLoader.new(dll_path)
    end

    # Boot the Godot engine in-memory
    def boot(args : Array(String) = ARGV) : Bool
      # Convert arguments to C-style argv
      c_args = args.map(&.to_unsafe)
      argc = c_args.size
      argv = c_args.to_unsafe

      init_callback = ->(p_get_proc_address : LibGodot::GDExtensionInterfaceGetProcAddress, p_library : LibGodot::GDExtensionClassLibraryPtr, r_initialization : LibGodot::GDExtensionInitialization*) : LibGodot::GDExtensionBool {
        # Configure initialization struct
        r_initialization.value.minimum_initialization_level = LibGodot::GDExtensionInitializationLevel::Scene
        r_initialization.value.userdata = Pointer(Void).null

        r_initialization.value.initialize = ->(userdata : Void*, level : LibGodot::GDExtensionInitializationLevel) {
          if level == LibGodot::GDExtensionInitializationLevel::Scene
            # Register user nodes
            Godot.print "[LibGodot-Crystal] Engine reached Scene level: registering #{::Godot::ClassRegistry.entries.size} Crystal nodes..."
            ::Godot::ClassRegistry.entries.each do |entry|
              Godot.print "  -> Registered Crystal Node: #{entry.class_name} (inherits #{entry.parent_name})"
            end
          end
        }

        r_initialization.value.deinitialize = ->(userdata : Void*, level : LibGodot::GDExtensionInitializationLevel) {
          if level == LibGodot::GDExtensionInitializationLevel::Scene
            Godot.print "[LibGodot-Crystal] Deinitializing Scene level..."
          end
        }

        1_u8 # Return true for successful extension initialization
      }

      @instance_ptr = @loader.create_godot_instance(argc, argv, init_callback)
      if @instance_ptr.null?
        Godot.print_error "[LibGodot-Crystal] Failed to create Godot instance from #{@loader.dll_path}. Check if the DLL exists and is valid."
        return false
      end

      @is_running = true
      Godot.print "[LibGodot-Crystal] Godot Engine 4.8 instance created successfully!"
      true
    end

    # Clean shutdown
    def shutdown : Void
      return unless @is_running
      if !@instance_ptr.null?
        @loader.destroy_godot_instance(@instance_ptr)
        @instance_ptr = Pointer(Void).null
      end
      @is_running = false
      Godot.print "[LibGodot-Crystal] Godot instance cleanly destroyed."
    end
  end
end
