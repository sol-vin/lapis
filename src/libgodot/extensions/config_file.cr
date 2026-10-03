module Godot
  # ===========================================================================
  # ConfigFile Ergonomic Extensions
  # ===========================================================================
  class ConfigFile < RefCounted
    @local_store : ::Hash(String, ::Hash(String, Variant))? = nil

    private def local_store : ::Hash(String, ::Hash(String, Variant))
      @local_store ||= ::Hash(String, ::Hash(String, Variant)).new
    end

    # Sets a value for a section and key with automatic variant conversion, returning value for chaining
    def set_value(section : String, key : String, value)
      var_val = value.is_a?(Variant) ? value : Variant.new(value)
      if @pointer.null?
        sec = (local_store[section] ||= ::Hash(String, Variant).new)
        sec[key] = var_val
      else
        call("set_value", section, key, value)
      end
      value
    end

    # Sets a value using indexer syntax: `cfg["audio", "master_volume"] = 1.0`, returning value for chaining
    def []=(section : String, key : String, value)
      set_value(section, key, value)
    end

    # Gets a Float64 value for a section and key with an optional default
    def get_value_f64(section : String, key : String, default : Float64 = 0.0_f64) : Float64
      if @pointer.null?
        if sec = local_store[section]?
          if v = sec[key]?
            raw = v.raw
            return raw.is_a?(Number) ? raw.to_f64 : default
          end
        end
        default
      else
        call_f64("get_value", section, key, default)
      end
    end

    # Gets a String value for a section and key with an optional default
    def get_value_str(section : String, key : String, default : String = "") : String
      if @pointer.null?
        if sec = local_store[section]?
          if v = sec[key]?
            return v.raw.to_s
          end
        end
        default
      else
        call_str("get_value", section, key, default)
      end
    end

    # Gets an Int64 value for a section and key with an optional default
    def get_value_i64(section : String, key : String, default : Int64 = 0_i64) : Int64
      if @pointer.null?
        if sec = local_store[section]?
          if v = sec[key]?
            raw = v.raw
            return raw.is_a?(Number) ? raw.to_i64 : default
          end
        end
        default
      else
        call_i64("get_value", section, key, default)
      end
    end

    # Gets a Bool value for a section and key with an optional default
    def get_value_bool(section : String, key : String, default : Bool = false) : Bool
      if @pointer.null?
        if sec = local_store[section]?
          if v = sec[key]?
            raw = v.raw
            return raw.is_a?(Bool) ? raw : default
          end
        end
        default
      else
        call_bool("get_value", section, key, default)
      end
    end

    # Checks if section and key exist in config
    def has_section_key(section : String, key : String) : Bool
      if @pointer.null?
        if sec = local_store[section]?
          sec.has_key?(key)
        else
          false
        end
      else
        call_bool("has_section_key", section, key)
      end
    end

    # Generic typed getter with default value:
    # `vol = cfg.get("audio", "master_volume", as: Float32, default: 0.8_f32)`
    def get(section : String, key : String, as type : T.class, default : T) : T forall T
      {% if T == Int32 %}
        get_value_i64(section, key, default.to_i64).to_i32
      {% elsif T == Int64 %}
        get_value_i64(section, key, default)
      {% elsif T == Float32 %}
        get_value_f64(section, key, default.to_f64).to_f32
      {% elsif T == Float64 %}
        get_value_f64(section, key, default)
      {% elsif T == String %}
        get_value_str(section, key, default)
      {% elsif T == Bool %}
        get_value_bool(section, key, default)
      {% else %}
        default
      {% end %}
    end

    # Generic safe typed getter returning nil if missing:
    # `vol = cfg.get?("audio", "master_volume", as: Float32)`
    def get?(section : String, key : String, as type : T.class) : T? forall T
      return nil unless has_section_key(section, key)
      {% if T == Int32 %}
        get_value_i64(section, key, 0_i64).to_i32
      {% elsif T == Int64 %}
        get_value_i64(section, key, 0_i64)
      {% elsif T == Float32 %}
        get_value_f64(section, key, 0.0).to_f32
      {% elsif T == Float64 %}
        get_value_f64(section, key, 0.0)
      {% elsif T == String %}
        get_value_str(section, key, "")
      {% elsif T == Bool %}
        get_value_bool(section, key, false)
      {% else %}
        nil
      {% end %}
    end
  end
end
