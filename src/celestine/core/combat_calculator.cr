require "./stamina_pool"

module Celestine
  module Core
    # Core mathematical combat calculator for damage, fall impacts, and parry timing.
    # Deterministic, allocation-free calculations.
    module CombatCalculator
      SAFE_FALL_VELOCITY   = 18.0_f32
      LETHAL_FALL_VELOCITY = 45.0_f32
      FALL_DAMAGE_FACTOR   =  4.5_f32

      BASE_SWING_DAMAGE =  45
      HEAVY_SWING_DAMAGE = 110
      BASE_BONK_DAMAGE   =  25
      THROW_DAMAGE       =  60

      # Calculates raw fall damage from vertical impact velocity.
      # Returns 9999 for instant lethal impact, 0 for safe impacts.
      def self.calculate_fall_damage(vertical_velocity : Float32) : Int32
        speed = vertical_velocity.abs
        return 0 if speed <= SAFE_FALL_VELOCITY
        return 9999 if speed >= LETHAL_FALL_VELOCITY

        ((speed - SAFE_FALL_VELOCITY) * FALL_DAMAGE_FACTOR).to_i
      end

      # Calculates shockwave AoE damage when executing a ground bonk during a fall.
      # Converts downward velocity into radial shockwave damage.
      def self.calculate_bonk_shockwave(vertical_velocity : Float32) : Int32
        speed = vertical_velocity.abs
        50 + (speed * 3.0_f32).to_i
      end

      # Calculates hammer damage according to charge level and layer difficulty.
      def self.calculate_hammer_damage(charge : ChargeLevel, layer_multiplier : Float32 = 1.0_f32) : Int32
        base = case charge
               when ChargeLevel::Tap  then BASE_SWING_DAMAGE
               when ChargeLevel::Red  then HEAVY_SWING_DAMAGE
               when ChargeLevel::Blue then (HEAVY_SWING_DAMAGE * 1.5).to_i
               else                        BASE_SWING_DAMAGE
               end
        (base * layer_multiplier).to_i
      end

      # Validates whether a parry input occurred within the parry window (in milliseconds).
      # Standard window is 200ms (12 frames at 60 FPS).
      def self.is_parry_timed?(time_diff_ms : Float32, window_ms : Float32 = 200.0_f32) : Bool
        time_diff_ms >= 0.0_f32 && time_diff_ms <= window_ms
      end

      # Calculates enemy health scaling across Tartarus layers (Layer 9 is base 1.0, Layer 1 is highest).
      # Layer index 1..9
      def self.calculate_layer_multiplier(layer_id : Int32, growth_rate : Float32 = 0.15_f32) : Float32
        clamped_layer = layer_id.clamp(1, 9)
        # Distance from bottom layer 9
        depth_steps = 9 - clamped_layer
        (1.0_f32 + (growth_rate * depth_steps)).to_f32
      end
    end
  end
end
