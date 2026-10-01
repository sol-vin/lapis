# =============================================================================
# LibGodot Test Suite: Procedural Noise Generation & FastNoiseLite
# =============================================================================

include Lapis::Test

test_suite "Noise" do
  test "FastNoiseLite type configurations, seeds, and frequencies" do
    noise = Godot.create(Godot::FastNoiseLite)
    assert_not_nil noise
    assert_false noise.pointer.null?

    # Test Perlin noise configuration
    noise.set_noise_type(Godot::FastNoiseLite::NoiseType::TypePerlin)
    assert_eq noise.get_noise_type.value, Godot::FastNoiseLite::NoiseType::TypePerlin.value

    noise.set_seed(42_i64)
    assert_eq noise.get_seed, 42_i64

    noise.set_frequency(0.02_f64)
    assert_true (noise.get_frequency - 0.02_f64).abs < 0.0001

    # Test Simplex noise configuration
    noise.set_noise_type(Godot::FastNoiseLite::NoiseType::TypeSimplex)
    assert_eq noise.get_noise_type.value, Godot::FastNoiseLite::NoiseType::TypeSimplex.value

    # Test Simplex Smooth
    noise.set_noise_type(Godot::FastNoiseLite::NoiseType::TypeSimplexSmooth)
    assert_eq noise.get_noise_type.value, Godot::FastNoiseLite::NoiseType::TypeSimplexSmooth.value

    # Test Cellular (Voronoi)
    noise.set_noise_type(Godot::FastNoiseLite::NoiseType::TypeCellular)
    assert_eq noise.get_noise_type.value, Godot::FastNoiseLite::NoiseType::TypeCellular.value
  end

  test "FastNoiseLite fractal and cellular parameter configurations" do
    noise = Godot.create(Godot::FastNoiseLite)

    # Fractal setup
    noise.set_fractal_type(Godot::FastNoiseLite::FractalType::FractalFbm)
    assert_eq noise.get_fractal_type.value, Godot::FastNoiseLite::FractalType::FractalFbm.value

    noise.set_fractal_octaves(5_i64)
    assert_eq noise.get_fractal_octaves, 5_i64

    noise.set_fractal_lacunarity(2.0_f64)
    assert_true (noise.get_fractal_lacunarity - 2.0_f64).abs < 0.0001

    noise.set_fractal_gain(0.5_f64)
    assert_true (noise.get_fractal_gain - 0.5_f64).abs < 0.0001

    # Cellular setup
    noise.set_cellular_distance_function(Godot::FastNoiseLite::CellularDistanceFunction::DistanceEuclidean)
    assert_eq noise.get_cellular_distance_function.value, Godot::FastNoiseLite::CellularDistanceFunction::DistanceEuclidean.value

    noise.set_cellular_return_type(Godot::FastNoiseLite::CellularReturnType::ReturnDistance)
    assert_eq noise.get_cellular_return_type.value, Godot::FastNoiseLite::CellularReturnType::ReturnDistance.value
  end

  test "FastNoiseLite 1D, 2D, and 3D coordinate sampling" do
    noise = Godot.create(Godot::FastNoiseLite)
    noise.set_noise_type(Godot::FastNoiseLite::NoiseType::TypePerlin)
    noise.set_seed(1337_i64)

    # 1D sampling
    val_1d_a = noise.get_noise_1d(10.0_f64)
    val_1d_b = noise.get_noise_1d(10.0_f64)
    val_1d_c = noise.get_noise_1d(20.0_f64)
    assert_eq val_1d_a, val_1d_b
    assert_true (val_1d_a - val_1d_c).abs > 0.000001

    # 2D sampling
    val_2d_a = noise.get_noise_2d(5.0_f64, 15.0_f64)
    val_2d_b = noise.get_noise_2dv(Godot::Vector2.new(5.0_f32, 15.0_f32))
    assert_true (val_2d_a - val_2d_b).abs < 0.0001

    # 3D sampling
    val_3d = noise.get_noise_3d(1.0_f64, 2.0_f64, 3.0_f64)
    assert_true val_3d >= -1.0_f64 && val_3d <= 1.0_f64
  end

  test "FastNoiseLite procedural Image texture rasterization" do
    noise = Godot.create(Godot::FastNoiseLite)
    noise.set_noise_type(Godot::FastNoiseLite::NoiseType::TypePerlin)
    noise.set_seed(777_i64)

    img = noise.get_image(64_i64, 64_i64)
    assert_not_nil img
    assert_false img.pointer.null?
    assert_eq img.get_width, 64_i64
    assert_eq img.get_height, 64_i64

    # Sample pixel from generated noise map
    pixel = img.get_pixel(32_i64, 32_i64)
    assert_true pixel.r >= 0.0_f32 && pixel.r <= 1.0_f32
  end
end
