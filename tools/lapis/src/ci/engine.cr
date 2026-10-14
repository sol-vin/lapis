require "yaml"
require "path"

module Lapis
  module CI
    # Core Engine Layer: Immutable configuration for building & testing a Lapis GDExtension addon in CI.
    struct AddonBuildConfig
      getter working_directory : String
      getter addon_name : String
      getter entry_point : String
      getter godot_version : String
      getter crystal_version : String
      getter lapis_ref : String
      getter release : Bool
      getter run_specs : Bool
      getter run_headless : Bool
      getter run_benchmarks : Bool
      getter install_libvlc : String
      getter os_matrix : Array(String)
      getter extra_apt_packages : Array(String)
      getter extra_brew_packages : Array(String)

      def initialize(
        @working_directory : String = ".",
        @addon_name : String = "",
        @entry_point : String = "",
        @godot_version : String = "4.8-dev7",
        @crystal_version : String = "1.21.0",
        @lapis_ref : String = "4.8-dev7",
        @release : Bool = false,
        @run_specs : Bool = true,
        @run_headless : Bool = true,
        @run_benchmarks : Bool = true,
        @install_libvlc : String = "auto",
        @os_matrix : Array(String) = ["ubuntu-latest", "windows-latest", "macos-latest"],
        @extra_apt_packages : Array(String) = [] of String,
        @extra_brew_packages : Array(String) = [] of String,
      )
      end

      def target_branch_valid? : Bool
        !@godot_version.empty? && @lapis_ref != "main" && @lapis_ref != "master"
      end
    end

    # Core Engine Layer: Result of auditing a .gdextension manifest file.
    struct AddonManifestAudit
      getter manifest_path : String
      getter exists : Bool
      getter has_configuration_section : Bool
      getter has_libraries_section : Bool
      getter entry_symbol : String?
      getter compatibility_minimum : String?
      getter platforms : Array(String)
      getter errors : Array(String)

      def initialize(
        @manifest_path : String,
        @exists : Bool,
        @has_configuration_section : Bool = false,
        @has_libraries_section : Bool = false,
        @entry_symbol : String? = nil,
        @compatibility_minimum : String? = nil,
        @platforms : Array(String) = [] of String,
        @errors : Array(String) = [] of String,
      )
      end

      def valid? : Bool
        @exists && @has_configuration_section && @has_libraries_section &&
          !(@entry_symbol.nil? || @entry_symbol.try(&.empty?)) && @errors.empty?
      end
    end

    # Core Engine Layer: Result of verifying an addon project directory for CI readiness.
    struct AddonVerificationReport
      getter project_dir : String
      getter addon_name : String
      getter shard_version : String
      getter godot_version : String
      getter entry_point : String
      getter manifest_audit : AddonManifestAudit
      getter errors : Array(String)

      def initialize(
        @project_dir : String,
        @addon_name : String,
        @shard_version : String,
        @godot_version : String,
        @entry_point : String,
        @manifest_audit : AddonManifestAudit,
        @errors : Array(String) = [] of String,
      )
      end

      def valid? : Bool
        !@addon_name.empty? && !@godot_version.empty? && !@entry_point.empty? &&
          @manifest_audit.valid? && @errors.empty?
      end
    end

    # Core Engine Layer: Pure deterministic verifier for Lapis GDExtension addon projects and manifests.
    module AddonVerifier
      VALID_ENTRY_SYMBOLS = [
        "crystal_library_init",
        "crystal_godot_init",
        "crystal_bridge_init",
        "lapis_gdextension_entry",
        "godot_gdextension_entry",
      ]

      def self.audit_manifest(path : Path | String) : AddonManifestAudit
        manifest_path = path.to_s
        unless File.exists?(manifest_path)
          return AddonManifestAudit.new(
            manifest_path: manifest_path,
            exists: false,
            errors: ["GDExtension manifest not found at #{manifest_path}"]
          )
        end

        content = File.read(manifest_path)
        has_config = false
        has_libs = false
        entry_sym : String? = nil
        compat_min : String? = nil
        platforms = Set(String).new
        errors = [] of String
        current_section = ""

        content.each_line do |raw_line|
          line = raw_line.strip
          next if line.empty? || line.starts_with?('#') || line.starts_with?(';')

          if line.starts_with?('[') && line.ends_with?(']')
            current_section = line[1..-2].strip.downcase
            has_config = true if current_section == "configuration"
            has_libs = true if current_section == "libraries"
            next
          end

          next unless line.includes?('=')
          parts = line.split('=', 2)
          key = parts[0].strip
          val = parts[1].strip.gsub(/^["']|["']$/, "")

          case current_section
          when "configuration"
            if key == "entry_symbol"
              entry_sym = val
            elsif key == "compatibility_minimum"
              compat_min = val
            end
          when "libraries"
            plat_prefix = key.split('.').first?.try(&.downcase)
            platforms << plat_prefix if plat_prefix && !plat_prefix.empty?
          end
        end

        errors << "Missing [configuration] section in #{manifest_path}" unless has_config
        errors << "Missing [libraries] section in #{manifest_path}" unless has_libs

        if sym = entry_sym
          unless VALID_ENTRY_SYMBOLS.includes?(sym)
            errors << "Unexpected entry_symbol '#{sym}' (expected one of: #{VALID_ENTRY_SYMBOLS.join(", ")})"
          end
        else
          errors << "Missing entry_symbol in [configuration]"
        end

        %w[windows linux macos].each do |required_plat|
          unless platforms.includes?(required_plat)
            errors << "Missing '#{required_plat}' library target in [libraries]"
          end
        end

        AddonManifestAudit.new(
          manifest_path: manifest_path,
          exists: true,
          has_configuration_section: has_config,
          has_libraries_section: has_libs,
          entry_symbol: entry_sym,
          compatibility_minimum: compat_min,
          platforms: platforms.to_a.sort,
          errors: errors
        )
      end

      def self.resolve_godot_version(project_dir : Path, fallback : String = "4.8-dev7") : String
        candidates = [
          project_dir.join("godot-version.yml"),
          project_dir.parent.join("godot-version.yml"),
        ]
        candidates.each do |cand|
          next unless File.exists?(cand)
          if parsed = (YAML.parse(File.read(cand)) rescue nil)
            if ver = parsed["version"]?.try(&.as_s?)
              cleaned = ver.strip
              return cleaned unless cleaned.empty?
            end
          end
        end
        fallback
      end

      def self.verify_project(project_dir : Path | String, explicit_addon_name : String = "") : AddonVerificationReport
        dir = Path.new(project_dir.to_s)
        errors = [] of String

        shard_path = dir.join("shard.yml")
        addon_name = explicit_addon_name.strip
        shard_version = "0.1.0"

        if File.exists?(shard_path)
          if parsed = (YAML.parse(File.read(shard_path)) rescue nil)
            if addon_name.empty?
              addon_name = parsed["name"]?.try(&.as_s?) || ""
            end
            shard_version = parsed["version"]?.try(&.as_s?) || "0.1.0"
          else
            errors << "Failed to parse #{shard_path}"
          end
        else
          errors << "Missing shard.yml in #{dir}"
        end

        if addon_name.empty?
          manifests = Dir.glob(dir.join("addons/*/*.gdextension").to_s.gsub('\\', '/'))
          if first = manifests.first?
            addon_name = File.basename(File.dirname(first))
          end
        end

        godot_ver = resolve_godot_version(dir)

        entry_candidates = [
          dir.join("src", "main.cr"),
          dir.join("src", addon_name, "#{addon_name}.cr"),
          dir.join("src", "#{addon_name}.cr"),
        ]
        resolved_entry = ""
        entry_candidates.each do |cand|
          if File.exists?(cand)
            resolved_entry = cand.relative_to(dir).to_s.gsub('\\', '/')
            break
          end
        end
        errors << "No Crystal entry point found in #{dir}/src" if resolved_entry.empty?

        manifest_candidate = dir.join("addons", addon_name, "#{addon_name}.gdextension")
        unless File.exists?(manifest_candidate)
          globbed = Dir.glob(dir.join("addons/**/*.gdextension").to_s.gsub('\\', '/')).reject(&.includes?("crystal_integration"))
          if first_glob = globbed.first?
            manifest_candidate = Path.new(first_glob)
          end
        end

        audit = audit_manifest(manifest_candidate)
        errors.concat(audit.errors)

        AddonVerificationReport.new(
          project_dir: dir.to_s,
          addon_name: addon_name,
          shard_version: shard_version,
          godot_version: godot_ver,
          entry_point: resolved_entry,
          manifest_audit: audit,
          errors: errors
        )
      end
    end

    # Core Engine Layer: Deterministic generator and validator for Lapis CI caller workflows.
    module ActionGenerator
      # Renders the canonical 5-line caller job YAML for downstream addons (diorite, emerald, crshader).
      def self.render_caller_workflow(config : AddonBuildConfig) : String
        String.build do |io|
          io << "name: Addon CI\n\n"
          io << "on:\n"
          io << "  push:\n"
          io << "    branches: [main, master]\n"
          io << "  pull_request:\n"
          io << "    branches: [main, master]\n"
          io << "  workflow_dispatch:\n\n"
          io << "jobs:\n"
          io << "  lapis-addon-ci:\n"
          io << "    uses: sol-vin/lapis/.github/workflows/reusable-lapis-ci.yml@#{config.lapis_ref}\n"
          has_with = !config.addon_name.empty? || config.working_directory != "." ||
                     config.install_libvlc != "auto" || !config.extra_apt_packages.empty?
          if has_with
            io << "    with:\n"
            io << "      addon-name: #{config.addon_name}\n" unless config.addon_name.empty?
            io << "      working-directory: #{config.working_directory}\n" if config.working_directory != "."
            io << "      install-libvlc: #{config.install_libvlc}\n" if config.install_libvlc != "auto"
            unless config.extra_apt_packages.empty?
              io << "      extra-apt-packages: #{config.extra_apt_packages.join(" ")}\n"
            end
          end
        end
      end
    end
  end
end
