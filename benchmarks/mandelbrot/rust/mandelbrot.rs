// =============================================================================
// Mandelbrot 2D Fractal Rasterization Benchmark (Rust)
// =============================================================================

use std::env;
use std::fs;
use std::time::Instant;

fn main() {
    let args: Vec<String> = env::args().collect();
    let size = if args.len() > 1 {
        args[1].parse::<usize>().unwrap_or(500)
    } else {
        500
    };

    let w = size;
    let h = size;
    let iter = 50;
    let limit_sq = 4.0;
    let mut checksum: i64 = 0;

    let start_time = Instant::now();

    for y in 0..h {
        for x in 0..w {
            let mut zr = 0.0f64;
            let mut zi = 0.0f64;
            let cr = 2.0 * (x as f64) / (w as f64) - 1.5;
            let ci = 2.0 * (y as f64) / (h as f64) - 1.0;

            let mut i = 0;
            let mut tr = 0.0f64;
            let mut ti = 0.0f64;
            while i < iter && (tr + ti <= limit_sq) {
                zi = 2.0 * zr * zi + ci;
                zr = tr - ti + cr;
                tr = zr * zr;
                ti = zi * zi;
                i += 1;
            }

            if tr + ti <= limit_sq {
                checksum = (checksum + 1) & 0xFFFFFFFFFFFFi64;
            }
        }
    }

    let duration = start_time.elapsed();
    let elapsed_ms = duration.as_secs_f64() * 1000.0;

    println!("Mandelbrot {}x{} points inside: {}", w, h, checksum);
    println!("RESULT: {}", checksum);
    println!("ELAPSED_MS: {:.2}", elapsed_ms);

    let _ = fs::create_dir_all("benchmarks/results");
    let json_data = format!(
        "{{\n  \"benchmark\": \"mandelbrot\",\n  \"language\": \"rust\",\n  \"elapsed_ms\": {:.2},\n  \"result\": \"{}\"\n}}\n",
        elapsed_ms, checksum
    );
    let _ = fs::write("benchmarks/results/mandelbrot_rust_timing.json", json_data);
}
