# N-Body Simulation Benchmark (Velocity-Verlet numerical integration)
# Adapted from The Computer Language Benchmarks Game (Kostya / Alioth)

SOLAR_MASS    = 4.0 * Math::PI**2
DAYS_PER_YEAR = 365.24

class Body
  property x : Float64
  property y : Float64
  property z : Float64
  property vx : Float64
  property vy : Float64
  property vz : Float64
  property mass : Float64

  def initialize(@x, @y, @z, vx : Float64, vy : Float64, vz : Float64, mass : Float64)
    @vx = vx * DAYS_PER_YEAR
    @vy = vy * DAYS_PER_YEAR
    @vz = vz * DAYS_PER_YEAR
    @mass = mass * SOLAR_MASS
  end

  def advance(bodies : Array(Body), dt : Float64, i : Int32)
    nbodies = bodies.size
    j = i + 1
    while j < nbodies
      b2 = bodies[j]
      dx = @x - b2.x
      dy = @y - b2.y
      dz = @z - b2.z

      distance = Math.sqrt(dx * dx + dy * dy + dz * dz)
      mag = dt / (distance * distance * distance)
      b_mass_mag = @mass * mag
      b2_mass_mag = b2.mass * mag

      @vx -= dx * b2_mass_mag
      @vy -= dy * b2_mass_mag
      @vz -= dz * b2_mass_mag
      b2.vx += dx * b_mass_mag
      b2.vy += dy * b_mass_mag
      b2.vz += dz * b_mass_mag
      j += 1
    end

    @x += dt * @vx
    @y += dt * @vy
    @z += dt * @vz
  end
end

def energy(bodies : Array(Body)) : Float64
  e = 0.0
  nbodies = bodies.size

  (0...nbodies).each do |i|
    b = bodies[i]
    e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
    ((i + 1)...nbodies).each do |j|
      b2 = bodies[j]
      dx = b.x - b2.x
      dy = b.y - b2.y
      dz = b.z - b2.z
      distance = Math.sqrt(dx * dx + dy * dy + dz * dz)
      e -= (b.mass * b2.mass) / distance
    end
  end
  e
end

def offset_momentum(bodies : Array(Body))
  px = 0.0
  py = 0.0
  pz = 0.0
  bodies.each do |b|
    px += b.vx * b.mass
    py += b.vy * b.mass
    pz += b.vz * b.mass
  end
  sun = bodies[0]
  sun.vx = -px / SOLAR_MASS
  sun.vy = -py / SOLAR_MASS
  sun.vz = -pz / SOLAR_MASS
end

def init_bodies : Array(Body)
  [
    # Sun
    Body.new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
    # Jupiter
    Body.new(
      4.84143144246472090e+00,
      -1.16032004402742839e+00,
      -1.03622044471123109e-01,
      1.66007664274403694e-03,
      7.69901118481134547e-03,
      -6.90460016972063023e-05,
      9.54791938424326609e-04
    ),
    # Saturn
    Body.new(
      8.34336671824457987e+00,
      4.12479856412430479e+00,
      -4.03523417114321381e-01,
      -2.76742510726862411e-03,
      4.99852801234917238e-03,
      2.30417297573763929e-05,
      2.85885980666130812e-04
    ),
    # Uranus
    Body.new(
      1.28943695621391310e+01,
      -1.51111514016986312e+01,
      -2.23307578892655734e-01,
      2.96460137564761618e-03,
      2.37847173959480950e-03,
      -2.96589568540237556e-05,
      4.36624404335156298e-05
    ),
    # Neptune
    Body.new(
      1.53796971148509165e+01,
      -2.59193146099879641e+01,
      1.79258772950371181e-01,
      2.68067772490389322e-03,
      1.62824170038242295e-03,
      -9.51592221303114738e-05,
      5.15138902046611451e-05
    ),
  ]
end

n = (ARGV[0]? || "50000").to_i
bodies = init_bodies
offset_momentum(bodies)

printf("%.9f\n", energy(bodies))
dt = 0.01
nbodies = bodies.size

start_time = Time.instant
n.times do
  (0...nbodies).each do |i|
    bodies[i].advance(bodies, dt, i)
  end
end
elapsed_ms = (Time.instant - start_time).total_milliseconds

printf("%.9f\n", energy(bodies))
puts "ELAPSED_MS: #{elapsed_ms.round(2)}"
