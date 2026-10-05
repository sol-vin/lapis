require "file_utils"
require "json"
require "./models"
require "../../core/env"
require "../../core/logger"
require "../../core/process_runner"

module Lapis
  module Commands
    module Benchmarks
      module Executor
        def self.compile_crystal(bench : BenchmarkCase, base_dir : Path, release : Bool = true) : Bool
          bin_name = Core::Env.windows? ? "#{bench.crystal_bin}.exe" : bench.crystal_bin
          out_path = base_dir.join(bin_name)
          src_path = base_dir.join(bench.crystal_src)
          bin_dir = out_path.parent
          FileUtils.mkdir_p(bin_dir) unless Dir.exists?(bin_dir)

          needs_build = !File.exists?(out_path) || (File.info(src_path).modification_time > File.info(out_path).modification_time)
          return true unless needs_build

          cmd = "crystal"
          flags = ["build", src_path.to_s, "-o", out_path.to_s]
          if release
            flags << "--release"
            flags << "-O3"
          end

          root_dir = Core::Env.find_root
          Core::Logger.trace("Benchmark", "crystal #{flags.join(" ")}")
          res = Core::ProcessRunner.run(cmd, flags, chdir: root_dir.to_s)
          res.success? && File.exists?(out_path)
        end

        def self.compile_cpp(cpp_src : String, base_dir : Path, release : Bool = true) : Tuple(Bool, Path?)
          compiler = Process.find_executable("g++") || Process.find_executable("clang++") || Process.find_executable("cl")
          return {false, nil} unless compiler

          src_path = base_dir.join(cpp_src)
          return {false, nil} unless File.exists?(src_path)

          base_name = File.basename(cpp_src, ".cpp")
          bin_name = Core::Env.windows? ? "#{base_name}_cpp.exe" : "#{base_name}_cpp"
          out_bin = base_dir.join("bin", bin_name)
          FileUtils.mkdir_p(out_bin.parent) unless Dir.exists?(out_bin.parent)

          if File.exists?(out_bin) && (File.info(out_bin).modification_time >= File.info(src_path).modification_time)
            return {true, out_bin}
          end

          flags = if compiler.ends_with?("cl.exe") || compiler.ends_with?("cl")
                    [src_path.to_s, "/std:c++17", release ? "/O2" : "/Od", "/Fe:#{out_bin}"]
                  else
                    f = ["-std=c++17", src_path.to_s, "-o", out_bin.to_s]
                    f.unshift(release ? "-O3" : "-g")
                    f
                  end

          res = Core::ProcessRunner.run(compiler, flags, chdir: base_dir.to_s)
          {res.success? && File.exists?(out_bin), out_bin}
        end

        def self.compile_csharp(cs_src : String, base_dir : Path, release : Bool = true) : Tuple(Bool, Path?)
          return {false, nil} unless Process.find_executable("dotnet")

          target_path = base_dir.join(cs_src)
          return {false, nil} unless File.exists?(target_path)

          # Find or resolve .csproj
          proj_path = if target_path.to_s.ends_with?(".csproj")
                        target_path
                      else
                        sibling_proj = Dir.glob(target_path.parent.join("*.csproj").to_s.gsub('\\', '/')).first?
                        if sibling_proj
                          Path.new(sibling_proj)
                        else
                          # Generate minimal csproj
                          gen_proj = target_path.parent.join("#{File.basename(cs_src, ".cs")}.csproj")
                          File.write(gen_proj, <<-XML
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <Optimize>true</Optimize>
  </PropertyGroup>
</Project>
XML
                          )
                          gen_proj
                        end
                      end

          config = release ? "Release" : "Debug"
          proj_dir = proj_path.parent
          stem = File.basename(proj_path.to_s, ".csproj")
          bin_name = Core::Env.windows? ? "#{stem}.exe" : stem

          # Expected location under bin/<config>/net8.0/
          out_bin = proj_dir.join("bin", config, "net8.0", bin_name)

          flags = ["build", proj_path.to_s, "-c", config, "-v", "q", "--nologo"]
          res = Core::ProcessRunner.run("dotnet", flags, chdir: base_dir.to_s)

          if !File.exists?(out_bin)
            # Search recursively under proj_dir/bin for the binary
            candidates = Dir.glob(proj_dir.join("bin", "**", bin_name).to_s.gsub('\\', '/'))
            out_bin = Path.new(candidates.first) if candidates.first?
          end

          {res.success? && File.exists?(out_bin), out_bin}
        end

        def self.compile_rust(rs_src : String, base_dir : Path, release : Bool = true) : Tuple(Bool, Path?)
          return {false, nil} unless Process.find_executable("rustc")

          src_path = base_dir.join(rs_src)
          return {false, nil} unless File.exists?(src_path)

          base_name = File.basename(rs_src, ".rs")
          bin_name = Core::Env.windows? ? "#{base_name}_rs.exe" : "#{base_name}_rs"
          out_bin = base_dir.join("bin", bin_name)
          FileUtils.mkdir_p(out_bin.parent) unless Dir.exists?(out_bin.parent)

          if File.exists?(out_bin) && (File.info(out_bin).modification_time >= File.info(src_path).modification_time)
            return {true, out_bin}
          end

          flags = [src_path.to_s, "-o", out_bin.to_s]
          flags.unshift("-O") if release
          res = Core::ProcessRunner.run("rustc", flags, chdir: base_dir.to_s)
          {res.success? && File.exists?(out_bin), out_bin}
        end

        record ProcessRunResult,
          elapsed_ms : Float64,
          custom_time_specified : Bool,
          custom_metrics : Hash(String, Float64),
          result_value : String?,
          output : String

        def self.run_process_and_extract(
          cmd : String,
          args : Array(String),
          cwd : Path,
          case_name : String? = nil,
          lang : String? = nil
        ) : ProcessRunResult?
          stdout = IO::Memory.new
          stderr = IO::Memory.new
          start = ::Time.instant
          status = Process.run(cmd, args, chdir: cwd.to_s, output: stdout, error: stderr)
          wall_ms = (::Time.instant - start).total_milliseconds
          out_str = "#{stdout.to_s}\n#{stderr.to_s}"

          metrics = Hash(String, Float64).new
          out_str.scan(/METRIC:\s*([a-zA-Z0-9_\-]+)=([0-9.]+)/) do |m|
            metrics[m[1]] = m[2].to_f? || 0.0
          end

          custom_ms : Float64? = nil
          if match = out_str.match(/(?:ELAPSED_MS|TIME_MS|DURATION_MS|EXEC_MS):\s*([0-9.]+)/i)
            custom_ms = match[1].to_f?
          end

          result_val : String? = nil
          if match = out_str.match(/(?:RESULT|checksum|output|answer):\s*([^\r\n]+)/i)
            result_val = match[1].strip
          end

          # Check optional JSON timing artifact in benchmarks/results/ or results/
          if case_name && lang
            json_candidates = [
              cwd.join("results", "#{case_name.downcase}_#{lang.downcase}_timing.json"),
              cwd.join("benchmarks", "results", "#{case_name.downcase}_#{lang.downcase}_timing.json"),
              cwd.join("results", "#{lang.downcase}_timing.json")
            ]
            json_candidates.each do |candidate|
              if File.exists?(candidate)
                begin
                  json_data = JSON.parse(File.read(candidate))
                  if em = json_data["elapsed_ms"]?
                    custom_ms = em.as_f? || em.as_s?.try(&.to_f?)
                  end
                  if rv = json_data["result"]?
                    result_val = rv.as_s? || rv.to_s
                  end
                rescue
                end
                break if custom_ms
              end
            end
          end

          final_ms = custom_ms || wall_ms
          ProcessRunResult.new(
            elapsed_ms: final_ms,
            custom_time_specified: !custom_ms.nil?,
            custom_metrics: metrics,
            result_value: result_val,
            output: out_str
          )
        end

        def self.run_process_and_extract_ms(
          cmd : String,
          args : Array(String),
          cwd : Path,
          case_name : String? = nil,
          lang : String? = nil
        ) : Float64?
          run_process_and_extract(cmd, args, cwd, case_name, lang).try(&.elapsed_ms)
        end

        def self.measure(iterations : Int32, &block : -> Float64?) : Tuple(Array(Float64), Float64, Float64, Float64)
          samples = [] of Float64
          iterations.times do
            if ms = yield
              samples << ms
            end
          end

          return { [] of Float64, 0.0, 0.0, 0.0 } if samples.empty?

          sorted = samples.sort
          median = sorted[sorted.size // 2]
          { samples, median, sorted.first, sorted.last }
        end

        def self.run_case(
          bench : BenchmarkCase,
          iterations : Int32,
          base_dir : Path,
          godot_exe : String?,
          release : Bool = true,
          env_mode : String = "standalone",
          run_foreign_languages : Bool = false,
          is_ci : Bool = false,
          enabled_languages : Set(String)? = nil,
          on_log : Proc(String, Nil)? = nil
        ) : BenchmarkResult?
          log_line = ->(msg : String) {
            on_log ? on_log.call(msg) : puts(msg)
          }

          log_line.call("\n--> Running Benchmark: \e[1;36m#{bench.name}\e[0m [#{bench.category.display_name}] (\e[2m#{bench.description}\e[0m)")

          unless compile_crystal(bench, base_dir, release: release)
            Core::Logger.error("Failed to compile #{bench.crystal_src}")
            return nil
          end

          cr_bin = base_dir.join(Core::Env.windows? ? "#{bench.crystal_bin}.exe" : bench.crystal_bin)
          accumulated_metrics = Hash(String, Float64).new
          cr_result_value : String? = nil

          cr_samples, cr_median, cr_min, cr_max = measure(iterations) do
            if run_res = run_process_and_extract(cr_bin.to_s, bench.args, base_dir, bench.name, "crystal")
              run_res.custom_metrics.each { |k, v| accumulated_metrics[k] = v }
              cr_result_value ||= run_res.result_value
              run_res.elapsed_ms
            else
              nil
            end
          end
          log_line.call("  Benchmarking Crystal... \e[1;32m%6.2f ms\e[0m (median of %d)" % [cr_median, cr_samples.size])

          gd_samples = [] of Float64
          gd_median = 0.0
          gd_min = 0.0
          gd_max = 0.0
          gd_result_value : String? = nil

          if godot_exe && !bench.gdscript_src.empty? && File.exists?(base_dir.join(bench.gdscript_src))
            gd_args = ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--script", bench.gdscript_src, "--"] + bench.args
            gd_samples, gd_median, gd_min, gd_max = measure(iterations) do
              if run_res = run_process_and_extract(godot_exe, gd_args, base_dir, bench.name, "gdscript")
                run_res.custom_metrics.each { |k, v| accumulated_metrics[k] = v }
                gd_result_value ||= run_res.result_value
                run_res.elapsed_ms
              else
                nil
              end
            end
            speedup = (cr_median > 0 && gd_median > 0) ? (gd_median / cr_median) : 1.0
            speedup_badge = speedup >= 1.0 ? "\e[1;32m%5.1fx faster\e[0m" % speedup : "\e[1;33m%5.1fx slower\e[0m" % (1.0 / speedup)
            log_line.call("  Benchmarking GDScript... \e[1;33m%6.2f ms\e[0m (median of %d) -> %s" % [gd_median, gd_samples.size, speedup_badge])
          end

          speedup = (cr_median > 0 && gd_median > 0) ? (gd_median / cr_median) : 1.0

          # Foreign language execution gating
          should_run_foreign = (run_foreign_languages || is_ci)
          should_run_lang = ->(lang : String) {
            if langs = enabled_languages
              langs.includes?(lang.downcase)
            else
              should_run_foreign
            end
          }

          # Multi-Language Benchmarks (C++, C#, Rust)
          cpp_median : Float64? = nil
          if (cpp_src = bench.cpp_src) && should_run_lang.call("cpp")
            ok, cpp_bin = compile_cpp(cpp_src, base_dir, release)
            if ok && cpp_bin && File.exists?(cpp_bin)
              cpp_res_val : String? = nil
              _samples, c_med, _min, _max = measure(iterations) do
                if run_res = run_process_and_extract(cpp_bin.to_s, bench.args, base_dir, bench.name, "cpp")
                  cpp_res_val ||= run_res.result_value
                  run_res.elapsed_ms
                else
                  nil
                end
              end
              cpp_median = c_med
              c_speedup = (cr_median > 0 && c_med > 0) ? (cr_median / c_med) : 1.0
              c_badge = c_speedup >= 1.0 ? "\e[1;34m%5.2fx faster than Crystal\e[0m" % c_speedup : "\e[1;33m%5.2fx vs Crystal\e[0m" % c_speedup
              log_line.call("  Benchmarking C++...     \e[1;34m%6.2f ms\e[0m (median of %d) -> %s" % [c_med, _samples.size, c_badge])
            end
          end

          cs_median : Float64? = nil
          if (cs_src = bench.csharp_src) && (should_run_lang.call("csharp") || should_run_lang.call("c#"))
            ok, cs_bin = compile_csharp(cs_src, base_dir, release)
            if ok && cs_bin && File.exists?(cs_bin)
              cs_res_val : String? = nil
              _samples, cs_med, _min, _max = measure(iterations) do
                if run_res = run_process_and_extract(cs_bin.to_s, bench.args, base_dir, bench.name, "csharp")
                  cs_res_val ||= run_res.result_value
                  run_res.elapsed_ms
                else
                  nil
                end
              end
              cs_median = cs_med
              cs_speedup = (cr_median > 0 && cs_med > 0) ? (cr_median / cs_med) : 1.0
              cs_badge = cs_speedup >= 1.0 ? "\e[1;35m%5.2fx faster than Crystal\e[0m" % cs_speedup : "\e[1;33m%5.2fx vs Crystal\e[0m" % cs_speedup
              log_line.call("  Benchmarking C#...      \e[1;35m%6.2f ms\e[0m (median of %d) -> %s" % [cs_med, _samples.size, cs_badge])
            end
          end

          rs_median : Float64? = nil
          if (rs_src = bench.rust_src) && should_run_lang.call("rust")
            ok, rs_bin = compile_rust(rs_src, base_dir, release)
            if ok && rs_bin && File.exists?(rs_bin)
              rs_res_val : String? = nil
              _samples, rs_med, _min, _max = measure(iterations) do
                if run_res = run_process_and_extract(rs_bin.to_s, bench.args, base_dir, bench.name, "rust")
                  rs_res_val ||= run_res.result_value
                  run_res.elapsed_ms
                else
                  nil
                end
              end
              rs_median = rs_med
              rs_speedup = (cr_median > 0 && rs_med > 0) ? (cr_median / rs_med) : 1.0
              rs_badge = rs_speedup >= 1.0 ? "\e[38;5;208m%5.2fx faster than Crystal\e[0m" % rs_speedup : "\e[1;33m%5.2fx vs Crystal\e[0m" % rs_speedup
              log_line.call("  Benchmarking Rust...    \e[38;5;208m%6.2f ms\e[0m (median of %d) -> %s" % [rs_med, _samples.size, rs_badge])
            end
          end

          ed_samples = [] of Float64
          ed_median = 0.0
          ed_overhead_ratio : Float64? = nil

          if (env_mode == "all" || env_mode == "editor") && godot_exe && !bench.gdscript_src.empty?
            ed_args = ["--headless", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--editor", "--path", base_dir.to_s, "--script", bench.gdscript_src, "--"] + bench.args
            ed_samples, ed_median, _ed_min, _ed_max = measure(iterations) do
              run_process_and_extract_ms(godot_exe, ed_args, base_dir, bench.name, "editor")
            end
            if ed_median > 0 && gd_median > 0
              ed_overhead_ratio = ed_median / gd_median
              overhead_pct = ((ed_median - gd_median) / gd_median) * 100.0
              badge = overhead_pct >= 0 ? "+%.1f%% editor overhead" % overhead_pct : "%.1f%% editor speedup" % overhead_pct
              log_line.call("  Benchmarking In-Editor... \e[1;35m%6.2f ms\e[0m (median of %d) -> %s" % [ed_median, ed_samples.size, badge])
            end
          end

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
            speedup: speedup,
            editor_samples: ed_samples,
            editor_ms: (ed_median > 0 ? ed_median : nil),
            editor_overhead_ratio: ed_overhead_ratio,
            cpp_ms: cpp_median,
            csharp_ms: cs_median,
            rust_ms: rs_median,
            group_name: bench.group_name,
            custom_metrics: accumulated_metrics
          )
        end
      end
    end
  end
end
