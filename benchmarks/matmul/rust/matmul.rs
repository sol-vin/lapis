// =============================================================================
// Matrix Multiplication Benchmark (Rust) - Based on Kostya/Benchmarks
// =============================================================================

use std::env;
use std::fs;
use std::time::Instant;

type Matrix = Vec<Vec<f64>>;

fn matgen(n: usize, seed: f64) -> Matrix {
    let tmp = seed / (n as f64) / (n as f64);
    let mut a = vec![vec![0.0f64; n]; n];
    for i in 0..n {
        for j in 0..n {
            let i_f = i as f64;
            let j_f = j as f64;
            a[i][j] = tmp * (i_f - j_f) * (i_f + j_f);
        }
    }
    a
}

fn matmul(a: &Matrix, b: &Matrix) -> Matrix {
    let m = a.len();
    let n = a[0].len();
    let p = b[0].len();

    // Transpose b
    let mut b2 = vec![vec![0.0f64; n]; p];
    for i in 0..n {
        for j in 0..p {
            b2[j][i] = b[i][j];
        }
    }

    // Multiply
    let mut c = vec![vec![0.0f64; p]; m];
    for i in 0..m {
        let ai = &a[i];
        for j in 0..p {
            let mut s = 0.0f64;
            let b2j = &b2[j];
            for k in 0..n {
                s += ai[k] * b2j[k];
            }
            c[i][j] = s;
        }
    }
    c
}

fn calc(n: usize) -> f64 {
    let n = (n >> 1) << 1;
    let a = matgen(n, 1.0);
    let b = matgen(n, 2.0);
    let c = matmul(&a, &b);
    c[n >> 1][n >> 1]
}

fn main() {
    // Self-verification
    let left = calc(101);
    let right = -18.67;
    if (left - right).abs() > 0.1 {
        eprintln!("Verification failed: {} != {}", left, right);
        std::process::exit(1);
    }

    let args: Vec<String> = env::args().collect();
    let n = if args.len() > 1 {
        args[1].parse::<usize>().unwrap_or(300)
    } else {
        300
    };

    let start = Instant::now();
    let res = calc(n);
    let duration = start.elapsed();
    let elapsed_ms = (duration.as_secs_f64()) * 1000.0;

    println!("RESULT: {:.6}", res);
    println!("ELAPSED_MS: {:.2}", elapsed_ms);

    let _ = fs::create_dir_all("benchmarks/results");
    let json_data = format!(
        "{{\n  \"benchmark\": \"matmul\",\n  \"language\": \"rust\",\n  \"elapsed_ms\": {:.2},\n  \"result\": \"{:.6}\"\n}}\n",
        elapsed_ms, res
    );
    let _ = fs::write("benchmarks/results/matmul_rust_timing.json", json_data);
}
