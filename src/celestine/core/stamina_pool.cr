module Celestine
  module Core
    # Charge tiers for Celestine mechanics
    enum ChargeLevel
      Tap
      Red
      Blue
    end

    # Deterministic 4-pip stamina meter tracker.
    # High-throughput, zero-allocation struct for gameplay loops.
    struct StaminaPool
      getter max_pips : Int32
      getter current_pips : Int32

      def initialize(@max_pips : Int32 = 4, @current_pips : Int32 = 4)
      end

      # Checks if sufficient stamina pips exist without consuming.
      def can_afford?(pips : Int32) : Bool
        @current_pips >= pips
      end

      # Consumes specified number of stamina pips.
      # Returns true on success, false if insufficient pips.
      def consume(pips : Int32) : Bool
        return false unless can_afford?(pips)
        @current_pips -= pips
        true
      end

      # Dedicated consumer for Red Dash (1 Pip)
      def consume_red_dash : Bool
        consume(1)
      end

      # Dedicated consumer for Blue Hyper Dash (2 Pips)
      def consume_blue_dash : Bool
        consume(2)
      end

      # Dedicated consumer for Red Uppercut (2 Pips)
      def consume_red_uppercut : Bool
        consume(2)
      end

      # Dedicated consumer for Blue Max Uppercut (4 Pips)
      def consume_blue_uppercut : Bool
        consume(4)
      end

      # Instant full refill (e.g. on ground touch or projectile parry)
      def replenish_full : Nil
        @current_pips = @max_pips
      end

      # Replenishes pips based on ground bonk charge level
      def replenish_bonk(level : ChargeLevel) : Int32
        pips_to_add = case level
                      when ChargeLevel::Tap  then 1
                      when ChargeLevel::Red  then 2
                      when ChargeLevel::Blue then 4
                      else                        0
                      end
        add_pips(pips_to_add)
      end

      # Adds pips clamped to max capacity
      def add_pips(amount : Int32) : Int32
        old = @current_pips
        @current_pips = Math.min(@max_pips, @current_pips + amount)
        @current_pips - old # returns actual pips gained
      end

      # Returns fraction of stamina remaining (0.0 to 1.0)
      def ratio : Float32
        return 0.0_f32 if @max_pips <= 0
        @current_pips.to_f32 / @max_pips.to_f32
      end
    end
  end
end
