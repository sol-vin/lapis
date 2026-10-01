// =============================================================================
// Binary Trees Benchmark (C++) - Based on The Computer Language Benchmarks Game
// =============================================================================

#include <iostream>
#include <fstream>
#include <algorithm>
#include <chrono>
#include <cstdint>

struct TreeNode {
    TreeNode* left;
    TreeNode* right;
    int item;

    TreeNode(int item, TreeNode* left = nullptr, TreeNode* right = nullptr)
        : left(left), right(right), item(item) {}

    ~TreeNode() {
        delete left;
        delete right;
    }

    static TreeNode* create(int item, int depth) {
        if (depth > 0) {
            return new TreeNode(
                item,
                create(2 * item - 1, depth - 1),
                create(2 * item, depth - 1)
            );
        } else {
            return new TreeNode(item);
        }
    }

    int check() const {
        int res = item;
        if (left) res += left->check();
        if (right) res -= right->check();
        return res;
    }
};

int main(int argc, char* argv[]) {
    int n = 12;
    if (argc > 1) {
        n = std::stoi(argv[1]);
    }

    int min_depth = 4;
    int max_depth = std::max(min_depth + 2, n);
    int stretch_depth = max_depth + 1;

    auto start_time = std::chrono::high_resolution_clock::now();

    TreeNode* stretch_tree = TreeNode::create(0, stretch_depth);
    int stretch_check = stretch_tree->check();
    delete stretch_tree;

    std::cout << "stretch tree of depth " << stretch_depth << "\t check: " << stretch_check << std::endl;

    TreeNode* long_lived_tree = TreeNode::create(0, max_depth);

    int depth = min_depth;
    int total_check = 0;
    while (depth <= max_depth) {
        int iterations = 1 << (max_depth - depth + min_depth);
        int check = 0;
        for (int i = 1; i <= iterations; ++i) {
            TreeNode* t1 = TreeNode::create(i, depth);
            check += t1->check();
            delete t1;

            TreeNode* t2 = TreeNode::create(-i, depth);
            check += t2->check();
            delete t2;
        }
        std::cout << (iterations * 2) << "\t trees of depth " << depth << "\t check: " << check << std::endl;
        total_check += check;
        depth += 2;
    }

    int long_lived_check = long_lived_tree->check();
    delete long_lived_tree;

    std::cout << "long lived tree of depth " << max_depth << "\t check: " << long_lived_check << std::endl;
    int total_checksum = stretch_check + total_check + long_lived_check;
    std::cout << "checksum: " << total_checksum << std::endl;
    std::cout << "RESULT: " << total_checksum << std::endl;

    auto end_time = std::chrono::high_resolution_clock::now();
    double elapsed_ms = std::chrono::duration<double, std::milli>(end_time - start_time).count();
    std::cout << "ELAPSED_MS: " << elapsed_ms << std::endl;

    try {
        std::ofstream out("benchmarks/results/binarytrees_cpp_timing.json");
        if (out.is_open()) {
            out << "{\n"
                << "  \"benchmark\": \"binarytrees\",\n"
                << "  \"language\": \"cpp\",\n"
                << "  \"elapsed_ms\": " << elapsed_ms << ",\n"
                << "  \"result\": \"" << total_checksum << "\"\n"
                << "}\n";
            out.close();
        }
    } catch (...) {}

    return 0;
}
