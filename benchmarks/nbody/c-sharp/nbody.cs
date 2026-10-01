// =============================================================================
// N-Body Simulation Benchmark (C#) - Based on Kostya / Alioth
// =============================================================================

using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;

namespace Benchmarks
{
    public class Body
    {
        private const double DaysPerYear = 365.24;
        private const double SolarMass = 4.0 * Math.PI * Math.PI;

        public double X, Y, Z;
        public double Vx, Vy, Vz;
        public double Mass;

        public Body(double px, double py, double pz, double pvx, double pvy, double pvz, double pmass)
        {
            X = px;
            Y = py;
            Z = pz;
            Vx = pvx * DaysPerYear;
            Vy = pvy * DaysPerYear;
            Vz = pvz * DaysPerYear;
            Mass = pmass * SolarMass;
        }

        public void Advance(Body[] bodies, double dt, int i)
        {
            int nbodies = bodies.Length;
            for (int j = i + 1; j < nbodies; ++j)
            {
                Body b2 = bodies[j];
                double dx = X - b2.X;
                double dy = Y - b2.Y;
                double dz = Z - b2.Z;

                double distance = Math.Sqrt(dx * dx + dy * dy + dz * dz);
                double mag = dt / (distance * distance * distance);
                double bMassMag = Mass * mag;
                double b2MassMag = b2.Mass * mag;

                Vx -= dx * b2MassMag;
                Vy -= dy * b2MassMag;
                Vz -= dz * b2MassMag;
                b2.Vx += dx * bMassMag;
                b2.Vy += dy * bMassMag;
                b2.Vz += dz * bMassMag;
            }

            X += dt * Vx;
            Y += dt * Vy;
            Z += dt * Vz;
        }
    }

    public static class NBodyBenchmark
    {
        private const double SolarMass = 4.0 * Math.PI * Math.PI;

        public static double Energy(Body[] bodies)
        {
            double e = 0.0;
            int nbodies = bodies.Length;
            for (int i = 0; i < nbodies; ++i)
            {
                Body b = bodies[i];
                e += 0.5 * b.Mass * (b.Vx * b.Vx + b.Vy * b.Vy + b.Vz * b.Vz);
                for (int j = i + 1; j < nbodies; ++j)
                {
                    Body b2 = bodies[j];
                    double dx = b.X - b2.X;
                    double dy = b.Y - b2.Y;
                    double dz = b.Z - b2.Z;
                    double distance = Math.Sqrt(dx * dx + dy * dy + dz * dz);
                    e -= (b.Mass * b2.Mass) / distance;
                }
            }
            return e;
        }

        public static void OffsetMomentum(Body[] bodies)
        {
            double px = 0.0, py = 0.0, pz = 0.0;
            foreach (var b in bodies)
            {
                px += b.Vx * b.Mass;
                py += b.Vy * b.Mass;
                pz += b.Vz * b.Mass;
            }
            bodies[0].Vx = -px / SolarMass;
            bodies[0].Vy = -py / SolarMass;
            bodies[0].Vz = -pz / SolarMass;
        }

        public static Body[] InitBodies()
        {
            return new[]
            {
                new Body(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0),
                new Body(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01, 1.66007664274403694e-03, 7.69901118481134547e-03, -6.90460016972063023e-05, 9.54791938424326609e-04),
                new Body(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01, -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05, 2.85885980666130812e-04),
                new Body(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01, 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05, 4.36624404335156298e-05),
                new Body(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01, 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592221303114738e-05, 5.15138902046611451e-05)
            };
        }

        public static int Main(string[] args)
        {
            int n = 50000;
            if (args.Length > 0 && int.TryParse(args[0], out int parsedN))
            {
                n = parsedN;
            }

            var bodies = InitBodies();
            OffsetMomentum(bodies);

            double dt = 0.01;
            int nbodies = bodies.Length;

            Stopwatch sw = Stopwatch.StartNew();
            for (int step = 0; step < n; ++step)
            {
                for (int i = 0; i < nbodies; ++i)
                {
                    bodies[i].Advance(bodies, dt, i);
                }
            }
            sw.Stop();
            double elapsedMs = sw.Elapsed.TotalMilliseconds;
            double finalEnergy = Energy(bodies);

            string resultStr = finalEnergy.ToString("F9", CultureInfo.InvariantCulture);
            Console.WriteLine(resultStr);
            Console.WriteLine($"RESULT: {resultStr}");
            Console.WriteLine($"ELAPSED_MS: {elapsedMs:F2}");

            try
            {
                Directory.CreateDirectory("benchmarks/results");
                File.WriteAllText("benchmarks/results/nbody_csharp_timing.json",
                    $"{{\n  \"benchmark\": \"nbody\",\n  \"language\": \"csharp\",\n  \"elapsed_ms\": {elapsedMs:F2},\n  \"result\": \"{resultStr}\"\n}}\n");
            }
            catch {}

            return 0;
        }
    }
}
