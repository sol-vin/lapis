require "./spec_helper"

describe "Lapis Upgrade" do
  it "upgrades an existing project from remote git dependency to embedded path" do
    LapisSpecHelper.with_temp_dir("upgrade_test") do |dir|
      proj_dir = dir.join("legacy_game")
      FileUtils.mkdir_p(proj_dir.join("src"))
      FileUtils.mkdir_p(proj_dir.join("addons/crystal_integration"))

      # 1. Setup legacy project files
      File.write(proj_dir.join("project.godot"), <<-GODOT
; Engine configuration file.
config_version=5

[application]
config/name="Legacy Game"
config/features=PackedStringArray("4.8")
GODOT
      )

      File.write(proj_dir.join("shard.yml"), <<-YAML
name: legacy_game
version: 0.1.0

dependencies:
  lapis:
    github: sol-vin/lapis
    tag: 4.8-dev6

targets:
  game:
    main: src/main.cr
YAML
      )

      File.write(proj_dir.join("src/main.cr"), <<-CR
require "lapis"

node LegacyGame < Node3D do
  def _ready : Void
    Godot.print("Legacy Game ready")
  end
end
CR
      )

      # 2. Run lapis upgrade
      res = LapisSpecHelper.run_lapis(["upgrade", "-p", proj_dir.to_s])
      res.success?.should be_true

      # 3. Verify shard.yml was migrated
      shard_content = File.read(proj_dir.join("shard.yml"))
      shard_content.should contain("path: lib/lapis")
      shard_content.should_not contain("github: sol-vin/lapis")

      # 4. Verify embedded engine library was extracted
      File.exists?(proj_dir.join("lib/lapis/src/lapis.cr")).should be_true
      File.exists?(proj_dir.join("lib/lapis/src/libgodot.cr")).should be_true
      File.exists?(proj_dir.join("lib/lapis/shard.yml")).should be_true
      File.exists?(proj_dir.join("lib/lapis/.gdignore")).should be_true

      # 5. Verify addon manifests refreshed
      File.exists?(proj_dir.join("addons/crystal_integration/crystal.gdextension")).should be_true
      File.exists?(proj_dir.join("addons/crystal_integration/plugin.cfg")).should be_true
    end
  end
end
