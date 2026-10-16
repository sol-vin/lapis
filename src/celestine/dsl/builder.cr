require "../core/vector3"
require "../core/kinematics"
require "../core/stamina_pool"
require "../core/combat_calculator"
require "../core/tartarus_layer"
require "../core/entity_properties"

module Celestine
  module DSL
    # Declarative character builder yielding context receiver
    class CharacterContext
      property name : String = "Menoitios"
      property max_stamina_pips : Int32 = 4
      property walk_speed : Float32 = 8.0_f32
      property wish_speed : Float32 = 14.0_f32
      property air_accel : Float32 = 12.0_f32
      property base_swing_damage : Int32 = 45
      property red_dash_pips : Int32 = 1
      property blue_dash_pips : Int32 = 2
      property downward_throw_pips : Int32 = 0

      def build_kinematics : Core::Kinematics
        Core::Kinematics.new(
          walk_speed: @walk_speed,
          wish_speed: @wish_speed,
          air_accel: @air_accel
        )
      end

      def build_stamina_pool : Core::StaminaPool
        Core::StaminaPool.new(@max_stamina_pips, @max_stamina_pips)
      end
    end

    # Declarative layer environment builder
    class LayerContext
      property layer_id : Int32
      property custom_name : String?
      property gravity_override : Float32?
      property damage_override : Float32?
      property custom_hazard : String?

      def initialize(@layer_id : Int32)
      end

      def build_profile : Core::TartarusLayerProfile
        base = Core::TartarusLayerProfile.find(@layer_id)
        Core::TartarusLayerProfile.new(
          base.id,
          @custom_name || base.name,
          base.classical_name,
          @custom_hazard || base.hazard_description,
          gravity_multiplier: @gravity_override || base.gravity_multiplier,
          damage_multiplier: @damage_override || base.damage_multiplier,
          palette_name: base.palette_name
        )
      end
    end

    # Declarative hammer action builder
    class HammerActionContext
      property name : String
      property stamina_cost : Int32 = 0
      property damage : Int32 = 45
      property launch_velocity : Float32 = 0.0_f32
      property charge_level : Core::ChargeLevel = Core::ChargeLevel::Tap
      property parry_window_ms : Float32 = 200.0_f32

      def initialize(@name : String)
      end
    end

    # Declarative encounter builder
    class EncounterContext
      property name : String
      property enemy_spawns : Array(Tuple(String, Core::Vec3)) = [] of Tuple(String, Core::Vec3)
      property trigger_on_entry : Bool = true
      property barrier_lock_id : String? = nil

      def initialize(@name : String)
      end

      def spawn(enemy_type : String, x : Number, y : Number, z : Number)
        @enemy_spawns << {enemy_type, Core::Vec3.new(x.to_f32, y.to_f32, z.to_f32)}
      end
    end
  end

  # Declarative API entrypoints
  def self.character(&block : DSL::CharacterContext ->) : DSL::CharacterContext
    ctx = DSL::CharacterContext.new
    yield ctx
    ctx
  end

  def self.layer(number : Int32, &block : DSL::LayerContext ->) : Core::TartarusLayerProfile
    ctx = DSL::LayerContext.new(number)
    yield ctx
    ctx.build_profile
  end

  def self.hammer_action(name : String, &block : DSL::HammerActionContext ->) : DSL::HammerActionContext
    ctx = DSL::HammerActionContext.new(name)
    yield ctx
    ctx
  end

  def self.encounter(name : String, &block : DSL::EncounterContext ->) : DSL::EncounterContext
    ctx = DSL::EncounterContext.new(name)
    yield ctx
    ctx
  end
end
