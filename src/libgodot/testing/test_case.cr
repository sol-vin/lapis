module Lapis
  module Test
    class TestCase
      getter category : String
      getter name : String
      getter file : String
      getter line : Int32
      getter? cold_boot : Bool
      @block : (Godot::Node -> Void)?
      @cold_boot_block : (ColdBootContext -> Void)?

      def initialize(@category : String, @name : String, @file : String = "", @line : Int32 = 0, @cold_boot : Bool = false, &block : Godot::Node -> Void)
        @block = block
        @cold_boot_block = nil
      end

      def self.new_cold_boot(category : String, name : String, file : String = "", line : Int32 = 0, &block : ColdBootContext -> Void)
        tc = allocate
        tc.initialize_cold_boot(category, name, file, line, &block)
        tc
      end

      protected def initialize_cold_boot(@category : String, @name : String, @file : String = "", @line : Int32 = 0, &block : ColdBootContext -> Void)
        @cold_boot = true
        @block = nil
        @cold_boot_block = block
      end

      def execute(context_node : Godot::Node) : TestResult
        cb_str = @cold_boot ? " [COLD_BOOT]" : ""
        Godot.print("  [Running] [#{@category}] #{@name}#{cb_str}...")
        start = ::Time.instant
        begin
          # Run before_each hooks
          Registry.run_before_each(@category, context_node)

          if @cold_boot
            boot_ctx = ColdBootContext.new("#{@category}_#{@name}")
            begin
              if cb = @cold_boot_block
                cb.call(boot_ctx)
              elsif blk = @block
                blk.call(context_node)
              end
            ensure
              boot_ctx.cleanup
            end
          else
            @block.not_nil!.call(context_node)
          end

          duration = (::Time.instant - start).total_milliseconds
          TestResult.new(@category, @name, true, "PASS", duration, "PASS")
        rescue ex : PendingTestException
          duration = (::Time.instant - start).total_milliseconds
          Godot.print("  [PENDING] [#{@category}] #{@name}: #{ex.message}")
          TestResult.new(@category, @name, true, "PENDING: #{ex.message}", duration, "PENDING")
        rescue ex : SkipTestException
          duration = (::Time.instant - start).total_milliseconds
          Godot.print("  [SKIPPED] [#{@category}] #{@name}: #{ex.message}")
          TestResult.new(@category, @name, true, "SKIPPED: #{ex.message}", duration, "SKIPPED")
        rescue ex : AssertionError
          duration = (::Time.instant - start).total_milliseconds
          TestResult.new(@category, @name, false, ex.message || "Assertion failed", duration, "FAIL")
        rescue ex : Exception
          duration = (::Time.instant - start).total_milliseconds
          Godot.print("[ERROR] #{ex.inspect_with_backtrace}")
          TestResult.new(@category, @name, false, "ERROR: #{ex.class.name}: #{ex.message}\n#{ex.backtrace.join("\n")}", duration, "FAIL")
        ensure
          # Run after_each hooks
          Registry.run_after_each(@category, context_node)
          # Clean up any nodes tracked via track_node during this test
          Lapis::Test.cleanup_tracked_nodes
          # Clean up any autofree/autoqfree objects
          Lapis::Test.cleanup_autofree
        end
      end
    end
  end
end
