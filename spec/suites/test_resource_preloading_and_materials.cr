# =============================================================================
# LibGodot Test Suite: Resource Preloading, Material Downcasting & Cache
# =============================================================================

include Lapis::Test

test_suite "ResourcePreload" do
  test "Pillar 1: PreloadCache thread-safe cache CRUD operations" do
    Godot::PreloadCache.clear
    assert_false Godot::PreloadCache.has?("res://custom_res_a.tres")
    assert_eq Godot::PreloadCache.size, 0

    res_a = Godot.create(Godot::Resource)
    Godot::PreloadCache["res://custom_res_a.tres"] = res_a
    assert_true Godot::PreloadCache.has?("res://custom_res_a.tres")
    assert_eq Godot::PreloadCache.size, 1

    res_b = Godot.create(Godot::Resource)
    Godot::PreloadCache.set("res://custom_res_b.tres", res_b)
    assert_true Godot::PreloadCache.has?("res://custom_res_b.tres")
    assert_eq Godot::PreloadCache.size, 2

    # Fetch from cache via get_or_load
    cached = Godot::PreloadCache.get_or_load("res://custom_res_a.tres", Godot::Resource)
    assert_eq cached, res_a

    # Delete from cache
    deleted = Godot::PreloadCache.delete("res://custom_res_a.tres")
    assert_eq deleted, res_a
    assert_false Godot::PreloadCache.has?("res://custom_res_a.tres")
    assert_eq Godot::PreloadCache.size, 1

    Godot::PreloadCache.clear
    assert_eq Godot::PreloadCache.size, 0

    res_a.destroy
    res_b.destroy
  end

  test "Pillar 2: String > preload operator and configuration blocks" do
    Godot::PreloadCache.clear
    mat = Godot.create(Godot::StandardMaterial3D)
    mat.albedo_color = Godot::Color.new(0.4_f32, 0.6_f32, 0.8_f32, 1.0_f32)
    Godot::PreloadCache["res://materials/hero_mat.tres"] = mat

    # Preload operator >
    loaded_mat = "res://materials/hero_mat.tres" > Godot::StandardMaterial3D
    assert_not_nil loaded_mat
    assert_approx_eq loaded_mat.albedo_color.r, 0.4_f32
    assert_approx_eq loaded_mat.albedo_color.g, 0.6_f32

    # Preload operator > with block configuration
    block_executed = false
    configured = "res://materials/hero_mat.tres".>(Godot::StandardMaterial3D) do |m|
      block_executed = true
      m.roughness = 0.45_f32
    end
    assert_true block_executed
    assert_approx_eq configured.roughness, 0.45_f32

    Godot::PreloadCache.clear
    mat.destroy
  end

  test "Pillar 3: Safe nilable preload (>) and load (>>) on missing paths" do
    Godot::PreloadCache.clear

    # Missing path with nilable type > returns nil without raising
    res_missing_preload = "res://scenes/non_existent_scene_xyz.tscn" > Godot::PackedScene?
    assert_nil res_missing_preload

    # Missing resource with nilable type >> returns nil without raising
    res_missing_load = "res://data/missing_item_data.tres" >> Godot::Resource?
    assert_nil res_missing_load
  end

  test "Pillar 4: Compile-time macro load/preload type inference" do
    # Verify that macros load?, preload? expand cleanly and return nil on absent files
    res_tscn = load?("res://absent.tscn")
    assert_nil res_tscn

    res_tres = preload?("res://absent.tres")
    assert_nil res_tres

    res_tex = preload?("res://absent.png")
    assert_nil res_tex

    res_audio = preload?("res://absent.wav")
    assert_nil res_audio
  end

  test "Pillar 5: PrimitiveMesh#material typed downcasting and null safety" do
    box_mesh = Godot.create(Godot::BoxMesh)
    assert_not_nil box_mesh

    # Unassigned material returns nil for material?
    assert_nil box_mesh.material?(as: Godot::StandardMaterial3D)
    assert_nil box_mesh.material?(Godot::StandardMaterial3D)

    # Calling non-nilable material on unassigned raises TypeCastError
    assert_raises(TypeCastError) do
      box_mesh.material(as: Godot::StandardMaterial3D)
    end

    # Assign StandardMaterial3D
    mat = Godot.create(Godot::StandardMaterial3D)
    mat.albedo_color = Godot::Color.new(0.9_f32, 0.1_f32, 0.2_f32, 1.0_f32)
    box_mesh.set_material(mat)

    # Typed material retrieval
    retrieved = box_mesh.material(as: Godot::StandardMaterial3D)
    assert_not_nil retrieved
    assert_approx_eq retrieved.albedo_color.r, 0.9_f32

    retrieved_pos = box_mesh.material(Godot::StandardMaterial3D)
    assert_not_nil retrieved_pos
    assert_approx_eq retrieved_pos.albedo_color.r, 0.9_f32

    # Safe nilable query
    retrieved_safe = box_mesh.material?(as: Godot::StandardMaterial3D)
    assert_not_nil retrieved_safe

    # Incompatible material downcast returns nil or raises TypeCastError
    assert_nil box_mesh.material?(as: Godot::ShaderMaterial)
    assert_raises(TypeCastError) do
      box_mesh.material(as: Godot::ShaderMaterial)
    end

    mat.destroy
    box_mesh.destroy
  end

  test "Pillar 6: Mesh#surface_get_material typed surface retrieval" do
    sphere = Godot.create(Godot::SphereMesh)
    assert_not_nil sphere

    # Surface material on unassigned surface
    assert_nil sphere.surface_get_material?(0, as: Godot::StandardMaterial3D)

    sphere.destroy
  end

  test "Pillar 7: StandardMaterial3D ergonomic property accessors and duplicate" do
    mat = Godot.create(Godot::StandardMaterial3D)
    mat.albedo_color = Godot::Color.new(0.2_f32, 0.4_f32, 0.8_f32, 1.0_f32)
    mat.roughness = 0.25_f32
    mat.metallic = 0.85_f32
    mat.emission_enabled = true
    mat.emission = Godot::Color.new(1.0_f32, 0.8_f32, 0.0_f32, 1.0_f32)

    assert_approx_eq mat.albedo_color.r, 0.2_f32
    assert_approx_eq mat.albedo_color.g, 0.4_f32
    assert_approx_eq mat.roughness, 0.25_f32
    assert_approx_eq mat.metallic, 0.85_f32
    assert_true mat.emission_enabled?
    assert_approx_eq mat.emission.r, 1.0_f32

    # Duplication directly returning StandardMaterial3D
    cloned = mat.duplicate(deep: false)
    assert_not_nil cloned
    assert_true cloned.is_a?(Godot::StandardMaterial3D)
    assert_approx_eq cloned.albedo_color.r, 0.2_f32
    assert_approx_eq cloned.roughness, 0.25_f32

    # Duplication with explicit type specification
    cloned_typed = mat.duplicate(deep: false, as: Godot::StandardMaterial3D)
    assert_not_nil cloned_typed
    assert_true cloned_typed.is_a?(Godot::StandardMaterial3D)
    assert_approx_eq cloned_typed.metallic, 0.85_f32

    cloned.destroy
    cloned_typed.destroy
    mat.destroy
  end

  test "Pillar 8: Quantitative zero memory leak verification" do
    assert_no_leak do
      Godot::PreloadCache.clear
      mat = Godot.create(Godot::StandardMaterial3D)
      mat.albedo_color = Godot::Color.new(0.5, 0.5, 0.5, 1.0)
      mat.roughness = 0.5
      mat.metallic = 0.5
      mat.emission_enabled = true

      mesh = Godot.create(Godot::BoxMesh)
      mesh.set_material(mat)
      _ret = mesh.material?(as: Godot::StandardMaterial3D)

      Godot::PreloadCache["res://temp_mat.tres"] = mat
      _cached = "res://temp_mat.tres" > Godot::StandardMaterial3D
      Godot::PreloadCache.clear

      mesh.destroy
      mat.destroy
    end
  end
end
