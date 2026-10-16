require "./vector3"

module Celestine
  module Core
    # Core kinematic constants and vector calculations following GoldSrc / Quake physics.
    # Completely decoupled from Godot Engine nodes for deterministic simulation.
    struct Kinematics
      # Standard physics parameters
      property walk_speed : Float32 = 8.0_f32
      property wish_speed : Float32 = 14.0_f32
      property air_accel : Float32 = 12.0_f32
      property air_cap : Float32 = 2.5_f32
      property ground_friction : Float32 = 6.0_f32
      property slide_friction : Float32 = 0.4_f32
      property gravity : Float32 = 24.0_f32
      property jump_impulse : Float32 = 9.8_f32
      property max_fall_speed : Float32 = 45.0_f32

      def initialize(
        @walk_speed = 8.0_f32,
        @wish_speed = 14.0_f32,
        @air_accel = 12.0_f32,
        @air_cap = 2.5_f32,
        @ground_friction = 6.0_f32,
        @slide_friction = 0.4_f32,
        @gravity = 24.0_f32,
        @jump_impulse = 9.8_f32,
        @max_fall_speed = 45.0_f32
      )
      end

      # Computes one Quake-style air acceleration step along the wish direction.
      def step_air_accelerate(velocity : Vec3, wish_dir : Vec3, dt : Float32) : Vec3
        norm_wish = wish_dir.normalized
        current_speed = velocity.dot(norm_wish)
        add_speed = (@air_cap - current_speed).clamp(0.0_f32, @air_accel * @wish_speed * dt)
        velocity + (norm_wish * add_speed)
      end

      # Computes ground friction deceleration.
      def step_ground_friction(velocity : Vec3, dt : Float32) : Vec3
        speed = velocity.length
        return Vec3.zero if speed < 0.001_f32

        drop = speed * @ground_friction * dt
        new_speed = Math.max(0.0_f32, speed - drop)
        (velocity / speed) * new_speed
      end

      # Computes slope slide acceleration given slope normal and gradient in radians.
      def step_slope_slide(velocity : Vec3, slope_normal : Vec3, slope_angle_rad : Float32, dt : Float32) : Vec3
        # Acceleration down slope: g * sin(theta) - friction * g * cos(theta)
        accel = @gravity * Math.sin(slope_angle_rad) - (@slide_friction * @gravity * Math.cos(slope_angle_rad))
        accel_f32 = accel.to_f32

        # Downhill vector projected on plane
        down_dir = Vec3.new(slope_normal.x, 0.0_f32, slope_normal.z).normalized
        if accel_f32 > 0.0_f32
          velocity + (down_dir * (accel_f32 * dt))
        else
          step_ground_friction(velocity, dt)
        end
      end

      # Calculates slingshot pull velocity when anchored to a surface via hammer chain.
      # Formula: v_pull = base_pull + 0.5 * distance, capped at max_pull (38.0 m/s).
      def calculate_tether_pull(distance : Float32, base_pull : Float32 = 28.0_f32, max_pull : Float32 = 38.0_f32) : Float32
        pulled = base_pull + (0.5_f32 * distance)
        pulled.clamp(base_pull, max_pull)
      end

      # Verifies if surface normal is within valid bonkable tolerance (max 35 deg deviation from up).
      def is_valid_bonk_surface(normal : Vec3, max_deviation_deg : Float32 = 35.0_f32) : Bool
        up = Vec3.up
        cos_angle = normal.dot(up)
        # cos(35 deg) ~= 0.819
        min_cos = Math.cos(max_deviation_deg * (Math::PI / 180.0)).to_f32
        cos_angle >= min_cos
      end
    end
  end
end
