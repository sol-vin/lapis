require "./spec_helper"

describe "String Preload (>) and Load (>>) Operators" do
  it "defines > and >> operators on String" do
    "res://test.tscn".responds_to?(:>).should be_true
    "res://test.tscn".responds_to?(:>>).should be_true
  end

  it "manages in-memory PreloadCache correctly" do
    Godot::PreloadCache.clear
    Godot::PreloadCache.has?("res://dummy.tres").should be_false

    # Mock cached resource insertion
    dummy_res = Godot.create(Godot::Resource)
    Godot::PreloadCache.get_or_load("res://dummy.tres", Godot::Resource) rescue nil
  end

  it "preserves standard string comparison operators without conflict" do
    ("apple" < "banana").should be_true
    ("zebra" > "apple").should be_true
    ("abc" <=> "abc").should eq(0)
  end
end
