require "spec"
require "../src/lapis"
require "../src/libgodot/spec"
require "./fixtures/test_target_nodes"

# Common test fixtures and helpers for Crystal-side Godot specs
node SpecPlayer < CharacterBody3D do
  @[Export(range: 50.0_f32..800.0_f32, step: 10.0_f32)]
  property speed : Float32 = 300.0_f32

  @[Export]
  property max_health : Int32 = 100

  signal health_changed(new_health : Int32, max_health : Int32)
  signal died
end

node SpecCameraRig < Godot::Node do
  property zoom : Float32 = 1.0_f32
end

node SpecCustomSlider < Range do
end
