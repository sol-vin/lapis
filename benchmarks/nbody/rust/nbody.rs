// =============================================================================
// N-Body Simulation Benchmark (Rust) - Based on Kostya / Alioth
// =============================================================================

use std::env;
use std::f64::consts::PI;
use std::fs;
use std::time::Instant;

const SOLAR_MASS: f64 = 4.0 * PI * PI;
const DAYS_PER_YEAR: f64 = 365.24;

#[derive(Clone, Copy)]
struct Body {
    x: f64,
    y: f64,
    z: f64,
    vx: f64,
    vy: f64,
    vz: f64,
    mass: f64,
}

impl Body {
    fn new(px: f64, py: f64, pz: f64, pvx: f64, pvy: f64, pvz: f64, pmass: f64) -> Self {
        Body {
            x: px,
            y: py,
            z: pz,
            vx: pvx * DAYS_PER_YEAR,
            vy: pvy * DAYS_PER_YEAR,
            vz: pvz * DAYS_PER_YEAR,
            mass: pmass * SOLAR_MASS,
        }
    }
}

fn energy(bodies: &[Body]) -> f64 {
    let mut e = 0.0f64;
    let nbodies = bodies.len();
    for i in 0..nbodies {
        let b = bodies[i];
        e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);
        for j in (i + 1)..nbodies {
            let b2 = bodies[j];
            let dx = b.x - b2.x;
            let dy = b.y - b2.y;
            let dz = b.z - b2.z;
            let distance = (dx * dx + dy * dy + dz * dz).sqrt();
            e -= (b.mass * b2.mass) / distance;
        }
    }
    e
}

fn offset_momentum(bodies: &mut [Body]) {
    let mut px = 0.0f64;
    let mut py = 0.0f64;
    let mut pz = 0.0f64;
    for b in bodies.iter() {
        px += b.vx * b.mass;
        py += b.vy * b.mass;
        pz += b.vz * b.mass;
    }
    bodies[0].vx = -px / SOLAR_MASS;
    bodies[0].vy = -py / SOLAR_MASS;
    bodies[0].vz = -pz / SOLAR_MASS;
}

fn init_bodies() -> Vec<Body> {
    vec![
        Body::new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
        Body::new(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01, 1.66007664274403694e-03, 7.69901118481134547e-03, -6.90460016972063023e-05, 9.54791938424326609e-04),
        Body::new(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01, -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05, 2.85885980666130812e-04),
        Body::new(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01, 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05, 4.36624404335156298e-05),
        Body::new(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01, 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592221303114738e-05, 5.15138902046611451e-05),
    ]
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let n = if args.len() > 1 {
        args[1].parse::<usize>().unwrap_or(50000)
    } else {
        50000
    };

    let mut bodies = init_bodies();
    offset_momentum(&mut bodies);

    let dt = 0.01f64;
    let nbodies = bodies.len();

    let start_time = Instant::now();
    for _ in 0..n {
        for i in 0..nbodies {
            for j in (i + 1)..nbodies {
                let dx = bodies[i].x - bodies[j].x;
                let dy = bodies[i].y - bodies[j].y;
                let dz = bodies[i].z - bodies[j].z;

                let distance = (dx * dx + dy * dy + dz * dz).sqrt();
                let mag = dt / (distance * distance * distance);
                let b_mass_mag = bodies[i].mass * mag;
                let b2_mass_mag = bodies[j].mass * mag;

                bodies[i].vx -= dx * b2_mass_mag;
                bodies[i].vy -= dy * b2_mass_mag;
                bodies[i].vz -= dz * b2_mass_mag;
                bodies[j].vx += dx * b_mass_mag;
                bodies[j].vy += dy * b_mass_mag;
                bodies[j].vz += dz * b_mass_mag;
            }

            bodies[i].x += dt * bodies[i].vx;
            bodies[i].y += dt * bodies[i].vy;
            bodies[i].z += dt * bodies[i].vz;
        }
    }
    let duration = start_time.elapsed();
    let elapsed_ms = duration.as_secs_f64() * 1000.0;
    let final_energy = energy(&bodies);

    println!("{:.9}", final_energy);
    println!("RESULT: {:.9}", final_energy);
    println!("ELAPSED_MS: {:.2}", elapsed_ms);

    let _ = fs::create_dir_all("benchmarks/results");
    let json_data = format!(
        "{{\n  \"benchmark\": \"nbody\",\n  \"language\": \"rust\",\n  \"elapsed_ms\": {:.2},\n  \"result\": \"{:.9}\"\n}}\n",
        elapsed_ms, final_energy
    );
    let _ = fs::write("benchmarks/results/nbody_rust_timing.json", json_data);
}
