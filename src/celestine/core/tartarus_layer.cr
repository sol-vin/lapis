module Celestine
  module Core
    # The 9 mythological layers of Tartarus, in upward ascending order (9 -> 1)
    enum LayerId
      Limbo     = 1
      Lust      = 2
      Gluttony  = 3
      Greed     = 4
      Wrath     = 5
      Heresy    = 6
      Violence  = 7
      Fraud     = 8
      Treachery = 9
    end

    # Metadata and gameplay rules for a Tartarus layer
    struct TartarusLayerProfile
      getter id : LayerId
      getter name : String
      getter classical_name : String
      getter hazard_description : String
      getter gravity_multiplier : Float32
      getter damage_multiplier : Float32
      getter palette_name : String

      def initialize(
        @id : LayerId,
        @name : String,
        @classical_name : String,
        @hazard_description : String,
        @gravity_multiplier : Float32 = 1.0_f32,
        @damage_multiplier : Float32 = 1.0_f32,
        @palette_name : String = "GameStation 2"
      )
      end

      # Returns the canonical profile for a specific layer number (1..9)
      def self.find(number : Int32) : TartarusLayerProfile
        case number
        when 9
          TartarusLayerProfile.new(
            LayerId::Treachery,
            "Treachery",
            "Cocytus",
            "Caustic ash wells and boiling lye drainage canals",
            gravity_multiplier: 1.0_f32,
            damage_multiplier: 1.0_f32,
            palette_name: "Warm Paper"
          )
        when 8
          TartarusLayerProfile.new(
            LayerId::Fraud,
            "Fraud",
            "Malebolge",
            "Ephemeral crumbling platforms and illusory apple orchards",
            gravity_multiplier: 1.0_f32,
            damage_multiplier: 1.15_f32,
            palette_name: "Inversion"
          )
        when 7
          TartarusLayerProfile.new(
            LayerId::Violence,
            "Violence",
            "Phlegethon",
            "Molten brass channels and flesh-crushing hydraulic pistons",
            gravity_multiplier: 1.05_f32,
            damage_multiplier: 1.30_f32,
            palette_name: "GameStation 2"
          )
        when 6
          TartarusLayerProfile.new(
            LayerId::Heresy,
            "Heresy",
            "The Necropolis of Stelae",
            "Burning sarcophagus tombs and suffocating phosphorus smog",
            gravity_multiplier: 1.0_f32,
            damage_multiplier: 1.45_f32,
            palette_name: "Classic Green"
          )
        when 5
          TartarusLayerProfile.new(
            LayerId::Wrath,
            "Wrath",
            "The Stygian Marsh",
            "Viscous mud reducing ground acceleration and split-soul shades",
            gravity_multiplier: 1.1_f32,
            damage_multiplier: 1.60_f32,
            palette_name: "FOS"
          )
        when 4
          TartarusLayerProfile.new(
            LayerId::Greed,
            "Greed",
            "The Gilded Hoards",
            "Rolling molten bullion boulders and portcullis crushing traps",
            gravity_multiplier: 1.0_f32,
            damage_multiplier: 1.75_f32,
            palette_name: "GameStation 2"
          )
        when 3
          TartarusLayerProfile.new(
            LayerId::Gluttony,
            "Gluttony",
            "The Putrid Mire",
            "Acidic downpours eroding energy shields outside shelter",
            gravity_multiplier: 1.0_f32,
            damage_multiplier: 1.90_f32,
            palette_name: "Aperture"
          )
        when 2
          TartarusLayerProfile.new(
            LayerId::Lust,
            "Lust",
            "The Tempest of Howls",
            "Gale-force vertical wind shear and abyssal chasms",
            gravity_multiplier: 0.85_f32,
            damage_multiplier: 2.05_f32,
            palette_name: "GameStation 2"
          )
        when 1
          TartarusLayerProfile.new(
            LayerId::Limbo,
            "Limbo",
            "The Silent Threshold",
            "Ancient crumbling marble colonnades bathed in sunlight",
            gravity_multiplier: 1.0_f32,
            damage_multiplier: 2.20_f32,
            palette_name: "Warm Paper"
          )
        else
          find(9)
        end
      end
    end
  end
end
