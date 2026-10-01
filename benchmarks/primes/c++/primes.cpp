// =============================================================================
// Sieve of Atkin + Prefix Trie Benchmark (C++) - Based on Kostya/Benchmarks
// =============================================================================

#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <unordered_map>
#include <algorithm>
#include <chrono>

struct TrieNode {
    std::unordered_map<char, TrieNode*> children;
    bool terminal = false;

    ~TrieNode() {
        for (auto& pair : children) {
            delete pair.second;
        }
    }
};

class Sieve {
    int limit;
    std::vector<bool> prime;

public:
    Sieve(int limit) : limit(limit), prime(limit + 1, false) {}

    std::vector<int> to_list() const {
        std::vector<int> result = {2, 3};
        for (int p = 5; p <= limit; ++p) {
            if (prime[p]) result.push_back(p);
        }
        return result;
    }

    void omit_squares() {
        for (int r = 5; r * r < limit; ++r) {
            if (prime[r]) {
                for (int i = r * r; i < limit; i += r * r) {
                    prime[i] = false;
                }
            }
        }
    }

    void step1(int x, int y) {
        int n = (4 * x * x) + (y * y);
        if (n <= limit && (n % 12 == 1 || n % 12 == 5)) {
            prime[n] = !prime[n];
        }
    }

    void step2(int x, int y) {
        int n = (3 * x * x) + (y * y);
        if (n <= limit && (n % 12 == 7)) {
            prime[n] = !prime[n];
        }
    }

    void step3(int x, int y) {
        int n = (3 * x * x) - (y * y);
        if (x > y && n <= limit && (n % 12 == 11)) {
            prime[n] = !prime[n];
        }
    }

    void loop_y(int x) {
        for (int y = 1; y * y < limit; ++y) {
            step1(x, y);
            step2(x, y);
            step3(x, y);
        }
    }

    void loop_x() {
        for (int x = 1; x * x < limit; ++x) {
            loop_y(x);
        }
    }

    void calc() {
        loop_x();
        omit_squares();
    }
};

TrieNode* generate_trie(const std::vector<int>& l) {
    TrieNode* root = new TrieNode();
    for (int el : l) {
        TrieNode* head = root;
        std::string s = std::to_string(el);
        for (char ch : s) {
            if (head->children.find(ch) == head->children.end()) {
                head->children[ch] = new TrieNode();
            }
            head = head->children[ch];
        }
        head->terminal = true;
    }
    return root;
}

std::vector<int> find_primes(int upper_bound, int prefix) {
    Sieve sieve(upper_bound);
    sieve.calc();

    std::string str_prefix = std::to_string(prefix);
    TrieNode* root = generate_trie(sieve.to_list());

    TrieNode* head = root;
    for (char ch : str_prefix) {
        if (head->children.find(ch) == head->children.end()) {
            delete root;
            return {};
        }
        head = head->children[ch];
    }

    std::vector<std::pair<TrieNode*, std::string>> queue;
    queue.push_back({head, str_prefix});
    std::vector<int> result;

    while (!queue.empty()) {
        auto item = queue.back();
        queue.pop_back();
        TrieNode* top = item.first;
        std::string cur_prefix = item.second;

        if (top->terminal) {
            result.push_back(std::stoi(cur_prefix));
        }
        for (auto& pair : top->children) {
            queue.insert(queue.begin(), {pair.second, cur_prefix + pair.first});
        }
    }

    std::sort(result.begin(), result.end());
    delete root;
    return result;
}

int main(int argc, char* argv[]) {
    // Self-verification
    std::vector<int> left = {2, 23, 29};
    std::vector<int> right = find_primes(100, 2);
    if (left != right) {
        std::cerr << "Verification failed!" << std::endl;
        return 1;
    }

    int upper_bound = 500000;
    int prefix = 3233;
    if (argc > 1) upper_bound = std::stoi(argv[1]);
    if (argc > 2) prefix = std::stoi(argv[2]);

    auto start_time = std::chrono::high_resolution_clock::now();
    std::vector<int> res = find_primes(upper_bound, prefix);
    auto end_time = std::chrono::high_resolution_clock::now();
    double elapsed_ms = std::chrono::duration<double, std::milli>(end_time - start_time).count();

    std::cout << "RESULT: " << res.size() << std::endl;
    std::cout << "ELAPSED_MS: " << elapsed_ms << std::endl;

    std::ofstream timing_file("benchmarks/results/primes_cpp_timing.json");
    if (timing_file.is_open()) {
        timing_file << "{\n";
        timing_file << "  \"benchmark\": \"primes\",\n";
        timing_file << "  \"language\": \"cpp\",\n";
        timing_file << "  \"elapsed_ms\": " << elapsed_ms << ",\n";
        timing_file << "  \"result\": \"" << res.size() << "\"\n";
        timing_file << "}\n";
        timing_file.close();
    }

    return 0;
}
