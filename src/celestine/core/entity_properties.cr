module Celestine
  module Core
    # Core TrenchBroom / FuncGodot entity properties
    struct WorldspawnProps
      property collision : Bool
      property mesh : Bool
      property occluder : Bool
      property layer_id : Int32

      def initialize(@collision = true, @mesh = true, @occluder = true, @layer_id = 9)
      end
    end

    enum DestroyableType
      Indestructible = 0
      InstantBreak   = 1
      HealthBased    = 2
    end

    struct DestroyableProps
      property type : DestroyableType
      property hp : Int32
      property required_charge : ChargeLevel
      property debris_count : Int32

      def initialize(
        @type = DestroyableType::InstantBreak,
        @hp = 100,
        @required_charge = ChargeLevel::Tap,
        @debris_count = 8
      )
      end

      # Returns true if an incoming attack damages or destroys this entity
      def can_damage?(incoming_damage : Int32, charge : ChargeLevel) : Bool
        return false if @type == DestroyableType::Indestructible

        # Charge check
        charge_ok = case @required_charge
                    when ChargeLevel::Tap  then true
                    when ChargeLevel::Red  then charge == ChargeLevel::Red || charge == ChargeLevel::Blue
                    when ChargeLevel::Blue then charge == ChargeLevel::Blue
                    else                        true
                    end
        return false unless charge_ok

        case @type
        when DestroyableType::InstantBreak
          incoming_damage >= 25
        when DestroyableType::HealthBased
          incoming_damage > 0
        else
          false
        end
      end
    end

    enum MoverStartType
      Auto
      Triggered
      Toggle
      EachNode
    end

    enum MoverStopType
      Halt
      Reverse
      Reset
      Loop
    end

    struct MoverProps
      property start_type : MoverStartType
      property stop_type : MoverStopType
      property move_speed : Float32
      property crush_damage : Int32

      def initialize(
        @start_type = MoverStartType::Auto,
        @stop_type = MoverStopType::Loop,
        @move_speed = 5.0_f32,
        @crush_damage = 999
      )
      end
    end
  end
end
