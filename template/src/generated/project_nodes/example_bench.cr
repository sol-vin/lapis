# Generated strongly typed wrapper for GDScript node `ExampleBench`
# Script Path: res://benchmarks/example_bench.gd
module Godot
  class ExampleBench < Godot::SceneTree
    def initialize(pointer : Void* = Pointer(Void).null)
      super(pointer)
    end

    def self.from(node : Godot::Object) : self
      new(node.pointer)
    end

    # Method `_init` -> Void
    def _init : Void
      call("_init")
      nil
    end
  end
end

alias ExampleBench = Godot::ExampleBench
