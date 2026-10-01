module LibGodot
  alias GDExtensionBool = UInt8
  alias GDExtensionInt = Int64
  alias GDExtensionFloat = Float64

  alias GDExtensionVariantPtr = Void*
  alias GDExtensionConstVariantPtr = Void*
  alias GDExtensionUninitializedVariantPtr = Void*
  alias GDExtensionStringNamePtr = Void*
  alias GDExtensionConstStringNamePtr = Void*
  alias GDExtensionUninitializedStringNamePtr = Void*
  alias GDExtensionStringPtr = Void*
  alias GDExtensionConstStringPtr = Void*
  alias GDExtensionUninitializedStringPtr = Void*
  alias GDExtensionObjectPtr = Void*
  alias GDExtensionConstObjectPtr = Void*
  alias GDExtensionTypePtr = Void*
  alias GDExtensionConstTypePtr = Void*
  alias GDExtensionUninitializedTypePtr = Void*
  alias GDExtensionMethodBindPtr = Void*
  alias GDExtensionClassLibraryPtr = Void*

  enum GDExtensionInitializationLevel
    Core    = 0
    Servers = 1
    Scene   = 2
    Editor  = 3
  end

  enum GDExtensionVariantType
    Nil                =  0
    Bool               =  1
    Int                =  2
    Float              =  3
    String             =  4
    Vector2            =  5
    Vector2i           =  6
    Rect2              =  7
    Rect2i             =  8
    Vector3            =  9
    Vector3i           = 10
    Transform2D        = 11
    Vector4            = 12
    Vector4i           = 13
    Plane              = 14
    Quaternion         = 15
    AABB               = 16
    Basis              = 17
    Transform3D        = 18
    Projection         = 19
    Color              = 20
    StringName         = 21
    NodePath           = 22
    RID                = 23
    Object             = 24
    Callable           = 25
    Signal             = 26
    Dictionary         = 27
    Array              = 28
    PackedByteArray    = 29
    PackedInt32Array   = 30
    PackedInt64Array   = 31
    PackedFloat32Array = 32
    PackedFloat64Array = 33
    PackedStringArray  = 34
    PackedVector2Array = 35
    PackedVector3Array = 36
    PackedColorArray   = 37
    PackedVector4Array = 38
    VariantMax         = 39
  end

  enum GDExtensionCallErrorType
    Ok               = 0
    InvalidMethod    = 1
    InvalidArgument  = 2
    TooManyArguments = 3
    TooFewArguments  = 4
    InstanceIsNull   = 5
    MethodCallFailed = 6
  end

  enum GDExtensionClassMethodArgumentMetadata
    None          =  0
    IntIsInt8     =  1
    IntIsInt16    =  2
    IntIsInt32    =  3
    IntIsInt64    =  4
    IntIsUint8    =  5
    IntIsUint16   =  6
    IntIsUint32   =  7
    IntIsUint64   =  8
    FloatIsFloat  =  9
    FloatIsDouble = 10
  end

  @[Flags]
  enum GDExtensionClassMethodFlags
    Normal  =  1
    Editor  =  2
    Const   =  4
    Virtual =  8
    Vararg  = 16
    Static  = 32
  end

  alias GDExtensionInterfaceFunctionPtr = (-> Void)
  alias GDExtensionInterfaceGetProcAddress = (UInt8* -> GDExtensionInterfaceFunctionPtr)
  alias GDExtensionInitializeCallback = (Void*, GDExtensionInitializationLevel -> Void)
  alias GDExtensionDeinitializeCallback = (Void*, GDExtensionInitializationLevel -> Void)

  alias GDExtensionClassCreateInstance = (Void* -> GDExtensionObjectPtr)
  alias GDExtensionClassFreeInstance = (Void*, GDExtensionTypePtr -> Void)
  alias GDExtensionClassMethodCall = (Void*, GDExtensionTypePtr, GDExtensionConstVariantPtr*, GDExtensionInt, GDExtensionVariantPtr, Void* -> Void)
  alias GDExtensionClassMethodPtrCall = (Void*, GDExtensionTypePtr, GDExtensionConstTypePtr*, GDExtensionTypePtr -> Void)

  lib ABI
    struct GDExtensionCallError
      error : GDExtensionCallErrorType
      argument : Int32
      expected : Int32
    end

    struct GDExtensionInitialization
      minimum_initialization_level : GDExtensionInitializationLevel
      userdata : Void*
      initialize : GDExtensionInitializeCallback
      deinitialize : GDExtensionDeinitializeCallback
    end

    struct GDExtensionPropertyInfo
      type : GDExtensionVariantType
      name : GDExtensionStringNamePtr
      class_name : GDExtensionStringNamePtr
      hint : UInt32
      hint_string : GDExtensionStringPtr
      usage : UInt32
    end

    struct GDExtensionClassMethodInfo
      name : GDExtensionStringNamePtr
      method_userdata : Void*
      call_func : GDExtensionClassMethodCall
      ptrcall_func : GDExtensionClassMethodPtrCall
      method_flags : UInt32
      has_return_value : GDExtensionBool
      return_value_info : GDExtensionPropertyInfo*
      return_value_metadata : GDExtensionClassMethodArgumentMetadata
      argument_count : UInt32
      arguments_info : GDExtensionPropertyInfo*
      arguments_metadata : GDExtensionClassMethodArgumentMetadata*
      default_argument_count : UInt32
      default_arguments : GDExtensionVariantPtr*
    end

    struct GDExtensionClassCreationInfo4
      is_virtual : GDExtensionBool
      is_abstract : GDExtensionBool
      is_exposed : GDExtensionBool
      is_runtime : GDExtensionBool
      set_func : (Void*, GDExtensionConstStringNamePtr, GDExtensionConstVariantPtr -> GDExtensionBool)
      get_func : (Void*, GDExtensionConstStringNamePtr, GDExtensionVariantPtr -> GDExtensionBool)
      get_property_list_func : (Void*, UInt32* -> GDExtensionPropertyInfo*)
      free_property_list_func : (Void*, GDExtensionPropertyInfo*, UInt32 -> Void)
      property_can_revert_func : (Void*, GDExtensionConstStringNamePtr -> GDExtensionBool)
      property_get_revert_func : (Void*, GDExtensionConstStringNamePtr, GDExtensionVariantPtr -> GDExtensionBool)
      validate_property_func : (Void*, GDExtensionPropertyInfo* -> GDExtensionBool)
      notification_func : (Void*, Int32, GDExtensionBool -> Void)
      to_string_func : (Void*, GDExtensionBool*, GDExtensionStringPtr -> Void)
      reference_func : (Void* -> Void)
      unreference_func : (Void* -> Void)
      create_instance_func : GDExtensionClassCreateInstance
      free_instance_func : GDExtensionClassFreeInstance
      recreate_instance_func : (Void*, GDExtensionObjectPtr -> GDExtensionTypePtr)
      get_virtual_func : (Void*, GDExtensionConstStringNamePtr -> GDExtensionInterfaceFunctionPtr)
      get_virtual_call_data_func : (Void*, GDExtensionConstStringNamePtr -> Void*)
      call_virtual_with_data_func : (Void*, GDExtensionConstStringNamePtr, Void*, GDExtensionTypePtr, GDExtensionConstTypePtr*, GDExtensionTypePtr -> Void)
      class_userdata : Void*
    end

    struct GDExtensionClassCreationInfo6
      is_virtual : GDExtensionBool
      is_abstract : GDExtensionBool
      is_exposed : GDExtensionBool
      is_runtime : GDExtensionBool
      icon_path : GDExtensionConstStringPtr
      set_func : (Void*, GDExtensionConstStringNamePtr, GDExtensionConstVariantPtr -> GDExtensionBool)
      get_func : (Void*, GDExtensionConstStringNamePtr, GDExtensionVariantPtr -> GDExtensionBool)
      get_property_list_func : (Void*, UInt32* -> GDExtensionPropertyInfo*)
      free_property_list_func : (Void*, GDExtensionPropertyInfo*, UInt32 -> Void)
      property_can_revert_func : (Void*, GDExtensionConstStringNamePtr -> GDExtensionBool)
      property_get_revert_func : (Void*, GDExtensionConstStringNamePtr, GDExtensionVariantPtr -> GDExtensionBool)
      validate_property_func : (Void*, GDExtensionPropertyInfo* -> GDExtensionBool)
      notification_func : (Void*, Int32, GDExtensionBool -> Void)
      to_string_func : (Void*, GDExtensionBool*, GDExtensionStringPtr -> Void)
      reference_func : (Void* -> Void)
      unreference_func : (Void* -> Void)
      create_instance_func : (Void*, GDExtensionBool -> GDExtensionObjectPtr)
      free_instance_func : GDExtensionClassFreeInstance
      recreate_instance_func : (Void*, GDExtensionObjectPtr -> GDExtensionTypePtr)
      get_virtual_func : (Void*, GDExtensionConstStringNamePtr, UInt32 -> GDExtensionInterfaceFunctionPtr)
      get_virtual_call_data_func : (Void*, GDExtensionConstStringNamePtr, UInt32 -> Void*)
      call_virtual_with_data_func : (Void*, GDExtensionConstStringNamePtr, Void*, GDExtensionTypePtr, GDExtensionConstTypePtr*, GDExtensionTypePtr -> Void)
      class_userdata : Void*
    end
  end

  alias GDExtensionInitialization = ABI::GDExtensionInitialization
  alias GDExtensionPropertyInfo = ABI::GDExtensionPropertyInfo
  alias GDExtensionClassMethodInfo = ABI::GDExtensionClassMethodInfo
  alias GDExtensionClassCreationInfo4 = ABI::GDExtensionClassCreationInfo4
  alias GDExtensionClassCreationInfo6 = ABI::GDExtensionClassCreationInfo6
  alias GDExtensionCallError = ABI::GDExtensionCallError
  alias GDExtensionInitializationFunction = (GDExtensionInterfaceGetProcAddress, GDExtensionClassLibraryPtr, GDExtensionInitialization* -> GDExtensionBool)
end
