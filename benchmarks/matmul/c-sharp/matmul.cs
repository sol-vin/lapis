// =============================================================================
// Matrix Multiplication Benchmark (C#) - Based on Kostya/Benchmarks
// =============================================================================

using System;
using System.Diagnostics;
using System.IO;

namespace Benchmarks
{
    public static class MatMulBenchmark
    {
        public static double[][] MatGen(int n, double seed)
        {
            double tmp = seed / n / n;
            double[][] a = new double[n][];
            for (int i = 0; i < n; ++i)
            {
                a[i] = new double[n];
                for (int j = 0; j < n; ++j)
                {
                    a[i][j] = tmp * (i - j) * (i + j);
                }
            }
            return a;
        }

        public static double[][] MatMul(double[][] a, double[][] b)
        {
            int m = a.Length;
            int n = a[0].Length;
            int p = b[0].Length;

            // Transpose b
            double[][] b2 = new double[p][];
            for (int j = 0; j < p; ++j)
            {
                b2[j] = new double[n];
                for (int i = 0; i < n; ++i)
                {
                    b2[j][i] = b[i][j];
                }
            }

            // Multiply
            double[][] c = new double[m][];
            for (int i = 0; i < m; ++i)
            {
                c[i] = new double[p];
                double[] ai = a[i];
                for (int j = 0; j < p; ++j)
                {
                    double s = 0.0;
                    double[] b2j = b2[j];
                    for (int k = 0; k < n; ++k)
                    {
                        s += ai[k] * b2j[k];
                    }
                    c[i][j] = s;
                }
            }
            return c;
        }

        public static double Calc(int n)
        {
            n = (n >> 1) << 1;
            double[][] a = MatGen(n, 1.0);
            double[][] b = MatGen(n, 2.0);
            double[][] c = MatMul(a, b);
            return c[n >> 1][n >> 1];
        }

        public static int Main(string[] args)
        {
            // Self-verification
            double left = Calc(101);
            double right = -18.67;
            if (Math.Abs(left - right) > 0.1)
            {
                Console.Error.WriteLine($"Verification failed: {left} != {right}");
                return 1;
            }

            int n = 300;
            if (args.Length > 0 && int.TryParse(args[0], out int parsedN))
            {
                n = parsedN;
            }

            Stopwatch sw = Stopwatch.StartNew();
            double res = Calc(n);
            sw.Stop();
            double elapsedMs = sw.Elapsed.TotalMilliseconds;

            Console.WriteLine($"RESULT: {res:F6}");
            Console.WriteLine($"ELAPSED_MS: {elapsedMs:F2}");

            try
            {
                Directory.CreateDirectory("benchmarks/results");
                File.WriteAllText("benchmarks/results/matmul_csharp_timing.json",
                    $"{{\n  \"benchmark\": \"matmul\",\n  \"language\": \"csharp\",\n  \"elapsed_ms\": {elapsedMs:F2},\n  \"result\": \"{res:F6}\"\n}}\n");
            }
            catch {}

            return 0;
        }
    }
}
