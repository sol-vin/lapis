# =============================================================================
# LibGodot Class Extensions: Multiplayer & Synchronization
# =============================================================================

module Godot
  class SceneReplicationConfig
    # Ergonomically registers a property to be replicated by MultiplayerSynchronizer.
    # Automatically prepends Godot's internal ".:" node-property syntax if not already present.
    def watch(property_name : Symbol | String) : Void
      prop_str = property_name.to_s
      prop_str = ".:#{prop_str}" unless prop_str.starts_with?(".:") || prop_str.includes?(":")
      add_property(prop_str)
    end

    # Unregisters a property from replication.
    def unwatch(property_name : Symbol | String) : Void
      prop_str = property_name.to_s
      prop_str = ".:#{prop_str}" unless prop_str.starts_with?(".:") || prop_str.includes?(":")
      remove_property(prop_str)
    end

    # Returns true if the property is configured for replication.
    def watching?(property_name : Symbol | String) : Bool
      prop_str = property_name.to_s
      prop_str = ".:#{prop_str}" unless prop_str.starts_with?(".:") || prop_str.includes?(":")
      has_property(prop_str)
    end
  end
end
