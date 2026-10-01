# =============================================================================
# LibGodot - Homogeneous In-Engine Benchmarks Framework
# =============================================================================
# Provides a high-performance benchmarking DSL that can execute both inside
# the Godot editor, in standalone test runners, or be completely eliminated
# at compile time for production release builds (Steam / Itch) via -Dno_benchmarks.

module Lapis
  module Benchmark
    {% unless flag?(:no_benchmarks) %}
      enum Category
        Compute
        Engine
        Toolchain
        Custom

        def display_name : String
          case self
          in Compute   then "Compute"
          in Engine    then "Engine"
          in Toolchain then "Toolchain"
          in Custom    then "Custom"
          end
        end

        def self.parse(val : Category | Symbol | String) : Category
          case val
          when Category
            val
          when Symbol, String
            case val.to_s.downcase
            when "compute", "comp"
              Compute
            when "engine", "enginecore", "engine_core", "core"
              Engine
            when "toolchain", "tools", "compiler", "compilation"
              Toolchain
            else
              Custom
            end
          else
            Custom
          end
        end
      end

      # Execution context passed to lifecycle hooks
      struct Context
        property is_ci : Bool
        property enabled_features : Set(Symbol)
        property base_dir : Path
        property iterations : Int32
        property metadata : Hash(String, String)

        def initialize(
          @is_ci : Bool = false,
          @enabled_features : Set(Symbol) = Set(Symbol).new,
          @base_dir : Path = Path.new("."),
          @iterations : Int32 = 3,
          @metadata : Hash(String, String) = Hash(String, String).new
        )
        end
      end

      # Target specification within a comparison group
      class TargetSpec
        property name : String
        property file : String
        property language : Symbol
        property command : String?
        property flags : Array(String)
        property description : String
        property feature : Symbol?
        property ci_only : Bool
        property subgroup : String?
        property args : Array(String)
        property block : Proc(Int32, Nil)?

        def initialize(
          @name : String,
          @file : String = "",
          @language : Symbol = :crystal,
          @command : String? = nil,
          @flags : Array(String) = [] of String,
          @description : String = "",
          @feature : Symbol? = nil,
          @ci_only : Bool = false,
          @subgroup : String? = nil,
          @args : Array(String) = [] of String,
          @block : Proc(Int32, Nil)? = nil
        )
        end

        # Determines if this target is active given the current execution context
        def active?(enabled_features : Set(Symbol), is_ci : Bool) : Bool
          return false if @ci_only && !is_ci
          return true if @feature.nil?

          feat = @feature.not_nil!
          if feat == :foreign_languages
            is_ci || enabled_features.includes?(:foreign_languages)
          else
            enabled_features.includes?(feat)
          end
        end
      end

      # A Comparison Group bundling multiple targets / benchmarks to compare side by side
      class Group
        property name : String
        property category : Category
        property description : String
        property baseline_name : String?
        property kind : Symbol = :runtime
        property chart_types : Array(Symbol)
        property targets : Array(TargetSpec)

        def initialize(
          @name : String,
          @category : Category = Category::Custom,
          @description : String = "",
          @baseline_name : String? = nil,
          @kind : Symbol = :runtime,
          chart_types : Array(Symbol)? = nil
        )
          @targets = [] of TargetSpec
          @chart_types = chart_types || default_chart_types_for(@kind)
        end

        def default_chart_types_for(k : Symbol) : Array(Symbol)
          case k
          when :compile_time
            [:release, :debug, :size]
          when :throughput
            [:throughput, :bar, :speedup]
          else
            [:bar, :speedup, :ratio, :log]
          end
        end

        def charts(types : Array(Symbol)) : Void
          @chart_types = types
        end

        def charts(*types : Symbol) : Void
          @chart_types = types.to_a
        end

        def chart_type(t : Symbol) : Void
          @chart_types = [t]
        end

        def description(desc : String) : Void
          @description = desc
        end

        def category(cat : Category | Symbol | String) : Void
          @category = Category.parse(cat)
        end

        def kind(k : Symbol) : Void
          @kind = k
          @chart_types = default_chart_types_for(k) if @chart_types == default_chart_types_for(:runtime)
        end

        def baseline(name : String) : Void
          @baseline_name = name
        end

        # Helper builder yielding a subgroup context for organizing targets
        class SubgroupBuilder
          def initialize(@group : Group, @subgroup_name : String)
          end

          def target(
            name : String,
            file : String,
            language : Symbol = :crystal,
            command : String? = nil,
            release_flags : Array(String)? = nil,
            description : String = "",
            feature : Symbol? = nil,
            ci_only : Bool = false,
            args : Array(String)? = nil
          ) : TargetSpec
            @group.target(
              name: name,
              file: file,
              language: language,
              command: command,
              release_flags: release_flags,
              description: description,
              feature: feature,
              ci_only: ci_only,
              subgroup: @subgroup_name,
              args: args
            )
          end

          def target(name : String, description : String = "", feature : Symbol? = nil, ci_only : Bool = false, &block : Int32 -> Nil) : TargetSpec
            @group.target(name, description: description, feature: feature, ci_only: ci_only, subgroup: @subgroup_name, &block)
          end

          def benchmark(name : String, description : String = "", feature : Symbol? = nil, ci_only : Bool = false, &block : Int32 -> Nil) : TargetSpec
            @group.benchmark(name, description: description, feature: feature, ci_only: ci_only, subgroup: @subgroup_name, &block)
          end
        end

        # Declares a logical subgroup within this comparison group
        def subgroup(name : String, &) : Nil
          builder = SubgroupBuilder.new(self, name)
          yield builder
        end

        # Register an in-engine Crystal benchmark block inside this group
        def benchmark(
          name : String,
          description : String = "",
          feature : Symbol? = nil,
          ci_only : Bool = false,
          subgroup : String? = nil,
          &block : Int32 -> Nil
        ) : TargetSpec
          target = TargetSpec.new(
            name: name,
            file: "",
            language: :crystal,
            description: description,
            feature: feature,
            ci_only: ci_only,
            subgroup: subgroup,
            block: block
          )
          @targets << target
          @baseline_name ||= name
          target
        end

        # Register a target with an in-process block
        def target(
          name : String,
          description : String = "",
          feature : Symbol? = nil,
          ci_only : Bool = false,
          subgroup : String? = nil,
          &block : Int32 -> Nil
        ) : TargetSpec
          benchmark(name, description: description, feature: feature, ci_only: ci_only, subgroup: subgroup, &block)
        end

        # Register an external file / multi-language target inside this group
        def target(
          name : String,
          file : String,
          language : Symbol = :crystal,
          command : String? = nil,
          release_flags : Array(String)? = nil,
          description : String = "",
          feature : Symbol? = nil,
          ci_only : Bool = false,
          subgroup : String? = nil,
          args : Array(String)? = nil
        ) : TargetSpec
          target = TargetSpec.new(
            name: name,
            file: file,
            language: language,
            command: command,
            flags: release_flags || [] of String,
            description: description,
            feature: feature,
            ci_only: ci_only,
            subgroup: subgroup,
            args: args || [] of String
          )
          @targets << target
          @baseline_name ||= name
          target
        end
      end

      record Case,
        name : String,
        category : Category,
        description : String,
        block : Proc(Int32, Nil)

      record TargetResult,
        name : String,
        language : Symbol,
        samples_ms : Array(Float64),
        median_ms : Float64,
        min_ms : Float64,
        max_ms : Float64,
        speedup_vs_baseline : Float64,
        custom_metrics : Hash(String, Float64),
        output_result : String? = nil,
        status : Symbol = :passed,
        skip_reason : String? = nil,
        subgroup : String? = nil

      record GroupResult,
        group_name : String,
        category : Category,
        description : String,
        baseline_name : String,
        targets : Array(TargetResult),
        kind : Symbol = :runtime,
        chart_types : Array(Symbol) = [:bar, :speedup, :ratio, :log]

      record Result,
        name : String,
        category : Category,
        iterations : Int32,
        samples_ms : Array(Float64),
        median_ms : Float64,
        min_ms : Float64,
        max_ms : Float64,
        custom_metrics : Hash(String, Float64) = Hash(String, Float64).new,
        output_result : String? = nil

      struct Summary
        property total_cases : Int32
        property total_groups : Int32
        property total_duration_ms : Float64
        property results : Array(Result)
        property group_results : Array(GroupResult)

        def initialize(
          @total_cases : Int32 = 0,
          @total_groups : Int32 = 0,
          @total_duration_ms : Float64 = 0.0,
          @results : Array(Result) = [] of Result,
          @group_results : Array(GroupResult) = [] of GroupResult
        )
        end
      end

      @@cases = [] of Case
      @@groups = [] of Group
      @@current_elapsed_ms : Float64? = nil
      @@current_output : String? = nil
      @@current_metrics = Hash(String, Float64).new

      # Lifecycle hook registrations
      @@before_suite_hooks = [] of Proc(Context, Nil)
      @@after_suite_hooks = [] of Proc(Summary, Context, Nil)
      @@before_case_hooks = [] of Proc(Case, Context, Nil)
      @@after_case_hooks = [] of Proc(Case, Result, Context, Nil)
      @@before_group_hooks = [] of Proc(Group, Context, Nil)
      @@after_group_hooks = [] of Proc(Group, GroupResult, Context, Nil)

      # Register lifecycle hooks
      def self.before_suite(&block : Context -> Nil)
        @@before_suite_hooks << block
      end

      def self.after_suite(&block : (Summary, Context) -> Nil)
        @@after_suite_hooks << block
      end

      def self.before_case(&block : (Case, Context) -> Nil)
        @@before_case_hooks << block
      end

      def self.after_case(&block : (Case, Result, Context) -> Nil)
        @@after_case_hooks << block
      end

      def self.before_group(&block : (Group, Context) -> Nil)
        @@before_group_hooks << block
      end

      def self.after_group(&block : (Group, GroupResult, Context) -> Nil)
        @@after_group_hooks << block
      end

      # Trigger lifecycle hooks
      def self.trigger_before_suite(ctx : Context) : Nil
        @@before_suite_hooks.each { |h| h.call(ctx) }
      end

      def self.trigger_after_suite(sum : Summary, ctx : Context) : Nil
        @@after_suite_hooks.each { |h| h.call(sum, ctx) }
      end

      def self.trigger_before_case(c : Case, ctx : Context) : Nil
        @@before_case_hooks.each { |h| h.call(c, ctx) }
      end

      def self.trigger_after_case(c : Case, r : Result, ctx : Context) : Nil
        @@after_case_hooks.each { |h| h.call(c, r, ctx) }
      end

      def self.trigger_before_group(g : Group, ctx : Context) : Nil
        @@before_group_hooks.each { |h| h.call(g, ctx) }
      end

      def self.trigger_after_group(g : Group, gr : GroupResult, ctx : Context) : Nil
        @@after_group_hooks.each { |h| h.call(g, gr, ctx) }
      end

      # Allows a benchmark to specify its own accurate elapsed time
      def self.report_elapsed_ms(ms : Float64) : Nil
        @@current_elapsed_ms = ms
      end

      # Allows a benchmark to specify its output result / checksum for parity verification
      def self.report_output(val : String) : Nil
        @@current_output = val
      end

      # Allows a benchmark to report secondary custom metrics (compile time, memory, throughput)
      def self.report_metric(key : String, value : Float64) : Nil
        @@current_metrics[key] = value
      end

      # Register a single benchmark case in Crystal
      def self.register(
        name : String,
        category : Category = Category::Custom,
        description : String = "",
        &block : Int32 -> Nil
      ) : Case
        c = Case.new(name, category, description, block)
        @@cases << c
        c
      end

      # Define a comparison group containing multiple benchmarks or language targets
      def self.group(
        name : String,
        category : Category = Category::Custom,
        description : String = "",
        &block : Group -> Nil
      ) : Group
        g = Group.new(name, category, description)
        yield g
        @@groups << g
        g
      end

      def self.all : Array(Case)
        @@cases
      end

      def self.all_groups : Array(Group)
        @@groups
      end

      def self.find_group(name : String) : Group?
        target = name.downcase
        @@groups.find { |g| g.name.downcase == target }
      end

      def self.clear : Nil
        @@cases.clear
        @@groups.clear
        @@current_elapsed_ms = nil
        @@current_output = nil
        @@current_metrics.clear
        @@before_suite_hooks.clear
        @@after_suite_hooks.clear
        @@before_case_hooks.clear
        @@after_case_hooks.clear
        @@before_group_hooks.clear
        @@after_group_hooks.clear
      end

      # Measure a single benchmark case across N iterations
      def self.run_case(c : Case, iterations : Int32 = 3) : Result
        samples = [] of Float64
        metrics_acc = Hash(String, Float64).new
        last_out : String? = nil
        iterations.times do |iter|
          @@current_elapsed_ms = nil
          @@current_output = nil
          @@current_metrics.clear
          start = ::Time.instant
          c.block.call(iter)
          elapsed = @@current_elapsed_ms || (::Time.instant - start).total_milliseconds
          samples << elapsed
          last_out ||= @@current_output
          @@current_metrics.each { |k, v| metrics_acc[k] = v }
        end
        sorted = samples.sort
        median = sorted[sorted.size // 2]
        Result.new(c.name, c.category, iterations, samples, median, sorted.first, sorted.last, metrics_acc, last_out)
      end

      # Measure an in-engine target within a group across N iterations
      def self.run_target(target : TargetSpec, iterations : Int32 = 3, ctx : Context? = nil) : TargetResult
        # Check active status if context is present
        if c = ctx
          unless target.active?(c.enabled_features, c.is_ci)
            return TargetResult.new(
              name: target.name,
              language: target.language,
              samples_ms: [] of Float64,
              median_ms: 0.0,
              min_ms: 0.0,
              max_ms: 0.0,
              speedup_vs_baseline: 1.0,
              custom_metrics: Hash(String, Float64).new,
              status: :skipped,
              skip_reason: target.ci_only ? "CI only" : "Feature #{target.feature} disabled"
            )
          end
        end

        samples = [] of Float64
        metrics_acc = Hash(String, Float64).new
        last_out : String? = nil
        if blk = target.block
          iterations.times do |iter|
            @@current_elapsed_ms = nil
            @@current_output = nil
            @@current_metrics.clear
            start = ::Time.instant
            blk.call(iter)
            elapsed = @@current_elapsed_ms || (::Time.instant - start).total_milliseconds
            samples << elapsed
            last_out ||= @@current_output
            @@current_metrics.each { |k, v| metrics_acc[k] = v }
          end
        else
          samples << 0.0
        end

        sorted = samples.empty? ? [0.0] : samples.sort
        median = sorted[sorted.size // 2]
        TargetResult.new(
          name: target.name,
          language: target.language,
          samples_ms: samples,
          median_ms: median,
          min_ms: sorted.first,
          max_ms: sorted.last,
          speedup_vs_baseline: 1.0,
          custom_metrics: metrics_acc,
          output_result: last_out,
          status: :passed
        )
      end

      # Execute a group and return comparative results against the designated baseline
      def self.run_group(group : Group, iterations : Int32 = 3, ctx : Context? = nil) : GroupResult
        raw_results = group.targets.map { |t| run_target(t, iterations, ctx) }
        baseline_name = group.baseline_name || group.targets.first?.try(&.name) || ""
        baseline_median = raw_results.find { |r| r.name == baseline_name && r.status == :passed }.try(&.median_ms) || 1.0
        baseline_median = 0.0001 if baseline_median <= 0.0

        target_results = raw_results.map do |r|
          speedup = if r.status == :passed && r.median_ms > 0.0
                      baseline_median / r.median_ms
                    else
                      1.0
                    end
          TargetResult.new(
            name: r.name,
            language: r.language,
            samples_ms: r.samples_ms,
            median_ms: r.median_ms,
            min_ms: r.min_ms,
            max_ms: r.max_ms,
            speedup_vs_baseline: speedup,
            custom_metrics: r.custom_metrics,
            output_result: r.output_result,
            status: r.status,
            skip_reason: r.skip_reason
          )
        end

        GroupResult.new(
          group_name: group.name,
          category: group.category,
          description: group.description,
          baseline_name: baseline_name,
          targets: target_results,
          kind: group.kind,
          chart_types: group.chart_types
        )
      end

      # Run all registered benchmarks
      def self.run_all(iterations : Int32 = 3, ctx : Context? = nil) : Array(Result)
        if c = ctx
          trigger_before_suite(c)
        end
        results = @@cases.map do |cs|
          c.try { |cx| trigger_before_case(cs, cx) }
          res = run_case(cs, iterations)
          c.try { |cx| trigger_after_case(cs, res, cx) }
          res
        end
        if c = ctx
          sum = Summary.new(
            total_cases: results.size,
            total_groups: @@groups.size,
            total_duration_ms: results.sum(&.median_ms),
            results: results
          )
          trigger_after_suite(sum, c)
        end
        results
      end

      # Run all registered groups
      def self.run_all_groups(iterations : Int32 = 3, ctx : Context? = nil) : Array(GroupResult)
        @@groups.map do |g|
          ctx.try { |c| trigger_before_group(g, c) }
          gr = run_group(g, iterations, ctx)
          ctx.try { |c| trigger_after_group(g, gr, c) }
          gr
        end
      end
    {% else %}
      # Benchmark framework completely compiled out via -Dno_benchmarks flag
      def self.report_elapsed_ms(ms : Float64) : Nil
      end

      def self.report_output(val : String) : Nil
      end

      def self.report_metric(key : String, value : Float64) : Nil
      end

      def self.register(name : String, category = nil, description = "", &block) : Nil
      end

      def self.group(name : String, category = nil, description = "", &block) : Nil
      end

      def self.before_suite(&block) : Nil
      end

      def self.after_suite(&block) : Nil
      end

      def self.before_case(&block) : Nil
      end

      def self.after_case(&block) : Nil
      end

      def self.before_group(&block) : Nil
      end

      def self.after_group(&block) : Nil
      end

      def self.trigger_before_suite(ctx) : Nil
      end

      def self.trigger_after_suite(sum, ctx) : Nil
      end

      def self.trigger_before_case(c, ctx) : Nil
      end

      def self.trigger_after_case(c, r, ctx) : Nil
      end

      def self.trigger_before_group(g, ctx) : Nil
      end

      def self.trigger_after_group(g, gr, ctx) : Nil
      end

      def self.all
        [] of Nil
      end

      def self.all_groups
        [] of Nil
      end

      def self.find_group(name : String)
        nil
      end

      def self.run_all(iterations : Int32 = 3, ctx = nil)
        [] of Nil
      end

      def self.run_all_groups(iterations : Int32 = 3, ctx = nil)
        [] of Nil
      end

      def self.run_group(group, iterations : Int32 = 3, ctx = nil)
        nil
      end

      def self.clear : Nil
      end
    {% end %}
  end
end
