# =============================================================================
# LibGodot Performance Benchmark - Test Registry Catalog
# =============================================================================

require "lapis"
require "./perf_base"

module PerfFramework
  class TestDefinition
    getter id : String
    getter title : String
    getter category : String
    getter description : String
    getter scene_path : String
    getter default_count : Int32
    getter default_duration : Float64

    def initialize(
      @id : String,
      @title : String,
      @category : String,
      @description : String,
      @scene_path : String,
      @default_count : Int32,
      @default_duration : Float64,
    )
    end

    def instantiate_test : Tuple(Godot::Node, PerfLifecycleInterface)?
      packed = Godot.load_as(Godot::PackedScene, @scene_path)
      return nil unless packed
      node = packed.instantiate
      if alive = Godot::Bridge.find_alive_instance(node.pointer)
        if lifecycle = alive.as?(PerfLifecycleInterface)
          return {node, lifecycle}
        end
      end
      if lifecycle = node.as?(PerfLifecycleInterface)
        return {node, lifecycle}
      end
      nil
    end
  end

  class TestRegistry
    @@tests = Hash(String, TestDefinition).new

    def self.register(
      id : String,
      title : String,
      category : String,
      description : String,
      scene_path : String,
      default_count : Int32 = 5000,
      default_duration : Float64 = 15.0,
    ) : TestDefinition
      test_def = TestDefinition.new(id, title, category, description, scene_path, default_count, default_duration)
      @@tests[id] = test_def
      test_def
    end

    def self.all : Array(TestDefinition)
      @@tests.values
    end

    def self.find?(id : String) : TestDefinition?
      @@tests[id]?
    end

    def self.ids : Array(String)
      @@tests.keys
    end
  end
end
