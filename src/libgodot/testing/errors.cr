module Lapis
  module Test
    class AssertionError < Exception
      getter file : String
      getter line : Int32

      def initialize(message : String, @file : String = "", @line : Int32 = 0)
        full_msg = if !@file.empty? && @line > 0
                     "#{message} (at #{@file}:#{@line})"
                   else
                     message
                   end
        super(full_msg)
      end
    end

    # Exception raised when an asynchronous operation or signal await exceeds its timeout deadline
    class TimeoutError < AssertionError
    end

    # Exception raised when a test is deliberately skipped
    class SkipTestException < Exception
    end

    # Exception raised when a test is pending implementation
    class PendingTestException < Exception
    end

    # Encapsulates the execution result of a single registered test case
    record TestResult, category : String, name : String, passed : Bool, message : String = "", duration_ms : Float64 = 0.0, status : String = "PASS" do
      def pass? : Bool
        @status == "PASS" || (@passed && @status != "FAIL")
      end

      def fail? : Bool
        !pass? && !pending? && !skipped?
      end

      def pending? : Bool
        @status == "PENDING"
      end

      def skipped? : Bool
        @status == "SKIPPED"
      end
    end
  end
end
