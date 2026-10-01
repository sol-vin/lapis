// =============================================================================
// Mandelbrot 2D Fractal Rasterization Benchmark (C#)
// =============================================================================

using System;
using System.Diagnostics;
using System.IO;

namespace Benchmarks
{
    public static class MandelbrotBenchmark
    {
        public static int Main(string[] args)
        {
            int size = 500;
            if (args.Length > 0 && int.TryParse(args[0], out int parsedSize))
            {
                size = parsedSize;
            }

            int w = size;
            int h = size;
            int iter = 50;
            double limitSq = 4.0;
            long checksum = 0;

            Stopwatch sw = Stopwatch.StartNew();

            for (int y = 0; y < h; ++y)
            {
                for (int x = 0; x < w; ++x)
                {
                    double zr = 0.0;
                    double zi = 0.0;
                    double cr = 2.0 * x / w - 1.5;
                    double ci = 2.0 * y / h - 1.0;

                    int i = 0;
                    double tr = 0.0;
                    double ti = 0.0;
                    while (i < iter && (tr + ti <= limitSq))
                    {
                        zi = 2.0 * zr * zi + ci;
                        zr = tr - ti + cr;
                        tr = zr * zr;
                        ti = zi * zi;
                        ++i;
                    }

                    if (tr + ti <= limitSq)
                    {
                        checksum = (checksum + 1) & 0xFFFFFFFFFFFFL;
                    }
                }
            }

            sw.Stop();
            double elapsedMs = sw.Elapsed.TotalMilliseconds;

            Console.WriteLine($"Mandelbrot {w}x{h} points inside: {checksum}");
            Console.WriteLine($"RESULT: {checksum}");
            Console.WriteLine($"ELAPSED_MS: {elapsedMs:F2}");

            try
            {
                Directory.CreateDirectory("benchmarks/results");
                File.WriteAllText("benchmarks/results/mandelbrot_csharp_timing.json",
                    $"{{\n  \"benchmark\": \"mandelbrot\",\n  \"language\": \"csharp\",\n  \"elapsed_ms\": {elapsedMs:F2},\n  \"result\": \"{checksum}\"\n}}\n");
            }
            catch {}

            return 0;
        }
    }
}
