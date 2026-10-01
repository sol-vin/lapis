// =============================================================================
// Binary Trees Benchmark (C#) - Based on The Computer Language Benchmarks Game
// =============================================================================

using System;
using System.Diagnostics;
using System.IO;

namespace Benchmarks
{
    public class TreeNode
    {
        public TreeNode? Left;
        public TreeNode? Right;
        public int Item;

        public TreeNode(int item, TreeNode? left = null, TreeNode? right = null)
        {
            Item = item;
            Left = left;
            Right = right;
        }

        public static TreeNode Create(int item, int depth)
        {
            if (depth > 0)
            {
                return new TreeNode(
                    item,
                    Create(2 * item - 1, depth - 1),
                    Create(2 * item, depth - 1)
                );
            }
            return new TreeNode(item);
        }

        public int Check()
        {
            int res = Item;
            if (Left != null) res += Left.Check();
            if (Right != null) res -= Right.Check();
            return res;
        }
    }

    public static class BinaryTreesBenchmark
    {
        public static int Main(string[] args)
        {
            int n = 12;
            if (args.Length > 0 && int.TryParse(args[0], out int parsedN))
            {
                n = parsedN;
            }

            int minDepth = 4;
            int maxDepth = Math.Max(minDepth + 2, n);
            int stretchDepth = maxDepth + 1;

            Stopwatch sw = Stopwatch.StartNew();

            int stretchCheck = TreeNode.Create(0, stretchDepth).Check();
            Console.WriteLine($"stretch tree of depth {stretchDepth}\t check: {stretchCheck}");

            TreeNode longLivedTree = TreeNode.Create(0, maxDepth);

            int depth = minDepth;
            int totalCheck = 0;
            while (depth <= maxDepth)
            {
                int iterations = 1 << (maxDepth - depth + minDepth);
                int check = 0;
                for (int i = 1; i <= iterations; ++i)
                {
                    check += TreeNode.Create(i, depth).Check();
                    check += TreeNode.Create(-i, depth).Check();
                }
                Console.WriteLine($"{iterations * 2}\t trees of depth {depth}\t check: {check}");
                totalCheck += check;
                depth += 2;
            }

            int longLivedCheck = longLivedTree.Check();
            Console.WriteLine($"long lived tree of depth {maxDepth}\t check: {longLivedCheck}");

            int totalChecksum = stretchCheck + totalCheck + longLivedCheck;
            Console.WriteLine($"checksum: {totalChecksum}");
            Console.WriteLine($"RESULT: {totalChecksum}");

            sw.Stop();
            double elapsedMs = sw.Elapsed.TotalMilliseconds;
            Console.WriteLine($"ELAPSED_MS: {elapsedMs:F2}");

            try
            {
                Directory.CreateDirectory("benchmarks/results");
                File.WriteAllText("benchmarks/results/binarytrees_csharp_timing.json",
                    $"{{\n  \"benchmark\": \"binarytrees\",\n  \"language\": \"csharp\",\n  \"elapsed_ms\": {elapsedMs:F2},\n  \"result\": \"{totalChecksum}\"\n}}\n");
            }
            catch {}

            return 0;
        }
    }
}
