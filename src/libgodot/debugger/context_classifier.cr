# =============================================================================
# LibGodot - Smart Context-Aware Debugging Execution Classifier
# =============================================================================
# Classifies instruction pointers, memory addresses, and stack frames into their
# architectural domain: Game Code, Addon Code, Editor Plugin, GDExtension Bridge,
# Godot Engine Core, Boehm GC / Crystal Runtime, or System CRT.

require "cradare2"

module Godot
  module Debugger
    enum ContextDomain
      Game
      Addon
      Plugin
      Bridge
      Engine
      Runtime
      System
      Unknown

      def display_name : String
        case self
        in Game    then "Game"
        in Addon   then "Addon"
        in Plugin  then "Editor Plugin"
        in Bridge  then "GDExtension Bridge"
        in Engine  then "Godot Core"
        in Runtime then "Crystal Runtime"
        in System  then "System CRT"
        in Unknown then "Unknown"
        end
      end
    end

    struct ExecutionContext
      getter domain : ContextDomain
      getter addon_name : String?
      getter module_name : String
      getter file : String?
      getter line : Int32?
      getter symbol : String?

      def initialize(
        @domain : ContextDomain,
        @module_name : String = "",
        @addon_name : String? = nil,
        @file : String? = nil,
        @line : Int32? = nil,
        @symbol : String? = nil
      )
      end

      def badge : String
        case @domain
        when ContextDomain::Addon
          name = @addon_name || "Unknown"
          "[Context: Addon '#{name}']"
        else
          "[Context: #{@domain.display_name}]"
        end
      end

      def to_s(io : IO) : Nil
        io << badge
        if mod = @module_name.presence
          io << " in " << mod
        end
        if f = @file.presence
          io << " (" << f
          io << ":" << @line if @line
          io << ")"
        end
        if sym = @symbol.presence
          io << " -> " << sym
        end
      end
    end

    class ContextClassifier
      # Registered addon modules: maps clean binary name (e.g. "custom_fx.dll") to addon name ("custom_fx")
      getter addon_modules : Hash(String, String) = Hash(String, String).new

      def initialize
        # Default known addons
        register_addon("crystal_integration", "crystal_integration.dll")
        register_addon("custom_fx", "custom_fx.dll")
        register_addon("dummy_audio", "dummy_audio.dll")
        register_addon("dummy_dialogue", "dummy_dialogue.dll")
        register_addon("dummy_inventory", "dummy_inventory.dll")
      end

      def register_addon(addon_name : String, binary_name : String) : Nil
        clean = File.basename(binary_name).downcase
        @addon_modules[clean] = addon_name
      end

      # Classifies an execution frame by file path, symbol, module name, and address
      def classify(
        file_path : String?,
        symbol_name : String? = nil,
        mod_name : String? = nil,
        address : UInt64 = 0_u64
      ) : ExecutionContext
        classify_target(mod_name || "", file_path, symbol_name, address)
      end

      # Classifies an execution frame by module name (first arg)
      def classify_target(
        mod_name : String,
        file_path : String? = nil,
        symbol_name : String? = nil,
        address : UInt64 = 0_u64
      ) : ExecutionContext
        clean_mod = File.basename(mod_name).downcase
        clean_file = file_path ? file_path.gsub('\\', '/').downcase : ""
        clean_sym = symbol_name || ""

        # 1. Check for Addon code (either by file path "addons/<name>/" or registered addon binary)
        if clean_file.includes?("addons/")
          parts = clean_file.split("addons/").last?.try(&.split('/'))
          addon = parts && parts.size > 0 ? parts.first : nil
          if addon && addon != "crystal_integration"
            return ExecutionContext.new(
              domain: ContextDomain::Addon,
              module_name: mod_name,
              addon_name: addon,
              file: file_path,
              line: nil,
              symbol: symbol_name
            )
          end
        end

        if @addon_modules.has_key?(clean_mod)
          addon = @addon_modules[clean_mod]
          if addon != "crystal_integration"
            return ExecutionContext.new(
              domain: ContextDomain::Addon,
              module_name: mod_name,
              addon_name: addon,
              file: file_path,
              line: nil,
              symbol: symbol_name
            )
          end
        end

        # 2. Check for Editor Plugin code
        if clean_mod.includes?("plugin") || clean_file.includes?("addons/crystal_integration") || clean_sym.includes?("CrystalIntegrationPlugin") || clean_sym.includes?("CrystalDebuggerPlugin")
          return ExecutionContext.new(
            domain: ContextDomain::Plugin,
            module_name: mod_name,
            file: file_path,
            line: nil,
            symbol: symbol_name
          )
        end

        # 3. Check for GDExtension loader bridge
        if clean_mod.includes?("crystal_bridge") || clean_file.includes?("bridge/crystal_bridge") || clean_sym.includes?("crystal_godot_init")
          return ExecutionContext.new(
            domain: ContextDomain::Bridge,
            module_name: mod_name,
            file: file_path,
            line: nil,
            symbol: symbol_name
          )
        end

        # 4. Check for User Game code
        if clean_mod.includes?("game") || clean_file.starts_with?("src/") || clean_file.includes?("/src/") || clean_sym.includes?("Player")
          return ExecutionContext.new(
            domain: ContextDomain::Game,
            module_name: mod_name,
            file: file_path,
            line: nil,
            symbol: symbol_name
          )
        end

        # 5. Check for Godot Engine Core
        if clean_mod.includes?("godot") || clean_mod.includes?("libgodot") || clean_sym.includes?("godot_") || clean_sym.includes?("ObjectDB") || clean_sym.includes?("ClassDB")
          return ExecutionContext.new(
            domain: ContextDomain::Engine,
            module_name: mod_name,
            file: file_path,
            line: nil,
            symbol: symbol_name
          )
        end

        # 6. Check for Boehm GC / Crystal runtime CRT
        if clean_mod.includes?("gc.") || clean_mod.includes?("pcre2") || clean_mod.includes?("iconv") || clean_sym.includes?("GC_") || clean_sym.includes?("crystal_")
          return ExecutionContext.new(
            domain: ContextDomain::Runtime,
            module_name: mod_name,
            file: file_path,
            line: nil,
            symbol: symbol_name
          )
        end

        # 7. Check for Windows / POSIX OS CRT
        if clean_mod.includes?("ntdll") || clean_mod.includes?("kernel32") || clean_mod.includes?("ucrtbase") || clean_mod.includes?("libc.")
          return ExecutionContext.new(
            domain: ContextDomain::System,
            module_name: mod_name,
            file: file_path,
            line: nil,
            symbol: symbol_name
          )
        end

        ExecutionContext.new(
          domain: ContextDomain::Unknown,
          module_name: mod_name,
          file: file_path,
          line: nil,
          symbol: symbol_name
        )
      end
    end
  end
end
