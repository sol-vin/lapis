# Image Processing Benchmark in Crystal
# 512x512 Image procedural pixel computation and mutation

require "../../src/lapis"

dim = (ARGV[0]? || "512").to_i

img = Godot::Image.create(dim.to_i64, dim.to_i64, false, Godot::Image::Format::FormatRgba8)

start_time = Time.instant

dim.times do |y|
  y_norm = y.to_f32 / dim.to_f32
  dim.times do |x|
    x_norm = x.to_f32 / dim.to_f32
    r = (x_norm ** 2.2_f32)
    g = (y_norm ** 2.2_f32)
    b = (((x_norm + y_norm) * 0.5_f32) ** 2.2_f32)
    img.set_pixel(x.to_i64, y.to_i64, Godot::Color.new(r, g, b, 1.0_f32))
  end
end

elapsed = (Time.instant - start_time).total_milliseconds
puts "ImageProcessing #{dim}x#{dim} (#{dim * dim} pixels): #{elapsed.round(2)} ms"
puts "ELAPSED_MS: #{elapsed.round(2)}"
