module Godot
  # ===========================================================================
  # ConfigFile Ergonomic Extensions
  # ===========================================================================
  class ConfigFile

    # Sets a value for a section and key with automatic variant conversion, returning value for chaining
    def set_value(section : String, key : String, value)
      call("set_value", section, key, value)
      value
    end

    # Sets a value using indexer syntax: `cfg["audio", "master_volume"] = 1.0`, returning value for chaining
    def []=(section : String, key : String, value)
      call("set_value", section, key, value)
      value
    end

    # Gets a value for section and key as Variant
    def [](section : String, key : String) : Variant
      call_variant("get_value", section, key)
    end

    # Gets a Float64 value for a section and key with an optional default
    def get_value_f64(section : String, key : String, default : Float64 = 0.0_f64) : Float64
      call_f64("get_value", section, key, default)
    end

    # Gets a String value for a section and key with an optional default
    def get_value_str(section : String, key : String, default : String = "") : String
      call_str("get_value", section, key, default)
    end

    # Gets an Int64 value for a section and key with an optional default
    def get_value_i64(section : String, key : String, default : Int64 = 0_i64) : Int64
      call_i64("get_value", section, key, default)
    end

    # Gets a Bool value for a section and key with an optional default
    def get_value_bool(section : String, key : String, default : Bool = false) : Bool
      call_bool("get_value", section, key, default)
    end
  end
end
