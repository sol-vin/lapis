require "./spec_helper"

describe "String Preload (>) and Load (>>) Operators" do
  it "defines > and >> operators on String" do
    "res://test.tscn".responds_to?(:>).should be_true
    "res://test.tscn".responds_to?(:>>).should be_true
  end

  it "manages in-memory PreloadCache correctly with CRUD operations" do
    Godot::PreloadCache.clear
    Godot::PreloadCache.has?("res://dummy.tres").should be_false
    Godot::PreloadCache.size.should eq(0)

    # In-memory resource insertion via []= and set
    res1 = Godot.create(Godot::Resource)
    Godot::PreloadCache["res://dummy1.tres"] = res1
    Godot::PreloadCache.has?("res://dummy1.tres").should be_true
    Godot::PreloadCache.size.should eq(1)

    res2 = Godot.create(Godot::Resource)
    Godot::PreloadCache.set("res://dummy2.tres", res2)
    Godot::PreloadCache.has?("res://dummy2.tres").should be_true
    Godot::PreloadCache.size.should eq(2)

    # Retrieval from PreloadCache via get_or_load
    cached1 = Godot::PreloadCache.get_or_load("res://dummy1.tres", Godot::Resource)
    cached1.should eq(res1)

    # Deletion
    removed = Godot::PreloadCache.delete("res://dummy1.tres")
    removed.should eq(res1)
    Godot::PreloadCache.has?("res://dummy1.tres").should be_false
    Godot::PreloadCache.size.should eq(1)

    Godot::PreloadCache.clear
    Godot::PreloadCache.size.should eq(0)
  end

  it "preloads cached resources and yields to configuration block via > operator" do
    Godot::PreloadCache.clear
    res = Godot.create(Godot::Resource)
    Godot::PreloadCache["res://cached_theme.tres"] = res

    # Retrieve cached resource via >
    loaded = "res://cached_theme.tres" > Godot::Resource
    loaded.should eq(res)

    # Configuration block via >
    block_ran = false
    configured = "res://cached_theme.tres".>(Godot::Resource) do |r|
      block_ran = true
      r.should eq(res)
    end
    block_ran.should be_true
    configured.should eq(res)

    Godot::PreloadCache.clear
  end

  it "safely returns nil for missing resources using nilable types with > and >>" do
    Godot::PreloadCache.clear

    # Missing resource with nilable type > returns nil without raising
    missing_preload = "res://missing_item_1234.tres" > Godot::Resource?
    missing_preload.should be_nil

    # Missing resource with nilable type >> returns nil without raising
    missing_load = "res://missing_item_5678.tres" >> Godot::Resource?
    missing_load.should be_nil
  end

  it "preserves standard string comparison operators without conflict" do
    ("apple" < "banana").should be_true
    ("zebra" > "apple").should be_true
    ("abc" <=> "abc").should eq(0)
  end

  it "supports StandardMaterial3D ergonomic properties and duplication" do
    mat = Godot::StandardMaterial3D.new
    mat.albedo_color = Godot::Color.new(0.8_f32, 0.2_f32, 0.1_f32, 1.0_f32)
    mat.roughness = 0.35_f32
    mat.metallic = 0.75_f32
    mat.emission_enabled = true
    mat.emission = Godot::Color.new(0.1_f32, 0.9_f32, 0.2_f32, 1.0_f32)

    mat.albedo_color.r.should be_close(0.8_f32, 1e-4)
    mat.albedo_color.g.should be_close(0.2_f32, 1e-4)
    mat.roughness.should be_close(0.35_f32, 1e-4)
    mat.metallic.should be_close(0.75_f32, 1e-4)
    mat.emission_enabled?.should be_true
    mat.emission.g.should be_close(0.9_f32, 1e-4)

    # Duplication
    cloned = mat.duplicate
    cloned.should be_a(Godot::StandardMaterial3D)
    cloned.albedo_color.r.should be_close(0.8_f32, 1e-4)
    cloned.roughness.should be_close(0.35_f32, 1e-4)
    cloned.metallic.should be_close(0.75_f32, 1e-4)
    cloned.emission_enabled?.should be_true
    cloned.emission.g.should be_close(0.9_f32, 1e-4)

    # Duplication through Resource base class with typed downcasting
    res = mat.as(Godot::Resource)
    cloned_res = res.duplicate(as: Godot::StandardMaterial3D)
    cloned_res.should be_a(Godot::StandardMaterial3D)
    cloned_res.albedo_color.r.should be_close(0.8_f32, 1e-4)
  end
end
