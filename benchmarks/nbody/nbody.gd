extends SceneTree

# N-Body Simulation Benchmark (Velocity-Verlet numerical integration in GDScript)

const SOLAR_MASS = 4.0 * PI * PI
const DAYS_PER_YEAR = 365.24

class Body:
	var x: float
	var y: float
	var z: float
	var vx: float
	var vy: float
	var vz: float
	var mass: float

	func _init(px: float, py: float, pz: float, pvx: float, pvy: float, pvz: float, pmass: float):
		x = px
		y = py
		z = pz
		vx = pvx * DAYS_PER_YEAR
		vy = pvy * DAYS_PER_YEAR
		vz = pvz * DAYS_PER_YEAR
		mass = pmass * SOLAR_MASS

	func advance(bodies: Array, dt: float, i: int):
		var nbodies = bodies.size()
		var j = i + 1
		while j < nbodies:
			var b2 = bodies[j]
			var dx = x - b2.x
			var dy = y - b2.y
			var dz = z - b2.z

			var distance = sqrt(dx * dx + dy * dy + dz * dz)
			var mag = dt / (distance * distance * distance)
			var b_mass_mag = mass * mag
			var b2_mass_mag = b2.mass * mag

			vx -= dx * b2_mass_mag
			vy -= dy * b2_mass_mag
			vz -= dz * b2_mass_mag
			b2.vx += dx * b_mass_mag
			b2.vy += dy * b_mass_mag
			b2.vz += dz * b_mass_mag
			j += 1

		x += dt * vx
		y += dt * vy
		z += dt * vz

static func compute_energy(bodies: Array) -> float:
	var e = 0.0
	var nbodies = bodies.size()
	for i in range(nbodies):
		var b = bodies[i]
		e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
		for j in range(i + 1, nbodies):
			var b2 = bodies[j]
			var dx = b.x - b2.x
			var dy = b.y - b2.y
			var dz = b.z - b2.z
			var distance = sqrt(dx * dx + dy * dy + dz * dz)
			e -= (b.mass * b2.mass) / distance
	return e

static func offset_momentum(bodies: Array):
	var px = 0.0
	var py = 0.0
	var pz = 0.0
	for b in bodies:
		px += b.vx * b.mass
		py += b.vy * b.mass
		pz += b.vz * b.mass
	var sun = bodies[0]
	sun.vx = -px / SOLAR_MASS
	sun.vy = -py / SOLAR_MASS
	sun.vz = -pz / SOLAR_MASS

static func init_bodies() -> Array:
	return [
		Body.new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
		Body.new(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01, 1.66007664274403694e-03, 7.69901118481134547e-03, -6.90460016972063023e-05, 9.54791938424326609e-04),
		Body.new(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01, -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05, 2.85885980666130812e-04),
		Body.new(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01, 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05, 4.36624404335156298e-05),
		Body.new(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01, 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592221303114738e-05, 5.15138902046611451e-05)
	]

func _init():
	var args = OS.get_cmdline_user_args()
	var n = 50000
	if args.size() > 0:
		n = int(args[0])

	var bodies = init_bodies()
	offset_momentum(bodies)

	print("%.9f" % compute_energy(bodies))
	var dt = 0.01
	var nbodies = bodies.size()

	var start_time = Time.get_ticks_usec()
	for step in range(n):
		for i in range(nbodies):
			bodies[i].advance(bodies, dt, i)
	var elapsed_ms = (Time.get_ticks_usec() - start_time) / 1000.0

	print("%.9f" % compute_energy(bodies))
	print("ELAPSED_MS: %.2f" % elapsed_ms)
	quit(0)
