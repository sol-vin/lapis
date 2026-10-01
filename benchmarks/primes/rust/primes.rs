// =============================================================================
// Sieve of Atkin + Prefix Trie Benchmark (Rust) - Based on Kostya/Benchmarks
// =============================================================================

use std::collections::{HashMap, VecDeque};
use std::env;
use std::fs;
use std::time::Instant;

struct TrieNode {
    children: HashMap<char, TrieNode>,
    terminal: bool,
}

impl TrieNode {
    fn new() -> Self {
        TrieNode {
            children: HashMap::new(),
            terminal: false,
        }
    }
}

struct Sieve {
    limit: usize,
    prime: Vec<bool>,
}

impl Sieve {
    fn new(limit: usize) -> Self {
        Sieve {
            limit,
            prime: vec![false; limit + 1],
        }
    }

    fn to_list(&self) -> Vec<usize> {
        let mut result = vec![2, 3];
        for p in 5..=self.limit {
            if self.prime[p] {
                result.push(p);
            }
        }
        result
    }

    fn omit_squares(&mut self) {
        let mut r = 5;
        while r * r < self.limit {
            if self.prime[r] {
                let mut i = r * r;
                while i < self.limit {
                    self.prime[i] = false;
                    i += r * r;
                }
            }
            r += 1;
        }
    }

    fn step1(&mut self, x: usize, y: usize) {
        let n = (4 * x * x) + (y * y);
        if n <= self.limit && (n % 12 == 1 || n % 12 == 5) {
            self.prime[n] = !self.prime[n];
        }
    }

    fn step2(&mut self, x: usize, y: usize) {
        let n = (3 * x * x) + (y * y);
        if n <= self.limit && (n % 12 == 7) {
            self.prime[n] = !self.prime[n];
        }
    }

    fn step3(&mut self, x: usize, y: usize) {
        let n = (3 * x * x) - (y * y);
        if x > y && n <= self.limit && (n % 12 == 11) {
            self.prime[n] = !self.prime[n];
        }
    }

    fn loop_y(&mut self, x: usize) {
        let mut y = 1;
        while y * y < self.limit {
            self.step1(x, y);
            self.step2(x, y);
            self.step3(x, y);
            y += 1;
        }
    }

    fn loop_x(&mut self) {
        let mut x = 1;
        while x * x < self.limit {
            self.loop_y(x);
            x += 1;
        }
    }
}

fn generate_trie(primes: &[usize]) -> TrieNode {
    let mut root = TrieNode::new();
    for &prime in primes {
        let s = prime.to_string();
        let mut head = &mut root;
        for ch in s.chars() {
            head = head.children.entry(ch).or_insert_with(TrieNode::new);
        }
        head.terminal = true;
    }
    root
}

fn find(upper_bound: usize, prefix: usize) -> Vec<usize> {
    let mut sieve = Sieve::new(upper_bound);
    sieve.loop_x();
    sieve.omit_squares();
    let primes = sieve.to_list();

    let root = generate_trie(&primes);
    let str_prefix = prefix.to_string();
    let mut head = &root;

    for ch in str_prefix.chars() {
        match head.children.get(&ch) {
            Some(next) => head = next,
            None => return Vec::new(),
        }
    }

    let mut queue: VecDeque<(&TrieNode, String)> = VecDeque::new();
    queue.push_back((head, str_prefix));
    let mut result = Vec::new();

    while let Some((node, cur_prefix)) = queue.pop_front() {
        if node.terminal {
            if let Ok(val) = cur_prefix.parse::<usize>() {
                result.push(val);
            }
        }
        for (&ch, next_node) in &node.children {
            let mut next_prefix = cur_prefix.clone();
            next_prefix.push(ch);
            queue.push_back((next_node, next_prefix));
        }
    }

    result.sort();
    result
}

fn main() {
    // Self-verification
    let left = vec![2, 23, 29];
    let right = find(100, 2);
    if left != right {
        eprintln!("Verification failed: {:?} != {:?}", left, right);
        std::process::exit(1);
    }

    let args: Vec<String> = env::args().collect();
    let upper_bound = if args.len() > 1 {
        args[1].parse::<usize>().unwrap_or(500000)
    } else {
        500000
    };
    let prefix = if args.len() > 2 {
        args[2].parse::<usize>().unwrap_or(3233)
    } else {
        3233
    };

    let start = Instant::now();
    let res = find(upper_bound, prefix);
    let duration = start.elapsed();
    let elapsed_ms = duration.as_secs_f64() * 1000.0;

    println!("RESULT: {}", res.len());
    println!("ELAPSED_MS: {:.2}", elapsed_ms);

    let _ = fs::create_dir_all("benchmarks/results");
    let json_data = format!(
        "{{\n  \"benchmark\": \"primes\",\n  \"language\": \"rust\",\n  \"elapsed_ms\": {:.2},\n  \"result\": \"{}\"\n}}\n",
        elapsed_ms, res.len()
    );
    let _ = fs::write("benchmarks/results/primes_rust_timing.json", json_data);
}
