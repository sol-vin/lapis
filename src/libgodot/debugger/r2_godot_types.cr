# =============================================================================
# LibGodot - Radare2 Godot Type Maps & Variant Binary Decoders
# =============================================================================
# Re-exports and delegates to `Cradare2::Engine::Godot` for binary layouts,
# Variant decoders, Object headers, and radare2 print format registrations (`pf.godot_*`).

require "cradare2"
require "cradare2/engine/godot"
require "json"

module Lapis
  module Debugger
    # Godot 4.x Variant types matching GDExtensionVariantType enum.
    alias VariantType = Cradare2::Engine::Godot::VariantType

    # Represents the binary header of a Godot Object in memory.
    alias GodotObjectHeader = Cradare2::Engine::Godot::GodotObjectHeader

    # Decoded Godot Variant value representation.
    alias DecodedVariant = Cradare2::Engine::Godot::DecodedVariant

    # Binary decoder for Godot Variant instances in process memory.
    alias VariantDecoder = Cradare2::Engine::Godot::VariantDecoder

    # Registers radare2 print format types (`pf`) for Godot data structures.
    class TypeMapRegistrar
      # Registers all standard Godot print formats into the radare2 session.
      def self.register_all(client : Cradare2::Client) : Nil
        Cradare2::Engine::Godot.register_formats(client)
      end
    end
  end
end
