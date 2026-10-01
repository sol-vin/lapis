require "./spec_helper"

# Require all 4 consumer plugins and the shared base dependency directly from source code
require "../addons/dummy_base_dep/src/dummy_base_dep"
require "../addons/dummy_base_dep/src/entities"
require "../addons/dummy_dep_combat/src/main"
require "../addons/dummy_dep_storage/src/main"
require "../addons/dummy_dep_quest/src/main"
require "../addons/dummy_dep_weather/src/main"

# In unified source mode, subclasses can also directly inherit from DummyBaseEntity
@[Tool]
node SourceDirectSubclass < DummyBaseEntity do
  @[Export]
  property subclass_rating : Int32 = 100

  def bonus_power : Float64
    calculate_power(2.0) + @subclass_rating
  end
end

describe "Multi-Plugin Dependency Addons (Source Code Mode)" do
  describe "Compilation & Require Deduplication" do
    it "compiles all 4 plugins requiring dummy_base_dep without symbol collisions" do
      DummyBaseEntity.should_not be_nil
      DummyBaseConfig.should_not be_nil
      DummyCombatEntity.should_not be_nil
      DummyStorageEntity.should_not be_nil
      DummyQuestEntity.should_not be_nil
      DummyWeatherEntity.should_not be_nil
      SourceDirectSubclass.should_not be_nil
    end
  end

  describe "Type Hierarchy & Ancestor Resolution" do
    it "verifies all 4 plugins inherit from Godot::Node2D and include DummyBaseMixin" do
      dummy_ptr = Pointer(Void).new(0x12345678_u64)
      DummyCombatEntity.new(dummy_ptr).is_a?(Godot::Node2D).should be_true
      DummyStorageEntity.new(dummy_ptr).is_a?(Godot::Node2D).should be_true
      DummyQuestEntity.new(dummy_ptr).is_a?(Godot::Node2D).should be_true
      DummyWeatherEntity.new(dummy_ptr).is_a?(Godot::Node2D).should be_true

      DummyCombatEntity.new(dummy_ptr).is_a?(DummyBaseMixin).should be_true
      DummyStorageEntity.new(dummy_ptr).is_a?(DummyBaseMixin).should be_true
      DummyQuestEntity.new(dummy_ptr).is_a?(DummyBaseMixin).should be_true
      DummyWeatherEntity.new(dummy_ptr).is_a?(DummyBaseMixin).should be_true
    end

    it "verifies DummyBaseEntity inherits from Godot::Node2D and Godot::Node" do
      dummy_ptr = Pointer(Void).new(0x12345678_u64)
      DummyBaseEntity.new(dummy_ptr).is_a?(Godot::Node2D).should be_true
      DummyBaseEntity.new(dummy_ptr).is_a?(Godot::Node).should be_true
      DummyBaseEntity.new(dummy_ptr).is_a?(Godot::Object).should be_true
    end

    it "verifies direct subclassing from DummyBaseEntity in unified source mode" do
      dummy_ptr = Pointer(Void).new(0x12345678_u64)
      sub = SourceDirectSubclass.new(dummy_ptr)
      sub.is_a?(DummyBaseEntity).should be_true
      sub.is_a?(Godot::Node2D).should be_true
      sub.subclass_rating.should eq(100)
      sub.bonus_power.should eq(120.0) # 1.0 * 2.0 * 10 = 20 + 100 = 120
    end

    it "verifies DummyBaseConfig inherits from Godot::Resource" do
      dummy_ptr = Pointer(Void).new(0x12345678_u64)
      DummyBaseConfig.new(dummy_ptr).is_a?(Godot::Resource).should be_true
      DummyBaseConfig.new(dummy_ptr).is_a?(Godot::RefCounted).should be_true
    end
  end

  describe "Pure Crystal Shared Utilities" do
    it "executes DummyBaseUtils functions consistently across plugin callers" do
      action1 = DummyBaseUtils.format_action("Combat", "strike")
      action2 = DummyBaseUtils.format_action("Storage", "stash")
      action3 = DummyBaseUtils.format_action("Quest", "complete")
      action4 = DummyBaseUtils.format_action("Weather", "thunder")

      action1.should eq("Combat::STRIKE")
      action2.should eq("Storage::STASH")
      action3.should eq("Quest::COMPLETE")
      action4.should eq("Weather::THUNDER")

      hash1 = DummyBaseUtils.compute_hash("combat_spell_fire")
      hash2 = DummyBaseUtils.compute_hash("storage_slot_99")
      hash1.should be >= 0
      hash2.should be >= 0
      hash1.should_not eq(hash2)
    end
  end

  describe "Instance Properties & Default Values in Source Mode" do
    it "instantiates wrapper objects with expected base and plugin defaults" do
      dummy_ptr = Pointer(Void).new(0x12345678_u64)

      combat = DummyCombatEntity.new(dummy_ptr)
      combat.attack_power.should eq(45.0)
      combat.combo_counter.should eq(0)
      combat.shared_tag.should eq("shared_mixin_tag")

      storage = DummyStorageEntity.new(dummy_ptr)
      storage.max_slots.should eq(32)
      storage.used_slots.should eq(0)
      storage.shared_tag.should eq("shared_mixin_tag")

      quest = DummyQuestEntity.new(dummy_ptr)
      quest.current_quest.should eq("IntroQuest")
      quest.quest_progress.should eq(0.0)
      quest.shared_tag.should eq("shared_mixin_tag")

      weather = DummyWeatherEntity.new(dummy_ptr)
      weather.weather_type.should eq("Clear")
      weather.temperature.should eq(21.0)
      weather.shared_tag.should eq("shared_mixin_tag")
    end

    it "allows mutating properties independently on each plugin instance" do
      dummy_ptr = Pointer(Void).new(0x23456789_u64)

      combat = DummyCombatEntity.new(dummy_ptr)
      combat.shared_tag = "combat_tag_override"
      combat.attack_power = 99.0
      combat.combo_counter = 7

      storage = DummyStorageEntity.new(dummy_ptr)
      storage.shared_tag = "storage_tag_override"
      storage.max_slots = 100

      combat.shared_tag.should eq("combat_tag_override")
      storage.shared_tag.should eq("storage_tag_override")
      combat.attack_power.should eq(99.0)
      storage.max_slots.should eq(100)
    end
  end

  describe "GC Allocation Stress & Memory Safety in Source Mode" do
    it "allocates and collects 1000 multi-plugin objects cleanly" do
      dummy_ptr = Pointer(Void).new(0x3456789a_u64)
      allocated = Array(Godot::Node2D).new

      1000.times do |i|
        case i % 4
        when 0
          c = DummyCombatEntity.new(dummy_ptr)
          c.attack_power = (i * 0.5).to_f64
          allocated << c
        when 1
          s = DummyStorageEntity.new(dummy_ptr)
          s.max_slots = i
          allocated << s
        when 2
          q = DummyQuestEntity.new(dummy_ptr)
          q.current_quest = "Quest_#{i}"
          allocated << q
        when 3
          w = DummyWeatherEntity.new(dummy_ptr)
          w.temperature = (i % 40).to_f64
          allocated << w
        end
      end

      allocated.size.should eq(1000)
      GC.collect
      allocated.size.should eq(1000)
      allocated.clear
      GC.collect
    end
  end
end
