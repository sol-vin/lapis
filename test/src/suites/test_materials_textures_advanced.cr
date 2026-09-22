# =============================================================================
# LibGodot Test Suite: Advanced Materials, Surface Textures & Pixel CRUD
# =============================================================================

test_material "StandardMaterial3D surface features, transparency, cull mode & triplanar" do
  mat = Godot.create(Godot::StandardMaterial3D)

  # Albedo color & roughness
  mat.set_albedo(Godot::Color.new(0.3, 0.6, 0.9, 0.8))
  mat.set_roughness(0.42_f64)
  mat.set_metallic(0.78_f64)
  TestFramework.assert_approx_eq mat.get_albedo.r, 0.3_f32
  TestFramework.assert_approx_eq mat.get_albedo.g, 0.6_f32
  TestFramework.assert_approx_eq mat.get_albedo.b, 0.9_f32
  TestFramework.assert_approx_eq mat.get_roughness.to_f32, 0.42_f32
  TestFramework.assert_approx_eq mat.get_metallic.to_f32, 0.78_f32

  # Transparency & Alpha Scissor using BaseMaterial3D enums directly
  mat.set_transparency(Godot::BaseMaterial3D::Transparency::TransparencyAlpha)
  TestFramework.assert_eq mat.get_transparency, 1_i64

  mat.set_alpha_scissor_threshold(0.55_f64)
  TestFramework.assert_approx_eq mat.get_alpha_scissor_threshold.to_f32, 0.55_f32

  # Cull mode
  mat.set_cull_mode(Godot::BaseMaterial3D::CullMode::CullDisabled)
  TestFramework.assert_eq mat.get_cull_mode, 2_i64

  # Emission
  mat.set_feature(Godot::BaseMaterial3D::Feature::FeatureEmission, true)
  mat.set_emission(Godot::Color.new(1.0, 0.8, 0.2, 1.0))
  mat.set_emission_energy_multiplier(3.5_f64)
  TestFramework.assert_true mat.get_feature(Godot::BaseMaterial3D::Feature::FeatureEmission.value)
  TestFramework.assert_approx_eq mat.get_emission.r, 1.0_f32
  TestFramework.assert_approx_eq mat.get_emission_energy_multiplier.to_f32, 3.5_f32

  # UV1 Triplanar
  mat.set_flag(Godot::BaseMaterial3D::Flags::FlagAlbedoFromVertexColor, true)
  TestFramework.assert_true mat.get_flag(Godot::BaseMaterial3D::Flags::FlagAlbedoFromVertexColor.value)
end

test_material "ORMMaterial3D occlusion, roughness, and metallic channels" do
  orm = Godot.create(Godot::ORMMaterial3D)
  orm.set_roughness(0.65_f64)
  orm.set_metallic(0.35_f64)
  TestFramework.assert_approx_eq orm.get_roughness.to_f32, 0.65_f32
  TestFramework.assert_approx_eq orm.get_metallic.to_f32, 0.35_f32

  orm.set_cull_mode(Godot::BaseMaterial3D::CullMode::CullFront)
  TestFramework.assert_eq orm.get_cull_mode, 1_i64
end

test_material "CanvasItemMaterial 2D blend and light modes" do
  cim = Godot.create(Godot::CanvasItemMaterial)
  cim.set_blend_mode(Godot::CanvasItemMaterial::BlendMode::BlendModeAdd)
  TestFramework.assert_eq cim.get_blend_mode, 1_i64

  cim.set_blend_mode(Godot::CanvasItemMaterial::BlendMode::BlendModeSub)
  TestFramework.assert_eq cim.get_blend_mode, 2_i64

  cim.set_blend_mode(Godot::CanvasItemMaterial::BlendMode::BlendModeMul)
  TestFramework.assert_eq cim.get_blend_mode, 3_i64

  cim.set_light_mode(Godot::CanvasItemMaterial::LightMode::LightModeUnshaded)
  TestFramework.assert_eq cim.get_light_mode, 1_i64
end

test_material "ParticleProcessMaterial emission shape, velocity and gravity" do
  ppm = Godot.create(Godot::ParticleProcessMaterial)

  # Sphere emission shape using strongly typed enum directly
  ppm.set_emission_shape(Godot::ParticleProcessMaterial::EmissionShape::EmissionShapeSphere)
  TestFramework.assert_eq ppm.get_emission_shape, 1_i64

  ppm.set_emission_sphere_radius(7.5_f64)
  TestFramework.assert_approx_eq ppm.get_emission_sphere_radius.to_f32, 7.5_f32

  # Gravity vector
  ppm.set_gravity(Godot::Vector3.new(0.0, -19.6, 0.0))
  TestFramework.assert_approx_eq ppm.get_gravity.y, -19.6_f32

  # Initial velocity parameter min/max
  ppm.set_param_min(Godot::ParticleProcessMaterial::Parameter::ParamInitialLinearVelocity, 15.0)
  ppm.set_param_max(Godot::ParticleProcessMaterial::Parameter::ParamInitialLinearVelocity, 30.0)
  TestFramework.assert_approx_eq ppm.get_param_min(Godot::ParticleProcessMaterial::Parameter::ParamInitialLinearVelocity).to_f32, 15.0_f32
  TestFramework.assert_approx_eq ppm.get_param_max(Godot::ParticleProcessMaterial::Parameter::ParamInitialLinearVelocity).to_f32, 30.0_f32
end

test_material "Dynamic Image pixel read/write and ImageTexture material binding" do
  # Strongly typed enum passed directly without manual .value extraction to factory constructor
  img = Godot::Image.create_empty(16, 16, false, Godot::Image::Format::FormatRgba8)
  TestFramework.assert_not_nil img
  TestFramework.assert_eq img.get_width, 16_i64
  TestFramework.assert_eq img.get_height, 16_i64
  TestFramework.assert_eq img.format, Godot::Image::Format::FormatRgba8

  # Write pixel colors
  target_col = Godot::Color.new(0.2, 0.7, 0.4, 1.0)
  img.set_pixel(4_i64, 4_i64, target_col)

  read_col = img.get_pixel(4_i64, 4_i64)
  TestFramework.assert_approx_eq read_col.r, 0.2_f32, 0.01
  TestFramework.assert_approx_eq read_col.g, 0.7_f32, 0.01
  TestFramework.assert_approx_eq read_col.b, 0.4_f32, 0.01

  # Create ImageTexture from Image using ergonomic factory constructor
  tex = Godot::ImageTexture.create_from_image(img)
  TestFramework.assert_not_nil tex
  TestFramework.assert_eq tex.get_width, 16_i64
  TestFramework.assert_eq tex.get_height, 16_i64

  # Bind to StandardMaterial3D using TextureParam::TextureAlbedo enum directly
  mat = Godot.create(Godot::StandardMaterial3D)
  mat.set_texture(Godot::BaseMaterial3D::TextureParam::TextureAlbedo, tex)

  ret_tex = mat.get_texture(Godot::BaseMaterial3D::TextureParam::TextureAlbedo)
  TestFramework.assert_not_nil ret_tex
  TestFramework.assert_false ret_tex.pointer.null?
  TestFramework.assert_eq ret_tex.get_width, 16_i64
end
