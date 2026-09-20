require "../core/env"
require "../core/logger"
require "file_utils"

module Lapis
  module Commands
    module Dirs
      def self.run(args : Array(String)) : Int32
        root = Core::Env::ROOT_DIR
        target_dirs = Core::Env.collect_target_bin_dirs(root)

        if Core::Env.is_libgodot_repo?(root)
          # Standard root dirs for monorepo
          target_dirs << root.join("bin")
          target_dirs << root.join("addons/crystal_integration/bin")
          target_dirs << root.join("test/bin")
          target_dirs << root.join("template/bin")
          target_dirs << root.join("template-addon/addons/crystal_addon/bin")
          target_dirs << root.join("performance/bin")
          target_dirs << root.join("performance/addons/crystal_integration/bin")
        elsif Core::Env.is_standalone_project?(root)
          target_dirs << root.join("bin")
        end

        created = 0
        target_dirs.uniq.each do |dir|
          unless Dir.exists?(dir)
            FileUtils.mkdir_p(dir)
            Core::Logger.debug("Created directory: #{dir}")
            created += 1
          end
        end

        # Ensure src/bridge/godot_version.h matches godot-version.yml
        bridge_dir = root.join("src/bridge")
        if Dir.exists?(bridge_dir)
          ver_file = root.join("godot-version.yml")
          target_ver = "4.8-dev6"
          if File.exists?(ver_file) && (content = File.read(ver_file)) =~ /version:\s*["']?([^"'\r\n]+)["']?/
            target_ver = $1.strip
          end
          hdr = bridge_dir.join("godot_version.h")
          hdr_content = <<-H
// Auto-generated target Godot version for C++ GDExtension loader bridge
#pragma once

#ifndef LIBGODOT_TARGET_VERSION
#define LIBGODOT_TARGET_VERSION "#{target_ver}"
#endif

H
          if !File.exists?(hdr) || File.read(hdr) != hdr_content
            File.write(hdr, hdr_content)
            Core::Logger.debug("Updated #{hdr} to #{target_ver}")
          end
        end

        Core::Logger.step("Dirs", "Ensured all output directories exist (#{created} created)")
        0
      end
    end
  end
end
