// =============================================================================
// Matrix Multiplication Benchmark (C++) - Based on Kostya/Benchmarks
// =============================================================================

#include <iostream>
#include <fstream>
#include <vector>
#include <cmath>
#include <chrono>
#include <iomanip>
#include <string>

using Matrix = std::vector<std::vector<double>>;

Matrix matgen(int n, double seed) {
    double tmp = seed / static_cast<double>(n) / static_cast<double>(n);
    Matrix a(n, std::vector<double>(n, 0.0));
    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < n; ++j) {
            a[i][j] = tmp * (i - j) * (i + j);
        }
    }
    return a;
}

Matrix matmul(const Matrix& a, const Matrix& b) {
    int m = static_cast<int>(a.size());
    int n = static_cast<int>(a[0].size());
    int p = static_cast<int>(b[0].size());

    // Transpose b
    Matrix b2(p, std::vector<double>(n, 0.0));
    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < p; ++j) {
            b2[j][i] = b[i][j];
        }
    }

    // Multiply
    Matrix c(m, std::vector<double>(p, 0.0));
    for (int i = 0; i < m; ++i) {
        const auto& ai = a[i];
        for (int j = 0; j < p; ++j) {
            double s = 0.0;
            const auto& b2j = b2[j];
            for (int k = 0; k < n; ++k) {
                s += ai[k] * b2j[k];
            }
            c[i][j] = s;
        }
    }
    return c;
}

double calc(int n) {
    n = (n >> 1) << 1;
    Matrix a = matgen(n, 1.0);
    Matrix b = matgen(n, 2.0);
    Matrix c = matmul(a, b);
    return c[n >> 1][n >> 1];
}

int main(int argc, char* argv[]) {
    // Self-verification
    double left = calc(101);
    double right = -18.67;
    if (std::abs(left - right) > 0.1) {
        std::cerr << "Verification failed: " << left << " != " << right << std::endl;
        return 1;
    }

    int n = 300;
    if (argc > 1) {
        try {
            n = std::stoi(argv[1]);
        } catch (...) {
            n = 300;
        }
    }

    auto start_time = std::chrono::high_resolution_clock::now();
    double res = calc(n);
    auto end_time = std::chrono::high_resolution_clock::now();
    double elapsed_ms = std::chrono::duration<double, std::milli>(end_time - start_time).count();

    std::cout << std::fixed << std::setprecision(6);
    std::cout << "RESULT: " << res << std::endl;
    std::cout << std::setprecision(2);
    std::cout << "ELAPSED_MS: " << elapsed_ms << std::endl;

    // Optional structured timing output
    std::ofstream timing_file("benchmarks/results/matmul_cpp_timing.json");
    if (timing_file.is_open()) {
        timing_file << "{\n";
        timing_file << "  \"benchmark\": \"matmul\",\n";
        timing_file << "  \"language\": \"cpp\",\n";
        timing_file << "  \"elapsed_ms\": " << elapsed_ms << ",\n";
        timing_file << "  \"result\": \"" << res << "\"\n";
        timing_file << "}\n";
        timing_file.close();
    }

    return 0;
}
