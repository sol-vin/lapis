require "spec"
require "../tools/lapis/src/commands/shard_manager"

describe "Lapis Plugin Dependencies & DAG Resolution" do
  describe "Topological Dependency Sorting & Diamond Resolution" do
    it "resolves diamond dependency hierarchies cleanly without duplication" do
      # Structure:
      #        CoreBase
      #       /        \
      #   Combat      Inventory
      #       \        /
      #       QuestSystem
      requirements = [
        Lapis::Commands::ShardManager::AddonRequirement.new(
          name: "core_base",
          provider: :git,
          source: "github.com/lapis/core_base",
          version: ">= 1.0.0",
          requester: "root"
        ),
        Lapis::Commands::ShardManager::AddonRequirement.new(
          name: "combat",
          provider: :git,
          source: "github.com/lapis/combat",
          version: "1.2.0",
          requester: "quest_system"
        ),
        Lapis::Commands::ShardManager::AddonRequirement.new(
          name: "inventory",
          provider: :git,
          source: "github.com/lapis/inventory",
          version: "1.1.0",
          requester: "quest_system"
        ),
        Lapis::Commands::ShardManager::AddonRequirement.new(
          name: "core_base",
          provider: :git,
          source: "github.com/lapis/core_base",
          version: "~> 1.2.0",
          requester: "combat"
        ),
        Lapis::Commands::ShardManager::AddonRequirement.new(
          name: "core_base",
          provider: :git,
          source: "github.com/lapis/core_base",
          version: "~> 1.2.0",
          requester: "inventory"
        )
      ]

      ok, resolved, errors = Lapis::Commands::ShardManager::AddonNegotiator.negotiate(requirements)
      ok.should be_true
      errors.should be_empty

      resolved.has_key?("core_base").should be_true
      resolved.has_key?("combat").should be_true
      resolved.has_key?("inventory").should be_true

      core = resolved["core_base"]
      core.version.should eq("1.2.0")
      core.all_requesters.should contain("root")
      core.all_requesters.should contain("combat")
      core.all_requesters.should contain("inventory")
    end

    it "detects and rejects incompatible semantic version constraints" do
      requirements = [
        Lapis::Commands::ShardManager::AddonRequirement.new(
          name: "physics_engine",
          provider: :git,
          source: "github.com/lapis/physics",
          version: "~> 1.0.0",
          requester: "module_a"
        ),
        Lapis::Commands::ShardManager::AddonRequirement.new(
          name: "physics_engine",
          provider: :git,
          source: "github.com/lapis/physics",
          version: ">= 2.0.0",
          requester: "module_b"
        )
      ]

      ok, resolved, errors = Lapis::Commands::ShardManager::AddonNegotiator.negotiate(requirements)
      ok.should be_false
      errors.size.should be > 0
      errors.first.should contain("Version conflict for addon 'physics_engine'")
      errors.first.should contain("incompatible constraints")
    end

    it "detects and rejects conflicting provider sources" do
      requirements = [
        Lapis::Commands::ShardManager::AddonRequirement.new(
          name: "audio_fx",
          provider: :git,
          source: "github.com/lapis/audio_git",
          version: "1.0.0",
          requester: "module_a"
        ),
        Lapis::Commands::ShardManager::AddonRequirement.new(
          name: "audio_fx",
          provider: :local,
          source: "../local_audio",
          version: "1.0.0",
          requester: "module_b"
        )
      ]

      ok, resolved, errors = Lapis::Commands::ShardManager::AddonNegotiator.negotiate(requirements)
      ok.should be_false
      errors.first.should contain("conflicting provider types")
    end
  end

  describe "GDExtension Manifest Parsing & Multi-Addon Validation" do
    it "parses official crystal.gdextension manifest" do
      manifest_path = File.join(__DIR__, "..", "addons", "crystal_integration", "crystal.gdextension")
      File.exists?(manifest_path).should be_true

      content = File.read(manifest_path)
      content.should contain("[configuration]")
      content.should contain("entry_symbol = \"crystal_library_init\"")
      content.should contain("compatibility_minimum = \"4.1\"")
      content.should contain("[libraries]")
      content.should contain("windows.debug")
      content.should contain("windows.release")
      content.should contain("linux.debug")
    end

    it "validates that dummy test addons maintain isolated manifests and entrypoints" do
      dummy_addons = ["dummy_audio", "dummy_dialogue", "dummy_inventory"]
      dummy_addons.each do |addon|
        dir = File.join(__DIR__, "..", "addons", addon)
        manifest = File.join(dir, "#{addon}.gdextension")
        if File.exists?(manifest)
          content = File.read(manifest)
          content.should contain("entry_symbol")
          content.should contain("compatibility_minimum")
        end
      end
    end
  end
end
