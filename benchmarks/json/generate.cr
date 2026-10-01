require "json"

count = (ARGV[0]? || "10000").to_i
out_file = ARGV[1]? || File.join(__DIR__, "1.json")

random = Random.new(42)
coordinates = Array(NamedTuple(x: Float64, y: Float64, z: Float64, name: String)).new(count)

count.times do |i|
  coordinates << {
    x: random.rand * 100.0,
    y: random.rand * 100.0,
    z: random.rand * 100.0,
    name: "point_#{i}"
  }
end

data = {
  "coordinates" => coordinates,
  "info" => "Generated benchmark dataset"
}

File.write(out_file, data.to_json)
puts "Wrote #{count} coordinates to #{out_file} (#{File.size(out_file)} bytes)"
