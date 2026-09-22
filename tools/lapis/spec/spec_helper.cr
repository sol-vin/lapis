# tools/lapis/spec/spec_helper.cr
require "spec"
require "file_utils"
require "path"
require "../src/version"
require "../src/core/env"
require "../src/core/logger"
require "../src/core/process_runner"
require "../src/core/baked_file_system"
require "../src/core/tool_checker"
require "../src/commands/dirs"
require "../src/commands/deps"
require "../src/commands/sync"
require "../src/commands/build"
require "../src/commands/clean"
require "../src/commands/scaffold"
require "../src/commands/package"
require "../src/commands/install"

module LapisSpecHelper
  def self.repo_root : Path
    # Determine repo root from spec location
    Path.new(File.expand_path("../../..", __DIR__))
  end

  def self.lapis_bin : Path
    exe_name = "lapis" + (Lapis::Core::Env.windows? ? ".exe" : "")
    bin_path = repo_root.join("bin", exe_name)
    src_entry = repo_root.join("tools/lapis/src/lapis.cr")

    needs_recompile = !File.exists?(bin_path)
    if !needs_recompile
      bin_time = File.info(bin_path).modification_time
      needs_recompile = Dir.glob(repo_root.join("tools/lapis/src/**/*.cr").to_s.gsub('\\', '/')).any? { |f| File.info(f).modification_time > bin_time } ||
                        Dir.glob(repo_root.join("tools/lapis/*.yml").to_s.gsub('\\', '/')).any? { |f| File.info(f).modification_time > bin_time } ||
                        File.info(repo_root.join("shard.yml")).modification_time > bin_time
    end

    if needs_recompile
      FileUtils.mkdir_p(bin_path.parent)
      res = Process.run("crystal", ["build", src_entry.to_s, "-o", bin_path.to_s], chdir: repo_root.to_s)
      unless res.success?
        raise "Failed to compile #{bin_path} for testing!" unless File.exists?(bin_path)
      end
    end

    bin_path
  end

  record ExecResult,
    status : Process::Status,
    output : String,
    error : String do
    def success? : Bool
      status.success?
    end

    def exit_code : Int32
      status.exit_code
    end

    def all_output : String
      "#{output}\n#{error}"
    end
  end

  def self.run_lapis(args : Array(String), chdir : Path | String | Nil = nil, env : Process::Env = nil) : ExecResult
    bin = lapis_bin
    out_io = IO::Memory.new
    err_io = IO::Memory.new

    status = Process.run(
      bin.to_s,
      args,
      chdir: chdir ? chdir.to_s : repo_root.to_s,
      env: env,
      output: out_io,
      error: err_io
    )

    ExecResult.new(status, out_io.to_s, err_io.to_s)
  end

  def self.with_temp_dir(prefix : String = "lapis_spec", &block : Path ->)
    scratch = repo_root.join("scratch", "#{prefix}_#{Time.utc.to_unix_ms}_#{rand(10000)}")
    FileUtils.mkdir_p(scratch)
    begin
      yield scratch
    ensure
      FileUtils.rm_rf(scratch) if Dir.exists?(scratch)
    end
  end
end
