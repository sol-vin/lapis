module Lapis
  module Test
    class Registry
      @@tests = Array(TestCase).new
      @@before_all_hooks = Hash(String, Array(Godot::Node -> Void)).new
      @@after_all_hooks = Hash(String, Array(Godot::Node -> Void)).new
      @@before_each_hooks = Hash(String, Array(Godot::Node -> Void)).new
      @@after_each_hooks = Hash(String, Array(Godot::Node -> Void)).new

      def self.register(category : String, name : String, file : String = "", line : Int32 = 0, cold_boot : Bool = false, &block : Godot::Node -> Void)
        @@tests << TestCase.new(category, name, file, line, cold_boot, &block)
      end

      def self.register_cold_boot(category : String, name : String, file : String = "", line : Int32 = 0, &block : ColdBootContext -> Void)
        @@tests << TestCase.new_cold_boot(category, name, file, line, &block)
      end

      def self.before_all(category : String = "global", &block : Godot::Node -> Void)
        cat_norm = category.downcase.sub(/^test_?/, "")
        hooks = @@before_all_hooks[cat_norm] ||= Array(Godot::Node -> Void).new
        hooks << block
      end

      def self.after_all(category : String = "global", &block : Godot::Node -> Void)
        cat_norm = category.downcase.sub(/^test_?/, "")
        hooks = @@after_all_hooks[cat_norm] ||= Array(Godot::Node -> Void).new
        hooks << block
      end

      def self.before_each(category : String = "global", &block : Godot::Node -> Void)
        cat_norm = category.downcase.sub(/^test_?/, "")
        hooks = @@before_each_hooks[cat_norm] ||= Array(Godot::Node -> Void).new
        hooks << block
      end

      def self.after_each(category : String = "global", &block : Godot::Node -> Void)
        cat_norm = category.downcase.sub(/^test_?/, "")
        hooks = @@after_each_hooks[cat_norm] ||= Array(Godot::Node -> Void).new
        hooks << block
      end

      def self.run_before_all(category : String, context_node : Godot::Node)
        cat_norm = category.downcase.sub(/^test_?/, "")
        if global_hooks = @@before_all_hooks["global"]?
          global_hooks.each { |h| h.call(context_node) }
        end
        if cat_hooks = @@before_all_hooks[cat_norm]?
          cat_hooks.each { |h| h.call(context_node) }
        end
      end

      def self.run_after_all(category : String, context_node : Godot::Node)
        cat_norm = category.downcase.sub(/^test_?/, "")
        if cat_hooks = @@after_all_hooks[cat_norm]?
          cat_hooks.reverse_each { |h| h.call(context_node) rescue nil }
        end
        if global_hooks = @@after_all_hooks["global"]?
          global_hooks.reverse_each { |h| h.call(context_node) rescue nil }
        end
      end

      def self.run_before_each(category : String, context_node : Godot::Node)
        cat_norm = category.downcase.sub(/^test_?/, "")
        if global_hooks = @@before_each_hooks["global"]?
          global_hooks.each { |h| h.call(context_node) }
        end
        if cat_hooks = @@before_each_hooks[cat_norm]?
          cat_hooks.each { |h| h.call(context_node) }
        end
      end

      def self.run_after_each(category : String, context_node : Godot::Node)
        cat_norm = category.downcase.sub(/^test_?/, "")
        if cat_hooks = @@after_each_hooks[cat_norm]?
          cat_hooks.reverse_each { |h| h.call(context_node) rescue nil }
        end
        if global_hooks = @@after_each_hooks["global"]?
          global_hooks.reverse_each { |h| h.call(context_node) rescue nil }
        end
      end

      def self.all_tests : Array(TestCase)
        @@tests
      end

      def self.for_category(category : String) : Array(TestCase)
        cat_norm = category.downcase.sub(/^test_?/, "")
        @@tests.select { |t| t.category.downcase.sub(/^test_?/, "") == cat_norm }
      end

      def self.categories : Array(String)
        @@tests.map(&.category).uniq
      end

      def self.run_category(category : String, context_node : Godot::Node, filter : String? = nil) : Array(TestResult)
        results = Array(TestResult).new
        run_before_all(category, context_node)
        begin
          for_category(category).each do |test|
            next if filter && !filter.empty? && !test.name.includes?(filter)
            results << test.execute(context_node)
          end
        ensure
          run_after_all(category, context_node)
        end
        results
      end

      def self.run_all(context_node : Godot::Node, filter : String? = nil, category_filter : String? = nil) : Array(TestResult)
        results = Array(TestResult).new
        cat_norm = category_filter ? category_filter.downcase.sub(/^test_?/, "") : nil

        # Group by category to trigger category before_all/after_all lifecycle
        by_category = Hash(String, Array(TestCase)).new
        @@tests.each do |test|
          t_cat = test.category.downcase.sub(/^test_?/, "")
          if cat_norm && !cat_norm.empty?
            next if t_cat != cat_norm
          end
          next if filter && !filter.empty? && !test.name.downcase.includes?(filter.downcase)
          (by_category[test.category] ||= Array(TestCase).new) << test
        end

        by_category.each do |category, tests|
          run_before_all(category, context_node)
          begin
            tests.each do |test|
              results << test.execute(context_node)
            end
          ensure
            run_after_all(category, context_node)
          end
        end

        results
      end

      def self.clear : Void
        @@tests.clear
        @@before_all_hooks.clear
        @@after_all_hooks.clear
        @@before_each_hooks.clear
        @@after_each_hooks.clear
      end
    end
  end
end
