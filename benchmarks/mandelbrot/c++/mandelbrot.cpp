// =============================================================================
// Mandelbrot 2D Fractal Rasterization Benchmark (C++)
// =============================================================================

#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <cstdint>

int main(int argc, char* argv[]) {
    int size = 500;
    if (argc > 1) {
        size = std::stoi(argv[1]);
    }

    int w = size;
    int h = size;
    int iter = 50;
    double limit_sq = 4.0;
    int64_t checksum = 0;

    auto start_time = std::chrono::high_resolution_clock::now();

    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            double zr = 0.0;
            double zi = 0.0;
            double cr = 2.0 * x / w - 1.5;
            double ci = 2.0 * y / h - 1.0;

            int i = 0;
            double tr = 0.0;
            double ti = 0.0;
            while (i < iter && (tr + ti <= limit_sq)) {
                zi = 2.0 * zr * zi + ci;
                zr = tr - ti + cr;
                tr = zr * zr;
                ti = zi * zi;
                ++i;
            }

            if (tr + ti <= limit_sq) {
                checksum = (checksum + 1) & 0xFFFFFFFFFFFFLL;
            }
        }
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    double elapsed_ms = std::chrono::duration<double, std::milli>(end_time - start_time).count();

    std::cout << "Mandelbrot " << w << "x" << h << " points inside: " << checksum << std::endl;
    std::cout << "RESULT: " << checksum << std::endl;
    std::cout << "ELAPSED_MS: " << elapsed_ms << std::endl;

    try {
        std::ofstream out("benchmarks/results/mandelbrot_cpp_timing.json");
        if (out.is_open()) {
            out << "{\n"
                << "  \"benchmark\": \"mandelbrot\",\n"
                << "  \"language\": \"cpp\",\n"
                << "  \"elapsed_ms\": " << elapsed_ms << ",\n"
                << "  \"result\": \"" << checksum << "\"\n"
                << "}\n";
            out.close();
        }
    } catch (...) {}

    return 0;
}
