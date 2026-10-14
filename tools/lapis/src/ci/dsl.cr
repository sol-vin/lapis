require "./engine"

module Lapis
  module CI
    # Declarative DSL Layer: Ergonomic builder wrapping AddonBuildConfig and ActionGenerator.
    class AddonPipelineBuilder
      @working_directory : String = "."
      @addon_name : String = ""
      @entry_point : String = ""
      @godot_version : String = "4.8-dev7"
      @crystal_version : String = "1.21.0"
      @lapis_ref : String = "4.8-dev7"
      @release : Bool = false
      @run_specs : Bool = true
      @run_headless : Bool = true
      @run_benchmarks : Bool = true
      @install_libvlc : String = "auto"
      @os_matrix : Array(String) = ["ubuntu-latest", "windows-latest", "macos-latest"]
      @extra_apt_packages : Array(String) = [] of String
      @extra_brew_packages : Array(String) = [] of String

      def working_directory(value : String) : self
        @working_directory = value
        self
      end

      def addon_name(value : String) : self
        @addon_name = value
        self
      end

      def entry(value : String) : self
        @entry_point = value
        self
      end

      def godot_version(value : String) : self
        @godot_version = value
        self
      end

      def crystal_version(value : String) : self
        @crystal_version = value
        self
      end

      def lapis_ref(value : String) : self
        @lapis_ref = value
        self
      end

      def release(value : Bool = true) : self
        @release = value
        self
      end

      def run_specs(value : Bool = true) : self
        @run_specs = value
        self
      end

      def run_headless(value : Bool = true) : self
        @run_headless = value
        self
      end

      def run_benchmarks(value : Bool = true) : self
        @run_benchmarks = value
        self
      end

      def install_libvlc(value : String | Bool) : self
        @install_libvlc = value.is_a?(Bool) ? (value ? "true" : "false") : value
        self
      end

      def platforms(*runners : String) : self
        @os_matrix = runners.to_a
        self
      end

      def platforms(runners : Array(String)) : self
        @os_matrix = runners.dup
        self
      end

      def apt_packages(*pkgs : String) : self
        @extra_apt_packages.concat(pkgs.to_a)
        self
      end

      def brew_packages(*pkgs : String) : self
        @extra_brew_packages.concat(pkgs.to_a)
        self
      end

      def build : AddonBuildConfig
        AddonBuildConfig.new(
          working_directory: @working_directory,
          addon_name: @addon_name,
          entry_point: @entry_point,
          godot_version: @godot_version,
          crystal_version: @crystal_version,
          lapis_ref: @lapis_ref,
          release: @release,
          run_specs: @run_specs,
          run_headless: @run_headless,
          run_benchmarks: @run_benchmarks,
          install_libvlc: @install_libvlc,
          os_matrix: @os_matrix,
          extra_apt_packages: @extra_apt_packages,
          extra_brew_packages: @extra_brew_packages
        )
      end

      def to_caller_yaml : String
        ActionGenerator.render_caller_workflow(build)
      end
    end

    # Declarative block DSL for constructing an AddonBuildConfig.
    def self.addon_pipeline(&block : AddonPipelineBuilder ->) : AddonBuildConfig
      builder = AddonPipelineBuilder.new
      yield builder
      builder.build
    end
  end
end
