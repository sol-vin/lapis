require "json"

# JSON parse and coordinate reduction benchmark (based on kostya/benchmarks)

struct Coordinate
  property x : Float64
  property y : Float64
  property z : Float64

  def initialize(@x : Float64, @y : Float64, @z : Float64)
  end

  def ==(other : Coordinate) : Bool
    (@x - other.x).abs < 0.001 &&
    (@y - other.y).abs < 0.001 &&
    (@z - other.z).abs < 0.001
  end
end

def calc(text : String) : Coordinate
  jobj = JSON.parse(text)
  coordinates = jobj["coordinates"].as_a
  len = coordinates.size
  return Coordinate.new(0.0, 0.0, 0.0) if len == 0

  x = 0.0
  y = 0.0
  z = 0.0

  coordinates.each do |coord|
    x += coord["x"].as_f
    y += coord["y"].as_f
    z += coord["z"].as_f
  end

  Coordinate.new(x / len, y / len, z / len)
end

# Self-verification
right = Coordinate.new(2.0, 0.5, 0.25)
[
  "{\"coordinates\":[{\"x\":2.0,\"y\":0.5,\"z\":0.25}]}",
  "{\"coordinates\":[{\"y\":0.5,\"x\":2.0,\"z\":0.25}]}"
].each do |v|
  left = calc(v)
  if left != right
    STDERR.puts "Verification failed: #{left} != #{right}"
    exit(1)
  end
end

file_path = ARGV[0]? || File.join(__DIR__, "1.json")
text = File.read(file_path)

start_time = Time.instant
res = calc(text)
elapsed_ms = (Time.instant - start_time).total_milliseconds

puts "RESULT: x=#{res.x.round(4)}, y=#{res.y.round(4)}, z=#{res.z.round(4)}"
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
