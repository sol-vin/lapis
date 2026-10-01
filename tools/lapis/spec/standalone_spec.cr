# tools/lapis/spec/standalone_spec.cr
require "./spec_helper"

describe "Lapis Standalone Executable" do
  it "functions correctly when moved to an isolated directory outside the repository" do
    LapisSpecHelper.with_temp_dir("standalone_test") do |isolated_root|
      bin_dir = isolated_root.join("installed_bin")
      work_dir = isolated_root.join("user_workspace")
      FileUtils.mkdir_p(bin_dir)
      FileUtils.mkdir_p(work_dir)

      # Copy lapis binary to isolated directory
      source_bin = LapisSpecHelper.lapis_bin
      target_bin_name = "lapis" + (Lapis::Core::Env.windows? ? ".exe" : "")
      isolated_bin = bin_dir.join(target_bin_name)
      FileUtils.cp(source_bin.to_s, isolated_bin.to_s)
      File.chmod(isolated_bin, 0o755) unless Lapis::Core::Env.windows?

      # 1. Verify --version executes cleanly in isolated environment
      out_io = IO::Memory.new
      err_io = IO::Memory.new
      status = Process.run(isolated_bin.to_s, ["--version"], chdir: work_dir.to_s, output: out_io, error: err_io)
      status.success?.should be_true
      out_io.to_s.should contain("Lapis v#{Lapis::VERSION}")

      # 2. Verify --help executes cleanly in isolated environment
      out_io.clear
      err_io.clear
      status = Process.run(isolated_bin.to_s, ["--help"], chdir: work_dir.to_s, output: out_io, error: err_io)
      status.success?.should be_true
      out_io.to_s.should contain("Lapis: Unified Crystal Engine Toolchain for Godot")

      # 3. Scaffold a new game using only embedded BakedFileSystem
      out_io.clear
      err_io.clear
      status = Process.run(
        isolated_bin.to_s,
        ["new", "game", "my_standalone_game", "--skip-godot"],
        chdir: work_dir.to_s,
        output: out_io,
        error: err_io
      )
      status.success?.should be_true

      game_dir = work_dir.join("my_standalone_game")
      Dir.exists?(game_dir).should be_true
      File.exists?(game_dir.join("project.godot")).should be_true
      File.exists?(game_dir.join("shard.yml")).should be_true
      File.exists?(game_dir.join("Makefile")).should be_true
      File.exists?(game_dir.join("src/main.cr")).should be_true
      File.exists?(game_dir.join("scenes/main.tscn")).should be_true
      File.exists?(game_dir.join("godot-version.yml")).should be_true

      # Verify customized project name inside project.godot
      godot_proj = File.read(game_dir.join("project.godot"))
      godot_proj.should contain("config/name=\"My Standalone Game\"")

      # 4. Verify lapis editor in standalone game directory resolves current project (not .../test)
      out_io.clear
      err_io.clear
      status = Process.run(
        isolated_bin.to_s,
        ["editor", "-g", "non_existent_godot_xyz"],
        chdir: game_dir.to_s,
        output: out_io,
        error: err_io
      )
      status.success?.should be_false
      err_io.to_s.should_not contain("Target project directory does not exist")
      err_io.to_s.should contain("Godot executable not found")

      # 5. Scaffold a new addon using only embedded assets
      out_io.clear
      err_io.clear
      target_addon = work_dir.join("my_standalone_addon")
      status = Process.run(
        isolated_bin.to_s,
        ["new", "addon", "my_standalone_addon", "-t", target_addon.to_s, "-a", "TestAuthor", "-d", "TestDescription"],
        chdir: work_dir.to_s,
        output: out_io,
        error: err_io
      )
      status.success?.should be_true

      Dir.exists?(target_addon).should be_true
      File.exists?(target_addon.join("my_standalone_addon.gdextension")).should be_true
      File.exists?(target_addon.join("shard.yml")).should be_true
      File.exists?(target_addon.join("src/main.cr")).should be_true
    end
  end
end
