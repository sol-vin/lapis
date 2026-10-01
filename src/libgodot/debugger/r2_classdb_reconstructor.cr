# =============================================================================
# LibGodot - ClassDB Binary Reconstructor for Compiled DLLs
# =============================================================================
# Reconstructs ClassDB registrations, classes, virtual methods, and signals
# directly from compiled GDExtension binaries (game.dll, plugin.dll) without PDBs.

require "cradare2"
require "json"

module Lapis
  module Debugger
    # Reconstructed method metadata from binary.
    struct ReconstructedMethod
      include JSON::Serializable

      getter name : String
      getter address : UInt64
      getter return_type : String?
      getter argument_count : Int32

      def initialize(@name : String, @address : UInt64 = 0_u64, @return_type : String? = nil, @argument_count : Int32 = 0)
      end
    end

    # Reconstructed class metadata from binary.
    class ReconstructedClass
      include JSON::Serializable

      getter name : String
      getter parent_name : String
      getter address : UInt64
      getter methods : Array(ReconstructedMethod) = [] of ReconstructedMethod
      getter properties : Array(String) = [] of String
      getter signals : Array(String) = [] of String

      def initialize(@name : String, @parent_name : String = "Object", @address : UInt64 = 0_u64)
      end
    end

    # Binary scanner and ClassDB schema reconstructor.
    class ClassDBReconstructor
      getter classes : Hash(String, ReconstructedClass) = Hash(String, ReconstructedClass).new

      # Scans a binary session to discover registered classes, methods, and StringNames.
      def reconstruct_from_session(client : Cradare2::Client) : Hash(String, ReconstructedClass)
        @classes.clear

        # 1. Mine binary strings from data sections
        strings = client.strings rescue [] of Cradare2::Model::StringItem

        # Candidate class names (starting with uppercase letter)
        potential_classes = Hash(String, UInt64).new
        # Known lifecycle and standard engine callbacks
        known_callbacks = Set{"_ready", "_process", "_physics_process", "_enter_tree", "_exit_tree", "_input", "_unhandled_input"}

        strings.each do |s|
          str = s.string.strip
          next if str.size < 2 || str.size > 64

          # Potential class name (PascalCase, e.g. "Player", "CharacterBody3D", "ToolTester2D")
          if str =~ /^[A-Z][A-Za-z0-9_]+$/ && !str.includes?(" ")
            potential_classes[str] = s.vaddr
          end
        end

        # 2. Correlate with demangled symbols
        symbols = client.symbols rescue [] of Cradare2::Model::Symbol
        symbols.each do |sym|
          demangled = Cradare2::Util::Demangler.demangle(sym.name, client.transport)

          # Match patterns like: ClassName#method_name
          if demangled =~ /([A-Za-z0-9_:]+)#([A-Za-z0-9_]+)/
            cls_name = $1.split("::").last
            meth_name = $2

            reconstructed = (@classes[cls_name] ||= ReconstructedClass.new(cls_name, address: sym.vaddr))
            reconstructed.methods << ReconstructedMethod.new(meth_name, sym.vaddr)
          end
        end

        # 3. Add classes identified from strings if not already registered
        potential_classes.each do |cname, addr|
          unless @classes.has_key?(cname)
            # Only add classes likely to be Godot nodes (exclude common language keywords)
            if cname.ends_with?("Node") || cname.ends_with?("Panel") || cname.ends_with?("2D") || cname.ends_with?("3D") || cname.ends_with?("Plugin") || cname.ends_with?("Tester")
              @classes[cname] = ReconstructedClass.new(cname, address: addr)
            end
          end
        end

        @classes
      end

      # Injects reconstructed symbols into radare2 under the "godot" flag space.
      def inject_into_radare(client : Cradare2::Client) : Nil
        return if @classes.empty?

        client.flags.space("godot") do |f|
          batch = Hash(String, Cradare2::Address).new

          @classes.each do |cname, cls|
            if cls.address > 0
              batch["godot.class.#{cname}"] = cls.address
            end
            cls.methods.each do |m|
              if m.address > 0
                batch["godot.method.#{cname}.#{m.name}"] = m.address
              end
            end
          end

          f.batch_set(batch)
        end
      end
    end
  end
end
