module Lapis
  include Godot
  # Loader connecting .cr files in Godot's FileSystem dock to CrystalScript resources.
  @[Tool]
  node ResourceFormatLoaderCrystal < ResourceFormatLoader do
    @@instance : ResourceFormatLoaderCrystal? = nil
    @@registered : Bool = false
    @@created_by_us : Bool = false

    def self.ensure_registered : Void
      return if @@registered
      if Bridge.is_loader_registered?
        @@registered = true
        @@created_by_us = false
        return
      end
      rl_ptr = Bridge.get_singleton("ResourceLoader")
      if rl_ptr.null?
        Godot.printerr("[ResourceFormatLoaderCrystal.ensure_registered] ResourceLoader singleton is NULL!")
        return
      end
      r_loader = Godot::ResourceLoader.new(rl_ptr)
      current_type = r_loader.call_str("get_resource_type", "test.cr")
      if current_type == "CrystalScript"
        Bridge.set_loader_registered(true)
        @@registered = true
        @@created_by_us = false
        return
      end
      if loader = Godot.create(Godot::ResourceFormatLoaderCrystal)
        @@instance = loader
        @@created_by_us = true
        begin
          r_loader.add_resource_format_loader(loader, true)
        rescue
          r_loader.call("add_resource_format_loader", loader, true) rescue nil
        end
        Bridge.set_loader_registered(true)
        @@registered = true
      else
        Godot.printerr("[ResourceFormatLoaderCrystal.ensure_registered] Failed to create loader instance!")
      end
    end

    def self.unregister : Void
      return unless @@registered
      was_creator = @@created_by_us
      loader = @@instance
      @@instance = nil
      @@registered = false
      @@created_by_us = false

      return unless was_creator
      Bridge.set_loader_registered(false)
      return unless loader && !loader.pointer.null?

      rl_ptr = Bridge.get_singleton("ResourceLoader")
      unless rl_ptr.null?
        r_loader = Godot::ResourceLoader.new(rl_ptr)
        begin
          r_loader.remove_resource_format_loader(loader)
        rescue
          r_loader.call("remove_resource_format_loader", loader) rescue nil
        end
      end
      if loader.alive?
        loader.destroy rescue nil
      end
      loader = nil
      @@instance = nil
    end

    def self.instance : ResourceFormatLoaderCrystal
      if inst = @@instance
        return inst
      end
      ensure_registered
      @@instance || new
    end

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self.clear_instance : Void
      @@instance = nil
    end

    def get_recognized_extensions : Array(String)
      ["cr"]
    end

    def handles_type(typename : String) : Bool
      typename == "Script" || typename == "CrystalScript" || typename == "Resource"
    end

    def get_resource_type(path : String) : String
      path.ends_with?(".cr") ? "CrystalScript" : ""
    end

    # Resolves a virtual path (res:// or user://) or relative path to a readable file on disk
    def self.resolve_file_path(target_path : String) : String
      return "" if target_path.empty?

      if target_path.starts_with?("res://") || target_path.starts_with?("user://")
        if !Godot::ProjectSettings.singleton_ptr.null?
          ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
          global_path = ps.call_str("globalize_path", target_path).gsub('\\', '/')
          return global_path if !global_path.empty? && Godot::SystemIO.file_exists?(global_path)
        end
        stripped = target_path.sub(/^(res|user):\/\//, "")
        return stripped if Godot::SystemIO.file_exists?(stripped)
      end

      return target_path if Godot::SystemIO.file_exists?(target_path)
      ""
    end

    def load(path : String, original_path : String = "") : CrystalScript?
      target_path = original_path.empty? ? path : original_path
      resolved = ResourceFormatLoaderCrystal.resolve_file_path(target_path)
      code = resolved.empty? ? "" : Godot::SystemIO.read_file(resolved)

      script = Godot.create(Godot::CrystalScript)
      if script
        script.set_script_path(target_path)
        script.set_source_code(code)
        script
      else
        nil
      end
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_recognized_extensions", "_recognize_path", "_handles_type", "_get_resource_type", "_get_resource_script_class", "_load"
        true
      else
        false
      end
    end

    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_get_recognized_extensions"
        Bridge.ret_packed_string_array(ret, ["cr"])
      when "_recognize_path"
        path = Bridge.arg_to_string(args[0])
        tname = ""
        if args && args[1]
          tname = Bridge.arg_to_string_name(args[1]) rescue ""
          tname = Bridge.arg_to_string(args[1]) rescue "" if tname.empty?
        end
        type_ok = tname.empty? || tname == "Script" || tname == "CrystalScript" || tname == "Resource"
        ret.as(UInt8*).value = (type_ok && path.downcase.ends_with?(".cr")) ? 1_u8 : 0_u8
      when "_handles_type"
        typename = Bridge.arg_to_string_name(args[0]) rescue ""
        typename = Bridge.arg_to_string(args[0]) rescue "" if typename.empty?
        handles = (typename == "Script" || typename == "CrystalScript" || typename == "Resource" || typename.empty?)
        ret.as(UInt8*).value = handles ? 1_u8 : 0_u8
      when "_get_resource_type"
        path = Bridge.arg_to_string(args[0])
        Bridge.ret_string(ret, path.downcase.ends_with?(".cr") ? "CrystalScript" : "")
      when "_get_resource_uid"
        ret.as(Int64*).value = -1_i64
      when "_get_resource_script_class"
        path = Bridge.arg_to_string(args[0])
        cls_name = ""
        if path.downcase.ends_with?(".cr")
          begin
            normalized_path = path.starts_with?("res://") ? path : "res://#{path.lstrip('/')}"
            if entry = ClassRegistry.entries.find { |e| e.script_path == path || e.script_path == normalized_path || (!e.script_path.empty? && (path.ends_with?(e.script_path.sub("res://", "")) || e.script_path.ends_with?(path.sub("res://", "")))) }
              cls_name = entry.class_name
            else
              c_name, _, _ = CrystalLanguage.inspect_file_global_class(path)
              cls_name = c_name
            end
          rescue
            cls_name = ""
          end
        end
        Bridge.ret_string(ret, cls_name)
      when "_load"
        path = Bridge.arg_to_string(args[0])
        orig_path = Bridge.arg_to_string(args[1])
        target_path = orig_path.empty? ? path : orig_path

        resolved = ResourceFormatLoaderCrystal.resolve_file_path(target_path)
        code = resolved.empty? ? "" : Godot::SystemIO.read_file(resolved)

        script = Godot.create(Godot::CrystalScript)
        if script
          script.set_script_path(target_path)
          script.set_source_code(code)
          Bridge.ret_variant_object(ret, script.pointer)
        else
          Bridge.ret_variant_nil(ret)
        end
      else
        super
      end
    end
  end

  # Saver that persists modified CrystalScript source code back to .cr files on disk
  @[Tool]
  node ResourceFormatSaverCrystal < ResourceFormatSaver do
    @@instance : ResourceFormatSaverCrystal? = nil
    @@registered : Bool = false
    @@created_by_us : Bool = false

    def self.ensure_registered : Void
      return if @@registered
      if Bridge.is_saver_registered?
        @@registered = true
        @@created_by_us = false
        return
      end
      rs_ptr = Bridge.get_singleton("ResourceSaver")
      if rs_ptr.null?
        Godot.printerr("[ResourceFormatSaverCrystal.ensure_registered] ResourceSaver singleton is NULL!")
        return
      end
      if saver = Godot.create(Godot::ResourceFormatSaverCrystal)
        @@instance = saver
        @@created_by_us = true
        r_saver = Godot::ResourceSaver.new(rs_ptr)
        begin
          r_saver.add_resource_format_saver(saver, true)
        rescue
          r_saver.call("add_resource_format_saver", saver, true) rescue nil
        end
        Bridge.set_saver_registered(true)
        @@registered = true
      else
        Godot.printerr("[ResourceFormatSaverCrystal.ensure_registered] Failed to create saver instance!")
      end
    end

    def self.unregister : Void
      return unless @@registered
      was_creator = @@created_by_us
      saver = @@instance
      @@instance = nil
      @@registered = false
      @@created_by_us = false

      return unless was_creator
      Bridge.set_saver_registered(false)
      return unless saver && !saver.pointer.null?

      rs_ptr = Bridge.get_singleton("ResourceSaver")
      unless rs_ptr.null?
        r_saver = Godot::ResourceSaver.new(rs_ptr)
        begin
          r_saver.remove_resource_format_saver(saver)
        rescue
          r_saver.call("remove_resource_format_saver", saver) rescue nil
        end
      end
      if saver.alive?
        saver.destroy rescue nil
      end
      saver = nil
      @@instance = nil
    end

    def self.instance : ResourceFormatSaverCrystal
      if inst = @@instance
        return inst
      end
      ensure_registered
      @@instance || new
    end

    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self.clear_instance : Void
      @@instance = nil
    end

    def recognize(type : String) : Bool
      type == "CrystalScript" || type == "Script"
    end

    def get_recognized_extensions : Array(String)
      ["cr"]
    end

    def self.resolve_save_path(target_path : String) : String
      return "" if target_path.empty?

      if target_path.starts_with?("res://") || target_path.starts_with?("user://")
        if !Godot::ProjectSettings.singleton_ptr.null?
          ps = Godot::ProjectSettings.new(Godot::ProjectSettings.singleton_ptr)
          global_path = ps.call_str("globalize_path", target_path).gsub('\\', '/')
          return global_path unless global_path.empty?
        end
        return target_path.sub(/^(res|user):\/\//, "")
      end

      target_path
    end

    def save(script : CrystalScript, path : String) : Int32
      fs_path = ResourceFormatSaverCrystal.resolve_save_path(path)
      code = script.source_code

      # Safety guard against catastrophic file truncation
      if code.empty? && !fs_path.empty? && Godot::SystemIO.file_exists?(fs_path)
        existing_len = Godot::SystemIO.file_size(fs_path)
        if existing_len > 0
          Godot.printerr("[ResourceFormatSaverCrystal] Refusing to overwrite #{path} with empty content (source code unresolved)")
          return 1_i32 # ERR_FILE_CANT_WRITE
        end
      end

      dir_path = File.dirname(fs_path)
      Dir.mkdir_p(dir_path) unless dir_path.empty? || dir_path == "."

      if Godot::SystemIO.write_file(fs_path, code)
        0_i32
      else
        1_i32
      end
    end

    def self._godot_has_virtual_method(method_name : String) : Bool
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_recognize", "_recognize_path", "_get_recognized_extensions", "_save"
        true
      else
        false
      end
    end

    def _godot_call_virtual_with_data(method_name : String, args : Void**, ret : Void*) : Void
      norm = method_name.starts_with?('_') ? method_name : "_#{method_name}"
      case norm
      when "_recognize"
        res_ptr = Pointer(Void).null
        if !args.null? && !args[0].null?
          res_ptr = Bridge.ref_get_object(args[0])
        end
        recognize = false
        if !res_ptr.null?
          if inst = Bridge.find_alive_instance(res_ptr)
            recognize = inst.is_a?(CrystalScript)
          end
          unless recognize
            path = Bridge.resource_get_path(res_ptr)
            recognize = path.downcase.ends_with?(".cr")
          end
          unless recognize
            recognize = Bridge.object_is_class(res_ptr, "CrystalScript") ||
                        Bridge.object_is_class(res_ptr, "ScriptExtension") ||
                        Bridge.object_is_class(res_ptr, "Script")
          end
        end
        ret.as(UInt8*).value = recognize ? 1_u8 : 0_u8
      when "_recognize_path"
        path = (!args.null? && !args[1].null?) ? Bridge.arg_to_string(args[1]) : ""
        recognize = path.downcase.ends_with?(".cr")
        if !recognize && !args.null? && !args[0].null?
          p0_str = (Bridge.arg_to_string(args[0]) rescue "")
          recognize = p0_str.downcase.ends_with?(".cr")
        end
        if !recognize && !args.null? && !args[0].null?
          res_ptr = Bridge.ref_get_object(args[0])
          if !res_ptr.null?
            if inst = Bridge.find_alive_instance(res_ptr)
              recognize = inst.is_a?(CrystalScript)
            end
            unless recognize
              r_path = Bridge.resource_get_path(res_ptr)
              recognize = r_path.downcase.ends_with?(".cr")
            end
            unless recognize
              recognize = Bridge.object_is_class(res_ptr, "CrystalScript") ||
                          Bridge.object_is_class(res_ptr, "ScriptExtension") ||
                          Bridge.object_is_class(res_ptr, "Script")
            end
          end
        end
        ret.as(UInt8*).value = recognize ? 1_u8 : 0_u8
      when "_get_recognized_extensions"
        Bridge.ret_packed_string_array(ret, ["cr"])
      when "_set_uid"
        ret.as(Int32*).value = 0_i32 # OK
      when "_save"
        res_ptr = Pointer(Void).null
        if !args.null? && !args[0].null?
          res_ptr = Bridge.ref_get_object(args[0])
        end

        inst = Bridge.find_alive_instance(res_ptr)
        if inst.nil? && !args.null? && !args[0].null?
          inst = Bridge.find_alive_instance(args[0])
          res_ptr = args[0] if inst
        end

        path = (!args.null? && !args[1].null?) ? Bridge.arg_to_string(args[1]) : ""
        if path.empty? && !res_ptr.null?
          path = Bridge.resource_get_path(res_ptr)
        end
        if path.empty? && inst.is_a?(CrystalScript)
          path = inst.as(CrystalScript).script_path
        end
        fs_path = ResourceFormatSaverCrystal.resolve_save_path(path)

        code = ""
        resolved_script = false
        if script = inst.as?(CrystalScript)
          code = script.source_code
          resolved_script = true
        end

        # Fast direct Script.get_source_code ptrcall
        if code.empty? && !res_ptr.null?
          code = Bridge.script_get_source_code(res_ptr)
          resolved_script = true unless code.empty?
        end
        if code.empty? && !res_ptr.null?
          code = Bridge.object_call_ret_string(res_ptr, "get_source_code")
          resolved_script = true unless code.empty?
        end
        if code.empty? && !args.null? && !args[0].null?
          code = Bridge.script_get_source_code(args[0])
          resolved_script = true unless code.empty?
        end
        if code.empty? && !args.null? && !args[0].null?
          code = Bridge.object_call_ret_string(args[0], "get_source_code")
          resolved_script = true unless code.empty?
        end

        # Safety guard against catastrophic file truncation:
        # If code could not be resolved, and target file already exists with content,
        # refuse to overwrite with an empty string!
        if !resolved_script && code.empty? && !fs_path.empty? && Godot::SystemIO.file_exists?(fs_path)
          existing_len = Godot::SystemIO.file_size(fs_path)
          if existing_len > 0
            Godot.printerr("[ResourceFormatSaverCrystal] Refusing to overwrite #{path} with empty content (source code unresolved)")
            ret.as(Int32*).value = 1_i32 # ERR_FILE_CANT_WRITE
            return
          end
        end

        # Enforce strict 2-space indentation standard for all saved Crystal code:
        code = code.gsub('\t', "  ")

        dir_path = File.dirname(fs_path)
        Dir.mkdir_p(dir_path) unless dir_path.empty? || dir_path == "."

        if !fs_path.empty? && Godot::SystemIO.write_file(fs_path, code)
          Godot.print("[ResourceFormatSaverCrystal] Successfully saved #{path} (#{code.bytesize} bytes) -> #{fs_path}")
          ret.as(Int64*).value = 0_i64 # OK
        else
          Godot.printerr("[ResourceFormatSaverCrystal] Failed to save #{path}")
          ret.as(Int64*).value = 1_i64 # ERR_FILE_CANT_WRITE
        end
      else
        super
      end
    end
  end
end

alias ResourceFormatLoaderCrystal = Lapis::ResourceFormatLoaderCrystal
alias ResourceFormatSaverCrystal = Lapis::ResourceFormatSaverCrystal

module Godot
  alias ResourceFormatLoaderCrystal = ::Lapis::ResourceFormatLoaderCrystal
  alias ResourceFormatSaverCrystal = ::Lapis::ResourceFormatSaverCrystal
end
