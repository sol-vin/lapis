// =============================================================================
// Sieve of Atkin + Prefix Trie Benchmark (C#) - Based on Kostya/Benchmarks
// =============================================================================

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

namespace Benchmarks
{
    public class TrieNode
    {
        public Dictionary<char, TrieNode> Children { get; } = new Dictionary<char, TrieNode>();
        public bool Terminal { get; set; } = false;
    }

    public class Sieve
    {
        private readonly int _limit;
        private readonly bool[] _prime;

        public Sieve(int limit)
        {
            _limit = limit;
            _prime = new bool[limit + 1];
        }

        public List<int> ToList()
        {
            var result = new List<int> { 2, 3 };
            for (int p = 5; p <= _limit; p++)
            {
                if (_prime[p]) result.Add(p);
            }
            return result;
        }

        public Sieve OmitSquares()
        {
            for (int r = 5; r * r < _limit; r++)
            {
                if (_prime[r])
                {
                    for (int i = r * r; i < _limit; i += r * r)
                    {
                        _prime[i] = false;
                    }
                }
            }
            return this;
        }

        public void Step1(int x, int y)
        {
            int n = (4 * x * x) + (y * y);
            if (n <= _limit && (n % 12 == 1 || n % 12 == 5))
            {
                _prime[n] = !_prime[n];
            }
        }

        public void Step2(int x, int y)
        {
            int n = (3 * x * x) + (y * y);
            if (n <= _limit && (n % 12 == 7))
            {
                _prime[n] = !_prime[n];
            }
        }

        public void Step3(int x, int y)
        {
            int n = (3 * x * x) - (y * y);
            if (x > y && n <= _limit && (n % 12 == 11))
            {
                _prime[n] = !_prime[n];
            }
        }

        public void LoopY(int x)
        {
            for (int y = 1; y * y < _limit; y++)
            {
                Step1(x, y);
                Step2(x, y);
                Step3(x, y);
            }
        }

        public void LoopX()
        {
            for (int x = 1; x * x < _limit; x++)
            {
                LoopY(x);
            }
        }
    }

    public static class PrimesBenchmark
    {
        public static TrieNode GenerateTrie(List<int> primes)
        {
            var root = new TrieNode();
            foreach (var prime in primes)
            {
                var s = prime.ToString();
                var head = root;
                foreach (var ch in s)
                {
                    if (!head.Children.TryGetValue(ch, out var next))
                    {
                        next = new TrieNode();
                        head.Children[ch] = next;
                    }
                    head = next;
                }
                head.Terminal = true;
            }
            return root;
        }

        public static List<int> Find(int upperBound, int prefix)
        {
            var sieve = new Sieve(upperBound);
            sieve.LoopX();
            sieve.OmitSquares();
            var primes = sieve.ToList();

            var root = GenerateTrie(primes);
            var strPrefix = prefix.ToString();
            var head = root;

            foreach (var ch in strPrefix)
            {
                if (!head.Children.TryGetValue(ch, out var next))
                {
                    return new List<int>();
                }
                head = next;
            }

            var queue = new Queue<(TrieNode Node, string Prefix)>();
            queue.Enqueue((head, strPrefix));
            var result = new List<int>();

            while (queue.Count > 0)
            {
                var (node, curPrefix) = queue.Dequeue();
                if (node.Terminal)
                {
                    result.Add(int.Parse(curPrefix));
                }
                foreach (var kvp in node.Children)
                {
                    queue.Enqueue((kvp.Value, curPrefix + kvp.Key));
                }
            }

            result.Sort();
            return result;
        }

        public static int Main(string[] args)
        {
            // Self-verification
            var left = new List<int> { 2, 23, 29 };
            var right = Find(100, 2);
            if (left.Count != right.Count || string.Join(",", left) != string.Join(",", right))
            {
                Console.Error.WriteLine("Verification failed");
                return 1;
            }

            int upperBound = args.Length > 0 && int.TryParse(args[0], out var ub) ? ub : 500000;
            int prefix = args.Length > 1 && int.TryParse(args[1], out var p) ? p : 3233;

            var sw = Stopwatch.StartNew();
            var res = Find(upperBound, prefix);
            sw.Stop();
            double elapsedMs = sw.Elapsed.TotalMilliseconds;

            Console.WriteLine($"RESULT: {res.Count}");
            Console.WriteLine($"ELAPSED_MS: {elapsedMs:F2}");

            try
            {
                Directory.CreateDirectory("benchmarks/results");
                File.WriteAllText("benchmarks/results/primes_csharp_timing.json",
                    $"{{\n  \"benchmark\": \"primes\",\n  \"language\": \"csharp\",\n  \"elapsed_ms\": {elapsedMs:F2},\n  \"result\": \"{res.Count}\"\n}}\n");
            }
            catch {}

            return 0;
        }
    }
}
