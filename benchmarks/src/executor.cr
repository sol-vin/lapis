require "file_utils"
require "./models"

module Benchmarks
  class Executor
    def self.resolve_godot(base_dir : String? = nil) : String
      candidates = [
        "./godot.exe", "godot.exe", "../godot.exe", "../../godot.exe",
        "./godot", "godot", "../godot", "../../godot"
      ]
      if base_dir
        candidates.unshift(File.join(base_dir, "godot.exe"))
        candidates.unshift(File.join(base_dir, "../godot.exe"))
        candidates.unshift(File.join(base_dir, "godot"))
        candidates.unshift(File.join(base_dir, "../godot"))
      end
      candidates.each do |c|
        return File.expand_path(c) if File.exists?(c)
        return c if Process.find_executable(c)
      end
      ENV["GODOT_BIN"]? || ENV["GODOT"]? || "godot.exe"
    end

    def self.compile_crystal(bench : BenchmarkCase, base_dir : String, release : Bool = true) : Bool
      bin_name = Process.run("cmd", ["/c", "ver"], output: IO::Memory.new).success? ? "#{bench.crystal_bin}.exe" : bench.crystal_bin
      out_path = File.join(base_dir, bin_name)
      src_path = File.join(base_dir, bench.crystal_src)
      bin_dir = File.dirname(out_path)
      FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)

      needs_build = !File.exists?(out_path) || (File.info(src_path).modification_time > File.info(out_path).modification_time)
      return true unless needs_build

      cmd = "crystal"
      flags = ["build", src_path, "-o", out_path]
      flags << "--release" if release
      flags << "-O3" if release

      puts "  [Compile] crystal #{flags.join(" ")}"
      status = Process.run(cmd, flags)
      status.success? && File.exists?(out_path)
    end

    def self.run_process_and_extract_ms(cmd : String, args : Array(String), cwd : String) : Float64?
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run(cmd, args, chdir: cwd, output: stdout, error: stderr)
      out_str = stdout.to_s + "\n" + stderr.to_s
      if match = out_str.match(/ELAPSED_MS:\s*([0-9.]+)/)
        return match[1].to_f
      end
      nil
    end

    def self.measure(iterations : Int32, &block : -> Float64?) : Tuple(Array(Float64), Float64, Float64, Float64)
      samples = [] of Float64
      iterations.times do
        if ms = yield
          samples << ms
        end
      end

      if samples.empty?
        return { [] of Float64, 0.0, 0.0, 0.0 }
      end

      sorted = samples.sort
      median = sorted[sorted.size // 2]
      min = sorted.first
      max = sorted.last
      { samples, median, min, max }
    end

    def self.run_case(
      bench : BenchmarkCase,
      iterations : Int32,
      base_dir : String,
      godot_exe : String,
      release : Bool = true
    ) : BenchmarkResult?
      puts "\n--> Running Benchmark: \e[1;36m#{bench.name}\e[0m [#{bench.category.display_name}] (\e[2m#{bench.description}\e[0m)"

      unless compile_crystal(bench, base_dir, release: release)
        puts "  \e[31m[Error] Failed to compile #{bench.crystal_src}\e[0m"
        return nil
      end

      bin_ext = Process.run("cmd", ["/c", "ver"], output: IO::Memory.new).success? ? ".exe" : ""
      cr_bin_path = File.join(base_dir, "#{bench.crystal_bin}#{bin_ext}")

      print "  Benchmarking Crystal... "
      cr_samples, cr_median, cr_min, cr_max = measure(iterations) do
        run_process_and_extract_ms(cr_bin_path, bench.args, base_dir)
      end
      puts "\e[1;32m%6.2f ms\e[0m (median of %d)" % [cr_median, cr_samples.size]

      print "  Benchmarking GDScript... "
      gd_script_path = File.join(base_dir, bench.gdscript_src)
      gd_args = ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--script", gd_script_path, "--"] + bench.args
      gd_samples, gd_median, gd_min, gd_max = measure(iterations) do
        run_process_and_extract_ms(godot_exe, gd_args, base_dir)
      end
      speedup = (cr_median > 0) ? (gd_median / cr_median) : 1.0
      speedup_badge = speedup >= 1.0 ? "\e[1;32m%5.1fx faster\e[0m" % speedup : "\e[1;33m%5.1fx slower\e[0m" % (1.0 / speedup)
      puts "\e[1;33m%6.2f ms\e[0m (median of %d) -> %s" % [gd_median, gd_samples.size, speedup_badge]

      BenchmarkResult.new(
        benchmark: bench,
        crystal_samples: cr_samples,
        gdscript_samples: gd_samples,
        crystal_ms: cr_median,
        gdscript_ms: gd_median,
        crystal_min_ms: cr_min,
        crystal_max_ms: cr_max,
        gdscript_min_ms: gd_min,
        gdscript_max_ms: gd_max,
        speedup: speedup
      )
    end
  end
end
