// =============================================================================
// Binary Trees Benchmark (Rust) - Based on The Computer Language Benchmarks Game
// =============================================================================

use std::cmp::max;
use std::env;
use std::fs;
use std::time::Instant;

struct TreeNode {
    item: i32,
    left: Option<Box<TreeNode>>,
    right: Option<Box<TreeNode>>,
}

impl TreeNode {
    fn create(item: i32, depth: i32) -> Self {
        if depth > 0 {
            TreeNode {
                item,
                left: Some(Box::new(TreeNode::create(2 * item - 1, depth - 1))),
                right: Some(Box::new(TreeNode::create(2 * item, depth - 1))),
            }
        } else {
            TreeNode {
                item,
                left: None,
                right: None,
            }
        }
    }

    fn check(&self) -> i32 {
        let mut res = self.item;
        if let Some(ref l) = self.left {
            res += l.check();
        }
        if let Some(ref r) = self.right {
            res -= r.check();
        }
        res
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let n = if args.len() > 1 {
        args[1].parse::<i32>().unwrap_or(12)
    } else {
        12
    };

    let min_depth = 4;
    let max_depth = max(min_depth + 2, n);
    let stretch_depth = max_depth + 1;

    let start_time = Instant::now();

    let stretch_check = TreeNode::create(0, stretch_depth).check();
    println!("stretch tree of depth {}\t check: {}", stretch_depth, stretch_check);

    let long_lived_tree = TreeNode::create(0, max_depth);

    let mut depth = min_depth;
    let mut total_check = 0;
    while depth <= max_depth {
        let iterations = 1 << (max_depth - depth + min_depth);
        let mut check = 0;
        for i in 1..=iterations {
            check += TreeNode::create(i, depth).check();
            check += TreeNode::create(-i, depth).check();
        }
        println!("{}\t trees of depth {}\t check: {}", iterations * 2, depth, check);
        total_check += check;
        depth += 2;
    }

    let long_lived_check = long_lived_tree.check();
    println!("long lived tree of depth {}\t check: {}", max_depth, long_lived_check);

    let total_checksum = stretch_check + total_check + long_lived_check;
    println!("checksum: {}", total_checksum);
    println!("RESULT: {}", total_checksum);

    let duration = start_time.elapsed();
    let elapsed_ms = duration.as_secs_f64() * 1000.0;
    println!("ELAPSED_MS: {:.2}", elapsed_ms);

    let _ = fs::create_dir_all("benchmarks/results");
    let json_data = format!(
        "{{\n  \"benchmark\": \"binarytrees\",\n  \"language\": \"rust\",\n  \"elapsed_ms\": {:.2},\n  \"result\": \"{}\"\n}}\n",
        elapsed_ms, total_checksum
    );
    let _ = fs::write("benchmarks/results/binarytrees_rust_timing.json", json_data);
}
