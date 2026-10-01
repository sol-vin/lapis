// =============================================================================
// N-Body Simulation Benchmark (C++) - Based on Kostya / Alioth
// =============================================================================

#include <iostream>
#include <iomanip>
#include <fstream>
#include <vector>
#include <cmath>
#include <chrono>

constexpr double PI = 3.14159265358979323846;
constexpr double SOLAR_MASS = 4.0 * PI * PI;
constexpr double DAYS_PER_YEAR = 365.24;

struct Body {
    double x, y, z;
    double vx, vy, vz;
    double mass;

    Body(double px, double py, double pz, double pvx, double pvy, double pvz, double pmass)
        : x(px), y(py), z(pz),
          vx(pvx * DAYS_PER_YEAR), vy(pvy * DAYS_PER_YEAR), vz(pvz * DAYS_PER_YEAR),
          mass(pmass * SOLAR_MASS) {}

    void advance(std::vector<Body>& bodies, double dt, size_t i) {
        size_t nbodies = bodies.size();
        for (size_t j = i + 1; j < nbodies; ++j) {
            Body& b2 = bodies[j];
            double dx = x - b2.x;
            double dy = y - b2.y;
            double dz = z - b2.z;

            double distance = std::sqrt(dx * dx + dy * dy + dz * dz);
            double mag = dt / (distance * distance * distance);
            double b_mass_mag = mass * mag;
            double b2_mass_mag = b2.mass * mag;

            vx -= dx * b2_mass_mag;
            vy -= dy * b2_mass_mag;
            vz -= dz * b2_mass_mag;
            b2.vx += dx * b_mass_mag;
            b2.vy += dy * b_mass_mag;
            b2.vz += dz * b_mass_mag;
        }

        x += dt * vx;
        y += dt * vy;
        z += dt * vz;
    }
};

double energy(const std::vector<Body>& bodies) {
    double e = 0.0;
    size_t nbodies = bodies.size();
    for (size_t i = 0; i < nbodies; ++i) {
        const Body& b = bodies[i];
        e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);
        for (size_t j = i + 1; j < nbodies; ++j) {
            const Body& b2 = bodies[j];
            double dx = b.x - b2.x;
            double dy = b.y - b2.y;
            double dz = b.z - b2.z;
            double distance = std::sqrt(dx * dx + dy * dy + dz * dz);
            e -= (b.mass * b2.mass) / distance;
        }
    }
    return e;
}

void offset_momentum(std::vector<Body>& bodies) {
    double px = 0.0;
    double py = 0.0;
    double pz = 0.0;
    for (const auto& b : bodies) {
        px += b.vx * b.mass;
        py += b.vy * b.mass;
        pz += b.vz * b.mass;
    }
    bodies[0].vx = -px / SOLAR_MASS;
    bodies[0].vy = -py / SOLAR_MASS;
    bodies[0].vz = -pz / SOLAR_MASS;
}

std::vector<Body> init_bodies() {
    return {
        Body(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
        Body(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01, 1.66007664274403694e-03, 7.69901118481134547e-03, -6.90460016972063023e-05, 9.54791938424326609e-04),
        Body(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01, -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05, 2.85885980666130812e-04),
        Body(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01, 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05, 4.36624404335156298e-05),
        Body(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01, 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592221303114738e-05, 5.15138902046611451e-05)
    };
}

int main(int argc, char* argv[]) {
    int n = 50000;
    if (argc > 1) {
        n = std::stoi(argv[1]);
    }

    auto bodies = init_bodies();
    offset_momentum(bodies);

    double dt = 0.01;
    size_t nbodies = bodies.size();

    auto start_time = std::chrono::high_resolution_clock::now();
    for (int step = 0; step < n; ++step) {
        for (size_t i = 0; i < nbodies; ++i) {
            bodies[i].advance(bodies, dt, i);
        }
    }
    auto end_time = std::chrono::high_resolution_clock::now();
    double elapsed_ms = std::chrono::duration<double, std::milli>(end_time - start_time).count();
    double final_energy = energy(bodies);

    std::cout << std::fixed << std::setprecision(9) << final_energy << std::endl;
    std::cout << "RESULT: " << std::fixed << std::setprecision(9) << final_energy << std::endl;
    std::cout << "ELAPSED_MS: " << std::fixed << std::setprecision(2) << elapsed_ms << std::endl;

    try {
        std::ofstream out("benchmarks/results/nbody_cpp_timing.json");
        if (out.is_open()) {
            out << "{\n"
                << "  \"benchmark\": \"nbody\",\n"
                << "  \"language\": \"cpp\",\n"
                << "  \"elapsed_ms\": " << std::fixed << std::setprecision(2) << elapsed_ms << ",\n"
                << "  \"result\": \"" << std::fixed << std::setprecision(9) << final_energy << "\"\n"
                << "}\n";
            out.close();
        }
    } catch (...) {}

    return 0;
}
