# spec/celestine_spec.cr
# Comprehensive specifications for Project Celestine Two-Tier Engine and Canonical GDD

require "spec"
require "../src/celestine"

describe "Project Celestine Two-Tier Engine" do
  describe "Core Vec3 Primitives" do
    it "performs accurate vector arithmetic and normalization" do
      v1 = Celestine::Core::Vec3.new(3.0_f32, 4.0_f32, 0.0_f32)
      v1.length.should eq(5.0_f32)

      norm = v1.normalized
      norm.x.should be_close(0.6_f32, 1e-4)
      norm.y.should be_close(0.8_f32, 1e-4)
      norm.length.should be_close(1.0_f32, 1e-4)

      v2 = Celestine::Core::Vec3.new(1.0_f32, 0.0_f32, 0.0_f32)
      v1.dot(v2).should eq(3.0_f32)
    end
  end

  describe "Core Kinematics Engine" do
    kinematics = Celestine::Core::Kinematics.new

    it "applies Quake/GoldSrc air acceleration correctly" do
      v_start = Celestine::Core::Vec3.zero
      wish_dir = Celestine::Core::Vec3.new(1.0_f32, 0.0_f32, 0.0_f32)
      dt = 1.0_f32 / 60.0_f32

      v_next = kinematics.step_air_accelerate(v_start, wish_dir, dt)
      v_next.x.should be > 0.0_f32
      v_next.x.should be <= kinematics.air_cap
    end

    it "decelerates on ground through friction" do
      v_ground = Celestine::Core::Vec3.new(10.0_f32, 0.0_f32, 0.0_f32)
      dt = 0.1_f32
      v_slower = kinematics.step_ground_friction(v_ground, dt)
      v_slower.x.should be < 10.0_f32
    end

    it "calculates distance-proportional slingshot tether pull" do
      pull_short = kinematics.calculate_tether_pull(10.0_f32)
      pull_long = kinematics.calculate_tether_pull(30.0_f32)
      pull_short.should eq(33.0_f32)
      pull_long.should eq(38.0_f32) # Clamped at max_pull
    end

    it "validates bonkable surface normal orientation" do
      upright_normal = Celestine::Core::Vec3.new(0.0_f32, 1.0_f32, 0.0_f32)
      kinematics.is_valid_bonk_surface(upright_normal).should be_true

      steep_wall_normal = Celestine::Core::Vec3.new(1.0_f32, 0.0_f32, 0.0_f32)
      kinematics.is_valid_bonk_surface(steep_wall_normal).should be_false
    end
  end

  describe "Core Stamina Resource Pool" do
    it "manages 4-pip consumption and replenishment" do
      pool = Celestine::Core::StaminaPool.new
      pool.current_pips.should eq(4)

      # Consume Red Dash (1 Pip)
      pool.consume_red_dash.should be_true
      pool.current_pips.should eq(3)

      # Consume Blue Dash (2 Pips)
      pool.consume_blue_dash.should be_true
      pool.current_pips.should eq(1)

      # Attempting 2-pip action with only 1 pip remaining fails
      pool.consume_blue_dash.should be_false
      pool.current_pips.should eq(1)

      # Full replenishment (e.g. ground touch)
      pool.replenish_full
      pool.current_pips.should eq(4)

      # Blue max uppercut consumes all 4 pips
      pool.consume_blue_uppercut.should be_true
      pool.current_pips.should eq(0)
    end

    it "replenishes pips correctly on ground bonk tiers" do
      pool = Celestine::Core::StaminaPool.new(4, 0)
      pool.replenish_bonk(Celestine::Core::ChargeLevel::Tap).should eq(1)
      pool.current_pips.should eq(1)

      pool.replenish_bonk(Celestine::Core::ChargeLevel::Red).should eq(2)
      pool.current_pips.should eq(3)

      pool.replenish_bonk(Celestine::Core::ChargeLevel::Blue)
      pool.current_pips.should eq(4)
    end
  end

  describe "Combat & Fall Damage Calculator" do
    it "mitigates fall damage below safe threshold" do
      Celestine::Core::CombatCalculator.calculate_fall_damage(12.0_f32).should eq(0)
      Celestine::Core::CombatCalculator.calculate_fall_damage(18.0_f32).should eq(0)
    end

    it "scales fall damage linearly between safe and lethal velocity" do
      dmg = Celestine::Core::CombatCalculator.calculate_fall_damage(28.0_f32)
      dmg.should eq(45) # (28 - 18) * 4.5 = 45
    end

    it "triggers instant fatality above lethal threshold" do
      Celestine::Core::CombatCalculator.calculate_fall_damage(46.0_f32).should eq(9999)
    end

    it "calculates bonk shockwave damage from fall velocity" do
      shockwave = Celestine::Core::CombatCalculator.calculate_bonk_shockwave(20.0_f32)
      shockwave.should eq(110) # 50 + 20 * 3 = 110
    end

    it "validates parry timing windows" do
      Celestine::Core::CombatCalculator.is_parry_timed?(150.0_f32, 200.0_f32).should be_true
      Celestine::Core::CombatCalculator.is_parry_timed?(250.0_f32, 200.0_f32).should be_false
    end

    it "scales layer difficulty multipliers from Layer 9 to Layer 1" do
      mult_l9 = Celestine::Core::CombatCalculator.calculate_layer_multiplier(9)
      mult_l1 = Celestine::Core::CombatCalculator.calculate_layer_multiplier(1)
      mult_l9.should eq(1.0_f32)
      mult_l1.should be > 2.0_f32
    end
  end

  describe "Tartarus Layer Profiles" do
    it "resolves canonical profiles for Layer 9 (Treachery) and Layer 7 (Violence)" do
      treachery = Celestine::Core::TartarusLayerProfile.find(9)
      treachery.name.should eq("Treachery")
      treachery.classical_name.should eq("Cocytus")
      treachery.palette_name.should eq("Warm Paper")

      violence = Celestine::Core::TartarusLayerProfile.find(7)
      violence.name.should eq("Violence")
      violence.classical_name.should eq("Phlegethon")
      violence.damage_multiplier.should be > 1.2_f32
    end
  end

  describe "Declarative DSL Builders" do
    it "builds character configuration with context block" do
      char = Celestine.character do |c|
        c.name = "Menoitios the Defiant"
        c.walk_speed = 9.0_f32
        c.wish_speed = 16.0_f32
        c.base_swing_damage = 50
      end

      char.name.should eq("Menoitios the Defiant")
      kinematics = char.build_kinematics
      kinematics.walk_speed.should eq(9.0_f32)
      kinematics.wish_speed.should eq(16.0_f32)
    end

    it "builds layer override profile with context block" do
      layer = Celestine.layer(9) do |l|
        l.custom_name = "Cocytus Industrial Core"
        l.gravity_override = 1.2_f32
      end

      layer.name.should eq("Cocytus Industrial Core")
      layer.gravity_multiplier.should eq(1.2_f32)
      layer.classical_name.should eq("Cocytus")
    end

    it "builds hammer action specification" do
      action = Celestine.hammer_action("Seismic Ground Slam") do |h|
        h.stamina_cost = 1
        h.damage = 80
        h.launch_velocity = 6.0_f32
        h.charge_level = Celestine::Core::ChargeLevel::Red
      end

      action.name.should eq("Seismic Ground Slam")
      action.damage.should eq(80)
      action.stamina_cost.should eq(1)
    end
  end

  describe "Canonical GDD Integrity Verification" do
    it "verifies existence and structure of PROJECT_CELESTINE_GDD.md" do
      gdd_path = File.expand_path("../gdd/PROJECT_CELESTINE_GDD.md", __DIR__)
      File.exists?(gdd_path).should be_true

      content = File.read(gdd_path)
      content.should contain("Project Celestine: Canonical Game Design Document")
      content.should contain("Menoitios")
      content.should contain("Pit of Tartarus")
      content.should contain("Pillar 1: Kinetic Momentum Freedom")
      content.should contain("The Celestine War Hammer")
      content.should contain("The Nine Layers of Tartarus")
      content.should contain("Treachery (Cocytus)")
      content.should contain("4-Pip Stamina Meter")
      content.should contain("TrenchBroom / FuncGodot Entity Specs")
      content.should contain("Two-Tier Engine & Lapis DSL Implementation Architecture")
      content.should contain("Sony PlayStation 2 Profile (Citrine)")
    end
  end
end
